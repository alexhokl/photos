package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

// moveCmd represents the move command
var moveCmd = &cobra.Command{
	Use:   "move",
	Short: "Move subjects",
	Run: func(_ *cobra.Command, _ []string) {
		fmt.Println("Please specify the subject to move")
	},
}

func init() {
	rootCmd.AddCommand(moveCmd)
}
