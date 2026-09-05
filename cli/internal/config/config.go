package config

import "github.com/spf13/viper"

func Load() {
	// Future: load inventory path, default security mode, etc.
	viper.SetDefault("inventory", "../inventory/machines.json")
	viper.SetDefault("flake", "..")
	viper.SetDefault("security.mode", "fast") // fast | full
}
