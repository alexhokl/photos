package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

// getCmd represents the get command
var getCmd = &cobra.Command{
	Use:   "get",
	Short: "Get subjects",
	Run: func(_ *cobra.Command, _ []string) {
		fmt.Println("Please specify the subject to get")
	},
}

func init() {
	rootCmd.AddCommand(getCmd)
}
