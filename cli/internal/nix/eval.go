package nix

import (
	"encoding/json"
	"fmt"
	"os/exec"

	"github.com/spf13/viper"
)

type Option struct {
	Description string `json:"description"`
	Type        string `json:"type"`
	Default     any    `json:"default"`
	Example     any    `json:"example"`
}

// GetOptionsForHost returns all options for a given host (or role) using nixosOptionsDoc
func GetOptionsForHost(host string) ([]Option, error) {
	// This assumes your flake.nix exposes nixosConfigurations.<host>
	expr := fmt.Sprintf(`
		let
		  flake = builtins.getFlake (toString %s);
		  host = flake.nixosConfigurations."%s";
		  doc = flake.pkgs.x86_64-linux.nixosOptionsDoc { options = host.options; };
		in
		  doc.options
	`, viper.GetString("flake"), host)

	cmd := exec.Command("nix", "eval", "--impure", "--json", "--expr", expr)
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("nix eval failed: %w", err)
	}

	var opts map[string]Option
	if err := json.Unmarshal(out, &opts); err != nil {
		return nil, err
	}

	var result []Option
	for _, o := range opts {
		result = append(result, o)
	}
	return result, nil
}
