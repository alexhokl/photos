package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

// createCmd represents the create command
var createCmd = &cobra.Command{
	Use:   "create",
	Short: "Create subjects",
	Run: func(_ *cobra.Command, _ []string) {
		fmt.Println("Please specify the subject to create")
	},
}

func init() {
	rootCmd.AddCommand(createCmd)
}
