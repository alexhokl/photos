package cmd

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"cloud.google.com/go/storage"
	"github.com/alexhokl/photos/database"
	"github.com/alexhokl/photos/internal"
	"github.com/alexhokl/photos/proto"
	pserver "github.com/alexhokl/privateserver/server"
	"github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"golang.org/x/sync/errgroup"
	"google.golang.org/api/option"
	"google.golang.org/grpc"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

const DefaultPort = 8080
const DefaultProxyPort = 8081

type serveOptions struct {
	Port                    int
	ProxyPort               int
	DatebaseFilePath        string
	Hostname                string
	TailscaleAuthKey        string
	TailscaleStateDirectory string
	GCSBucket               string
	GCSProject              string
	GCSCredentials          string
	GCSPrefix               string
	WebPQuality             int
}

var serveOpts serveOptions

// serveCmd represents the serve command
var serveCmd = &cobra.Command{
	Use:   "serve",
	Short: "Starts a server of photos",
	RunE:  runServe,
	PersistentPreRun: func(cmd *cobra.Command, args []string) {
		bindEnvironmentVariablesToServeOptions(cmd, &serveOpts)
	},
}

func init() {
	rootCmd.AddCommand(serveCmd)

	flags := serveCmd.Flags()

	flags.IntVarP(&serveOpts.Port, "port", "p", DefaultPort, "Port to run the server on")
	flags.IntVar(&serveOpts.ProxyPort, "proxy-port", DefaultProxyPort, "Port to run the proxy server on")
	flags.StringVarP(&serveOpts.DatebaseFilePath, "database", "d", "", "Path to the database file")
	flags.StringVar(&serveOpts.Hostname, "hostname", "", "Hostname for Tailscale (if empty, it would not be available on Tailscale network)")
	flags.StringVar(&serveOpts.TailscaleAuthKey, "ts-auth-key", "", "Tailscale auth key (if empty, it would not be available on Tailscale network)")
	flags.StringVar(&serveOpts.TailscaleStateDirectory, "ts-state-dir", "./tailscale-state", "Directory to store Tailscale state (if empty, it would use a temporary directory)")
	flags.StringVarP(&serveOpts.GCSBucket, "gcs-bucket", "b", "", "Google Cloud Storage bucket name")
	flags.StringVar(&serveOpts.GCSProject, "gcs-project", "", "Google Cloud project ID (optional, auto-detected if not set)")
	flags.StringVar(&serveOpts.GCSCredentials, "gcs-credentials", "", "Path to GCS service account credentials JSON file (optional, uses ADC if not set)")
	flags.StringVar(&serveOpts.GCSPrefix, "gcs-prefix", "", "Object prefix/folder path within the bucket (optional)")
	flags.IntVar(&serveOpts.WebPQuality, "webp-quality", internal.DefaultWebPQuality, "WebP quality percentage (1-100) for generated WebP images (requires cwebp)")

	_ = viper.BindPFlag("port", flags.Lookup("port"))
	_ = viper.BindPFlag("proxy_port", flags.Lookup("proxy-port"))
	_ = viper.BindPFlag("database", flags.Lookup("database"))
	_ = viper.BindPFlag("hostname", flags.Lookup("hostname"))
	_ = viper.BindPFlag("ts_auth_key", flags.Lookup("ts-auth-key"))
	_ = viper.BindPFlag("ts_state_dir", flags.Lookup("ts-state-dir"))
	_ = viper.BindPFlag("gcs_bucket", flags.Lookup("gcs-bucket"))
	_ = viper.BindPFlag("gcs_project", flags.Lookup("gcs-project"))
	_ = viper.BindPFlag("gcs_credentials", flags.Lookup("gcs-credentials"))
	_ = viper.BindPFlag("gcs_prefix", flags.Lookup("gcs-prefix"))
	_ = viper.BindPFlag("webp_quality", flags.Lookup("webp-quality"))
}

