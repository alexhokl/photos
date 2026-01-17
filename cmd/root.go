package cmd

import (
	"fmt"

	"github.com/alexhokl/helper/cli"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

type rootOptions struct {
	serviceURI              string
	allowInsecureConnection bool
	cfgFile                 string
}

var rootOpts rootOptions

const AppName = "photos"

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:          AppName,
	Short:        "A CLI application manages running server and client of photos",
	SilenceUsage: true,
	PersistentPreRun: func(cmd *cobra.Command, args []string) {
		bindEnvironmentVariablesToRootOptions(&rootOpts)
	},
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	_ = rootCmd.Execute()
}

func init() {
	cobra.OnInitialize(initConfig)

	persistentFlags := rootCmd.PersistentFlags()
	persistentFlags.StringVar(&rootOpts.cfgFile, "config", "", fmt.Sprintf("config file (default is $HOME/.%s.yaml)", AppName))
	persistentFlags.StringVarP(&rootOpts.serviceURI, "service", "s", "", "URI of the service to connect to")
	persistentFlags.BoolVarP(&rootOpts.allowInsecureConnection, "insecure", "i", false, "Allow insecure connection to the service")

	flags := rootCmd.Flags()
	flags.BoolP("toggle", "t", false, "Help message for toggle")

	_ = rootCmd.MarkFlagRequired("service")
}

func initConfig() {
	cli.ConfigureViper(rootOpts.cfgFile, AppName, false, "photos")
}

// / bindEnvironmentVariablesToRootOptions binds environment variables to root options.
func bindEnvironmentVariablesToRootOptions(opts *rootOptions) {
	if opts.serviceURI == "" {
		opts.serviceURI = viper.GetString("service")
	}
	if !opts.allowInsecureConnection {
		opts.allowInsecureConnection = viper.GetBool("insecure")
	}
	if opts.cfgFile == "" {
		opts.cfgFile = viper.GetString("config")
	}
}
