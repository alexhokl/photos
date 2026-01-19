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
}

var serveOpts serveOptions

// serveCmd represents the serve command
var serveCmd = &cobra.Command{
	Use:   "serve",
	Short: "Starts a server of photos",
	RunE:  runServe,
	PersistentPreRun: func(cmd *cobra.Command, args []string) {
		bindEnvironmentVariablesToServeOptions(&serveOpts)
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

	_ = serveCmd.MarkFlagRequired("database")
	_ = serveCmd.MarkFlagRequired("gcs-bucket")
}

func bindEnvironmentVariablesToServeOptions(opts *serveOptions) {
	if opts.TailscaleStateDirectory == "" {
		opts.TailscaleStateDirectory = viper.GetString("ts_state_dir")
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
	if opts.Port == 0 {
		opts.Port = viper.GetInt("port")
	}
	if opts.ProxyPort == 0 {
		opts.ProxyPort = viper.GetInt("proxy_port")
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
}

func runServe(cmd *cobra.Command, args []string) error {
	if err := validateFlags(serveOpts); err != nil {
		return err
	}

	dbConn, err := getDatabaseConnection(serveOpts.DatebaseFilePath)
	if err != nil {
		slog.Error("failed to connect to database", slog.String("error", err.Error()))
	}

	// Migrate the schema
	if err := database.AutoMigrate(dbConn); err != nil {
		return fmt.Errorf("failed to migrate database schema: %w", err)
	}

	// Verify GCS bucket connection
	gcsClient, err := getGCSClient(context.Background(), serveOpts)
	if err != nil {
		return fmt.Errorf("failed to create GCS client: %w", err)
	}
	defer gcsClient.Close()

	if err := verifyGCSBucket(context.Background(), gcsClient, serveOpts.GCSBucket); err != nil {
		return fmt.Errorf("failed to connect to GCS bucket %q: %w", serveOpts.GCSBucket, err)
	}
	slog.Info("successfully connected to GCS bucket", slog.String("bucket", serveOpts.GCSBucket))

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
		slog.Info("Tailscale is enabled", slog.String("hostname", serveOpts.Hostname))
	} else {
		grpcListener, err = net.Listen("tcp", fmt.Sprintf(":%d", serveOpts.Port))
		if err != nil {
			slog.Error(
				"failed to listen to port of gRPC server",
				slog.Int("port", serveOpts.Port),
				slog.String("error", err.Error()),
			)
			return err
		}
		restfulListener, err = net.Listen("tcp", fmt.Sprintf(":%d", serveOpts.ProxyPort))
		if err != nil {
			slog.Error(
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

	// Create gRPC server
	grpcServer := getGrpcServer(ctx, dbConn, privateServer, gcsClient, serveOpts.GCSBucket)

	// Create HTTP servers for graceful shutdown support
	fqdn := ""
	if privateServer != nil {
		fqdn = privateServer.FQDN()
	}
	restfulHandler, err := getRestfulProxyServerHandler(ctx, fqdn, serveOpts.Port)
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
			slog.Info("received shutdown signal", slog.String("signal", sig.String()))
		case <-ctx.Done():
			return nil
		}

		slog.Info("initiating graceful shutdown")

		// Create a timeout context for shutdown
		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer shutdownCancel()

		// Gracefully stop gRPC server (stops accepting new connections and waits for existing ones)
		grpcServer.GracefulStop()
		slog.Info("gRPC server stopped gracefully")

		// Shutdown HTTP servers
		if err := restfulServer.Shutdown(shutdownCtx); err != nil {
			slog.Error("error shutting down RESTful server", slog.String("error", err.Error()))
		} else {
			slog.Info("RESTful proxy server stopped gracefully")
		}

		if nonHTTPSServer != nil {
			if err := nonHTTPSServer.Shutdown(shutdownCtx); err != nil {
				slog.Error("error shutting down non-HTTPS server", slog.String("error", err.Error()))
			} else {
				slog.Info("non-HTTPS server stopped gracefully")
			}
		}

		// Cancel the main context to signal other goroutines
		cancel()
		return nil
	})

	// gRPC server goroutine
	g.Go(func() error {
		slog.Info(
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
		slog.Info(
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
			slog.Info(
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

	slog.Info("server shutdown complete")
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
	return nil
}

func getGrpcServer(_ context.Context, conn *gorm.DB, privateServer *pserver.Server, gcsClient *storage.Client, bucketName string) *grpc.Server {
	authenticationInterceptor := internal.DummyAuthenticationInterceptor
	if privateServer != nil {
		authenticationInterceptor = internal.NewTailscaleAuthenticationInterceptor(conn, privateServer).Intercept
	}
	grpcServer := grpc.NewServer(
		grpc.ChainUnaryInterceptor(
			internal.ErrorLoggingInterceptor,
			authenticationInterceptor,
		),
	)

	proto.RegisterByteServiceServer(grpcServer, &internal.BytesServer{
		DB:         conn,
		GCSClient:  gcsClient,
		BucketName: bucketName,
	})
	proto.RegisterLibraryServiceServer(grpcServer, &internal.LibraryServer{
		DB:         conn,
		GCSClient:  gcsClient,
		BucketName: bucketName,
	})

	return grpcServer
}

func getRestfulProxyServerHandler(ctx context.Context, fqdn string, grpcServerPort int) (http.Handler, error) {
	mux := runtime.NewServeMux()

	url := "localhost"
	if requireSecureConnection(fqdn) {
		url = fqdn
	}
	opts := []grpc.DialOption{grpc.WithTransportCredentials(getConnectionCredentials(requireSecureConnection(fqdn)))}
	grpcEndpoint := fmt.Sprintf("%s:%d", url, grpcServerPort)

	err := proto.RegisterByteServiceHandlerFromEndpoint(ctx, mux, grpcEndpoint, opts)
	if err != nil {
		return nil, err
	}

	err = proto.RegisterByteServiceHandlerFromEndpoint(ctx, mux, grpcEndpoint, opts)
	if err != nil {
		return nil, err
	}

	return mux, nil
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