func bindEnvironmentVariablesToServeOptions(cmd *cobra.Command, opts *serveOptions) {
	if !cmd.Flags().Changed("ts-state-dir") {
		if v := viper.GetString("ts_state_dir"); v != "" {
			opts.TailscaleStateDirectory = v
		}
	}
	if opts.TailscaleAuthKey == "" {
		opts.TailscaleAuthKey = viper.GetString("ts_auth_key")
	}
	if opts.Hostname == "" {
		opts.Hostname = viper.GetString("hostname")
	}
	if opts.DatebaseFilePath == "" {
		opts.DatebaseFilePath = viper.GetString("database")
	}
	if !cmd.Flags().Changed("port") {
		if v := viper.GetInt("port"); v != 0 {
			opts.Port = v
		}
	}
	if !cmd.Flags().Changed("proxy-port") {
		if v := viper.GetInt("proxy_port"); v != 0 {
			opts.ProxyPort = v
		}
	}
	if opts.GCSBucket == "" {
		opts.GCSBucket = viper.GetString("gcs_bucket")
	}
	if opts.GCSProject == "" {
		opts.GCSProject = viper.GetString("gcs_project")
	}
	if opts.GCSCredentials == "" {
		opts.GCSCredentials = viper.GetString("gcs_credentials")
	}
	if opts.GCSPrefix == "" {
		opts.GCSPrefix = viper.GetString("gcs_prefix")
	}
	if !cmd.Flags().Changed("webp-quality") {
		if v := viper.GetInt("webp_quality"); v != 0 {
			opts.WebPQuality = v
		}
	}
}

