package cmd

import (
	"fmt"
	"github.com/charmbracelet/bubbletea"
	"github.com/spf13/cobra"
	"github.com/xxLYNX/nebula/cli/internal/nix"
	"github.com/xxLYNX/nebula/cli/internal/ui"
)

var optionsCmd = &cobra.Command{
	Use:   "options",
	Short: "Discover every knob — with descriptions, types, defaults",
	Long:  "The killer feature. Real-time docs from your own roles/bundles.",
	RunE:  optionsRun,
}

func init() {
	optionsCmd.Flags().StringP("host", "h", "", "Host to inspect (from inventory)")
	optionsCmd.Flags().Bool("interactive", false, "Launch beautiful TUI browser")
}

func optionsRun(cmd *cobra.Command, args []string) error {
	host, _ := cmd.Flags().GetString("host")
	interactive, _ := cmd.Flags().GetBool("interactive")

	if host == "" {
		return fmt.Errorf("please specify --host (or we'll add --role/--bundle soon)")
	}

	opts, err := nix.GetOptionsForHost(host)
	if err != nil {
		return err
	}

	if interactive {
		p := tea.NewProgram(ui.NewOptionsTUI(opts))
		if _, err := p.Run(); err != nil {
			return err
		}
		return nil
	}

	// Simple table output for now
	for _, o := range opts {
		fmt.Printf("%-40s %s\n", o.Type, o.Description)
	}
	return nil
}
