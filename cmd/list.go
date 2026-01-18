package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

// listCmd represents the list command
var listCmd = &cobra.Command{
	Use:   "list",
	Short: "List subjects",
	Run: func(_ *cobra.Command, _ []string) {
		fmt.Println("Please specify the subject to be listed")
	},
}

func init() {
	rootCmd.AddCommand(listCmd)
}