func runServe(cmd *cobra.Command, args []string) error {
	if err := validateFlags(serveOpts); err != nil {
		return err
	}

	// Initialise OpenTelemetry (TracerProvider + LoggerProvider + default slog).
	// This must happen before any slog calls so all log output is routed through
	// the OTLP log exporter and carries trace correlation fields.
	ctx := cmd.Context()
	if ctx == nil {
		ctx = context.Background()
	}
	otelShutdown, err := internal.SetupOTel(ctx)
	if err != nil {
		// Non-fatal: log to stderr and continue without OTel rather than
		// refusing to start the server.
		slog.Error("failed to set up OpenTelemetry", slog.String("error", err.Error()))
	} else {
		defer func() {
			if shutdownErr := otelShutdown(context.Background()); shutdownErr != nil {
				slog.Error("error shutting down OpenTelemetry", slog.String("error", shutdownErr.Error()))
			}
		}()
	}

	dbConn, err := getDatabaseConnection(serveOpts.DatebaseFilePath)
	if err != nil {
		slog.ErrorContext(ctx, "failed to connect to database", slog.String("error", err.Error()))
	}

	// Migrate the schema
	if err := database.AutoMigrate(dbConn); err != nil {
		return fmt.Errorf("failed to migrate database schema: %w", err)
	}

	// Verify GCS bucket connection
	gcsClient, err := getGCSClient(cmd.Context(), serveOpts)
	if err != nil {
		return fmt.Errorf("failed to create GCS client: %w", err)
	}
	defer func() { _ = gcsClient.Close() }()

	if err := verifyGCSBucket(cmd.Context(), gcsClient, serveOpts.GCSBucket); err != nil {
		return fmt.Errorf("failed to connect to GCS bucket %q: %w", serveOpts.GCSBucket, err)
	}
	slog.InfoContext(ctx, "successfully connected to GCS bucket", slog.String("bucket", serveOpts.GCSBucket))

	var privateServer *pserver.Server
	var grpcListener net.Listener
	var restfulListener net.Listener
	var nonHTTPSListener net.Listener
	var nonHTTPSHandler http.Handler

	if serveOpts.Hostname != "" {
		privateServerConfig := &pserver.ServerConfig{
			Hostname:                serveOpts.Hostname,
			TailscaleAuthKey:        serveOpts.TailscaleAuthKey,
			TailscaleStateDirectory: serveOpts.TailscaleStateDirectory,
		}

		privateServer, err = pserver.NewServer(privateServerConfig)
		if err != nil {
			return fmt.Errorf("failed to create private server: %w", err)
		}
		listeners, redirectListener, redirectHandler, err := privateServer.Listen([]int{serveOpts.Port, serveOpts.ProxyPort})
		if err != nil {
			return fmt.Errorf("failed to start private server: %w", err)
		}
		grpcListener = listeners[0]
		restfulListener = listeners[1]
		nonHTTPSListener = redirectListener
		nonHTTPSHandler = redirectHandler
		slog.InfoContext(ctx, "Tailscale is enabled", slog.String("hostname", serveOpts.Hostname))
	} else {
		grpcListener, err = net.Listen("tcp", fmt.Sprintf(":%d", serveOpts.Port))
		if err != nil {
			slog.ErrorContext(
				ctx,
				"failed to listen to port of gRPC server",
				slog.Int("port", serveOpts.Port),
				slog.String("error", err.Error()),
			)
			return err
		}
		restfulListener, err = net.Listen("tcp", fmt.Sprintf(":%d", serveOpts.ProxyPort))
		if err != nil {
			slog.ErrorContext(
				ctx,
				"failed to listen to port of RESTful proxy server",
				slog.Int("port", serveOpts.ProxyPort),
				slog.String("error", err.Error()),
			)
			return err
		}
	}

	// Create a context that will be cancelled on SIGTERM/SIGINT
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Set up signal handling
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGTERM, syscall.SIGINT)

	g, ctx := errgroup.WithContext(ctx)

	// Construct the gRPC service implementations once; they are shared by
	// the gRPC server (served over Tailscale/tsnet or a plain TCP listener)
	// and the RESTful gateway below, which invokes them in-process instead
	// of dialing back into the gRPC server over the network.
	libraryServer := &internal.LibraryServer{
		DB:          dbConn,
		GCSClient:   gcsClient,
		BucketName:  serveOpts.GCSBucket,
		WebPQuality: serveOpts.WebPQuality,
	}
	bytesServer := &internal.BytesServer{
		DB:          dbConn,
		GCSClient:   gcsClient,
		BucketName:  serveOpts.GCSBucket,
		WebPQuality: serveOpts.WebPQuality,
	}

	authenticationInterceptor := internal.DummyAuthenticationInterceptor
	streamAuthenticationInterceptor := internal.DummyStreamAuthenticationInterceptor
	httpAuthenticationMiddleware := internal.DummyHTTPMiddleware
	if privateServer != nil {
		tailscaleInterceptor := internal.NewTailscaleAuthenticationInterceptor(dbConn, privateServer)
		authenticationInterceptor = tailscaleInterceptor.Intercept
		streamAuthenticationInterceptor = tailscaleInterceptor.InterceptStream
		httpAuthenticationMiddleware = tailscaleInterceptor.HTTPMiddleware
	}

	// Create gRPC server
	grpcServer := getGrpcServer(libraryServer, bytesServer, authenticationInterceptor, streamAuthenticationInterceptor)

	// Create HTTP servers for graceful shutdown support
	fqdn := ""
	if privateServer != nil {
		fqdn = privateServer.FQDN()
	}
	restfulHandler, err := getRestfulProxyServerHandler(ctx, libraryServer, bytesServer, httpAuthenticationMiddleware)
	if err != nil {
		return fmt.Errorf("failed to create RESTful proxy server handler: %w", err)
	}
	restfulServer := &http.Server{Handler: restfulHandler}

	var nonHTTPSServer *http.Server
	if nonHTTPSListener != nil && nonHTTPSHandler != nil {
		nonHTTPSServer = &http.Server{Handler: nonHTTPSHandler}
	}

	// Goroutine to handle shutdown signals
	g.Go(func() error {
		select {
		case sig := <-sigChan:
			slog.InfoContext(context.Background(), "received shutdown signal", slog.String("signal", sig.String()))
		case <-ctx.Done():
			return nil
		}

		slog.InfoContext(context.Background(), "initiating graceful shutdown")

		// Create a timeout context for shutdown
		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer shutdownCancel()

		// Gracefully stop gRPC server (stops accepting new connections and waits for existing ones)
		grpcServer.GracefulStop()
		slog.InfoContext(shutdownCtx, "gRPC server stopped gracefully")

		// Shutdown HTTP servers
		if err := restfulServer.Shutdown(shutdownCtx); err != nil {
			slog.ErrorContext(shutdownCtx, "error shutting down RESTful server", slog.String("error", err.Error()))
		} else {
			slog.InfoContext(shutdownCtx, "RESTful proxy server stopped gracefully")
		}

		if nonHTTPSServer != nil {
			if err := nonHTTPSServer.Shutdown(shutdownCtx); err != nil {
				slog.ErrorContext(shutdownCtx, "error shutting down non-HTTPS server", slog.String("error", err.Error()))
			} else {
				slog.InfoContext(shutdownCtx, "non-HTTPS server stopped gracefully")
			}
		}

		// Cancel the main context to signal other goroutines
		cancel()
		return nil
	})

	// gRPC server goroutine
	g.Go(func() error {
		slog.InfoContext(
			ctx,
			"gRPC server is serving",
			slog.Int("port", serveOpts.Port),
		)

		if err := grpcServer.Serve(grpcListener); err != nil {
			// grpc.Server.Serve returns nil on GracefulStop, but check for other errors
			select {
			case <-ctx.Done():
				return nil
			default:
				return err
			}
		}
		return nil
	})

	// RESTful proxy server goroutine
	g.Go(func() error {
		slog.InfoContext(
			ctx,
			"RESTful proxy server is serving",
			slog.Int("port", serveOpts.ProxyPort),
			slog.Bool("https", requireSecureConnection(fqdn)),
			slog.String("fqdn", fqdn),
		)

		if err := restfulServer.Serve(restfulListener); err != nil && err != http.ErrServerClosed {
			return err
		}
		return nil
	})

	// Non-HTTPS server goroutine (if enabled)
	if nonHTTPSServer != nil {
		g.Go(func() error {
			slog.InfoContext(
				ctx,
				"non-HTTPS server is listening",
				slog.String("addr", nonHTTPSListener.Addr().String()),
			)

			if err := nonHTTPSServer.Serve(nonHTTPSListener); err != nil && err != http.ErrServerClosed {
				return err
			}
			return nil
		})
	}

	if err := g.Wait(); err != nil {
		return err
	}

	slog.InfoContext(context.Background(), "server shutdown complete")
	return nil
}

