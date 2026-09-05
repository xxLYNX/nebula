package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"github.com/xxLYNX/nebula/cli/internal/config"
)

var rootCmd = &cobra.Command{
	Use:   "nebula",
	Short: "Nebula — NixOS fleet management with discoverability, validation, and zero-drift",
	Long: `Nebula turns your existing flake + inventory into a first-class configuration management tool.
GitOps, SOPS, roles, bundles, supply-chain security — all first-class.`,
	PersistentPreRun: func(cmd *cobra.Command, args []string) {
		config.Load()
	},
}

func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}

func init() {
	cobra.OnInitialize(initConfig)
	rootCmd.PersistentFlags().String("config", "", "config file (default is nebula.toml)")
	rootCmd.Flags().BoolP("verbose", "v", false, "verbose output")

	// Add subcommands here
	rootCmd.AddCommand(versionCmd)
	rootCmd.AddCommand(optionsCmd)
	rootCmd.AddCommand(validateCmd)
	rootCmd.AddCommand(enrollCmd)
	// TODO: role new, bundle new, machine add, apply, security, monitoring, etc.
}

func initConfig() {
	viper.SetConfigName("nebula")
	viper.SetConfigType("toml")
	viper.AddConfigPath(".")
	viper.AutomaticEnv()

	if err := viper.ReadInConfig(); err == nil {
		fmt.Println("Using config file:", viper.ConfigFileUsed())
	}
}
