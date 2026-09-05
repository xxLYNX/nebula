package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var validateCmd = &cobra.Command{
	Use:   "validate",
	Short: "Syntactic + semantic checks + optional full supply-chain scan",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Validating inventory, roles, bundles, and supply chain...")
		// TODO: call nix eval + vulnix + sbom
	},
}