func getDatabaseConnection(databaseFilePath string) (*gorm.DB, error) {
	db, err := gorm.Open(
		sqlite.Open(databaseFilePath),
		&gorm.Config{
			Logger: logger.New(
				slog.NewLogLogger(slog.NewJSONHandler(os.Stdout, nil), slog.LevelInfo),
				logger.Config{
					IgnoreRecordNotFoundError: true, // Ignore ErrRecordNotFound error for logger
				},
			),
		},
	)

	return db, err
}

func validateFlags(opts serveOptions) error {
	if opts.Port <= 0 || opts.Port > 65535 {
		return fmt.Errorf("invalid port number: %d", opts.Port)
	}
	if opts.ProxyPort <= 0 || opts.ProxyPort > 65535 {
		return fmt.Errorf("invalid proxy port number: %d", opts.ProxyPort)
	}
	if opts.DatebaseFilePath == "" {
		return fmt.Errorf("database file path cannot be empty")
	}
	if (opts.Hostname == "" && opts.TailscaleAuthKey != "") || (opts.Hostname != "" && opts.TailscaleAuthKey == "") {
		return fmt.Errorf("both hostname and Tailscale auth key must be provided to enable Tailscale")
	}
	if opts.GCSBucket == "" {
		return fmt.Errorf("GCS bucket name cannot be empty")
	}
	if opts.GCSCredentials != "" {
		if _, err := os.Stat(opts.GCSCredentials); os.IsNotExist(err) {
			return fmt.Errorf("GCS credentials file does not exist: %s", opts.GCSCredentials)
		}
	}
	if opts.WebPQuality < 1 || opts.WebPQuality > 100 {
		return fmt.Errorf("invalid webp quality: %d (must be between 1 and 100)", opts.WebPQuality)
	}
	return nil
}

