package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

// updateCmd represents the update command
var updateCmd = &cobra.Command{
	Use:   "update",
	Short: "Update subjects",
	Run: func(_ *cobra.Command, _ []string) {
		fmt.Println("Please specify the subject to be updated")
	},
}

func init() {
	rootCmd.AddCommand(updateCmd)
}
