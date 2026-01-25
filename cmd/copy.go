package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

// copyCmd represents the copy command
var copyCmd = &cobra.Command{
	Use:   "copy",
	Short: "Copy subjects",
	Run: func(_ *cobra.Command, _ []string) {
		fmt.Println("Please specify the subject to copy")
	},
}

func init() {
	rootCmd.AddCommand(copyCmd)
}