func getGrpcServer(
	libraryServer proto.LibraryServiceServer,
	bytesServer proto.ByteServiceServer,
	authenticationInterceptor grpc.UnaryServerInterceptor,
	streamAuthenticationInterceptor grpc.StreamServerInterceptor,
) *grpc.Server {
	grpcServer := grpc.NewServer(
		// OTel stats handler: starts a span for every incoming RPC and
		// propagates W3C trace context so logs emitted inside handlers are
		// correlated with the active trace in GCP Cloud Trace.
		grpc.StatsHandler(otelgrpc.NewServerHandler()),
		grpc.MaxRecvMsgSize(10*1024*1024), // 10 MB
		grpc.MaxSendMsgSize(10*1024*1024), // 10 MB
		grpc.ChainUnaryInterceptor(
			internal.ErrorLoggingInterceptor,
			authenticationInterceptor,
		),
		grpc.ChainStreamInterceptor(
			streamAuthenticationInterceptor,
		),
	)

	proto.RegisterByteServiceServer(grpcServer, bytesServer)
	proto.RegisterLibraryServiceServer(grpcServer, libraryServer)

	return grpcServer
}

// getRestfulProxyServerHandler builds the RESTful/JSON gateway handler. It
// registers the grpc-gateway mux directly against the in-process
// LibraryService/ByteService implementations (via the generated
// Register*HandlerServer functions), rather than dialing back into the gRPC
// server over the network - the gateway and the gRPC server run in the same
// process, so a network round-trip back to itself is unnecessary and, when
// the gRPC server is only reachable over Tailscale/tsnet, not reliably
// possible at all.
//
// Because Register*HandlerServer bypasses the gRPC server's own interceptor
// chain, authMiddleware is responsible for authenticating the incoming HTTP
// request and injecting the resolved caller identity into its context
// (mirroring what the gRPC authentication interceptors do for direct gRPC
// calls).
func getRestfulProxyServerHandler(
	ctx context.Context,
	libraryServer proto.LibraryServiceServer,
	bytesServer proto.ByteServiceServer,
	authMiddleware func(http.Handler) http.Handler,
) (http.Handler, error) {
	gwMux := runtime.NewServeMux()

	if err := proto.RegisterByteServiceHandlerServer(ctx, gwMux, bytesServer); err != nil {
		return nil, fmt.Errorf("failed to register ByteService gateway handler: %w", err)
	}

	if err := proto.RegisterLibraryServiceHandlerServer(ctx, gwMux, libraryServer); err != nil {
		return nil, fmt.Errorf("failed to register LibraryService gateway handler: %w", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /v1/photos/bytes/{object_id...}", internal.NewRawBytesHandler(&internal.ByteServerDownloader{Server: bytesServer}))
	mux.Handle("/", gwMux)

	return authMiddleware(otelhttp.NewHandler(mux, "gateway")), nil
}

func getGCSClient(ctx context.Context, opts serveOptions) (*storage.Client, error) {
	var clientOpts []option.ClientOption

	if opts.GCSCredentials != "" {
		clientOpts = append(clientOpts, option.WithAuthCredentialsFile(option.ServiceAccount, opts.GCSCredentials))
	}

	client, err := storage.NewClient(ctx, clientOpts...)
	if err != nil {
		return nil, err
	}

	return client, nil
}

func verifyGCSBucket(ctx context.Context, client *storage.Client, bucketName string) error {
	bucket := client.Bucket(bucketName)

	// Try to get bucket attributes to verify the bucket exists and we have access
	_, err := bucket.Attrs(ctx)
	if err != nil {
		return err
	}

	return nil
}
