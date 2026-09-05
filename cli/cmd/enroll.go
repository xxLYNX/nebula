package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var enrollCmd = &cobra.Command{
	Use:   "enroll <ip-or-hostname>",
	Short: "One-command enrollment (terraform + disko + sops + machineEnrolled flag)",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("Enrolling %s...\n", args[0])
		// TODO: wrap scripts/enroll-machine.sh
	},
}
