package ui

import (
	"fmt"
	"github.com/charmbracelet/bubbletea"
	"github.com/xxLYNX/nebula/cli/internal/nix"
)

type model struct {
	options []nix.Option
}

func NewOptionsTUI(opts []nix.Option) model {
	return model{options: opts}
}

func (m model) Init() tea.Cmd { return nil }
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) { return m, tea.Quit }
func (m model) View() string {
	s := "Nebula Options Browser\n\n"
	for _, o := range m.options {
		s += fmt.Sprintf("• %s\n", o.Description)
	}
	return s
}
