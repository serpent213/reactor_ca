package password

import (
	"bytes"
	"context"
	"fmt"
	"os"

	"golang.org/x/term"
	"reactor.de/reactor-ca/internal/domain"
	"reactor.de/reactor-ca/internal/ui"
)

// Provider implements the domain.PasswordProvider interface.
type Provider struct{}

// NewProvider creates a new password provider.
func NewProvider() *Provider {
	return &Provider{}
}

// GetMasterPassword retrieves the master password from file, env, or interactive prompt.
func (p *Provider) GetMasterPassword(ctx context.Context, cfg domain.PasswordConfig) ([]byte, error) {
	// 1. From file
	if cfg.File != "" {
		if pw, err := os.ReadFile(cfg.File); err == nil {
			return bytes.TrimSpace(pw), nil
		}
	}

	// 2. From environment variable
	if cfg.EnvVar != "" {
		if pw := os.Getenv(cfg.EnvVar); pw != "" {
			return []byte(pw), nil
		}
	}

	// 3. Interactive prompt
	prompt := ui.NewPrompt()
	return prompt.PromptPassword("Enter current CA password: ")
}

// GetNewMasterPassword prompts the user to enter and confirm a new password.
func (p *Provider) GetNewMasterPassword(ctx context.Context, minLength int) ([]byte, error) {
	// Check if we're in a non-interactive environment and try env var fallback
	if !term.IsTerminal(int(os.Stdin.Fd())) {
		if pw := os.Getenv("REACTOR_CA_PASSWORD"); pw != "" {
			if len(pw) < minLength {
				return nil, fmt.Errorf("password from REACTOR_CA_PASSWORD is too short (minimum %d characters)", minLength)
			}
			return []byte(pw), nil
		}
		return nil, fmt.Errorf("running in non-interactive environment but no password provided via REACTOR_CA_PASSWORD environment variable")
	}

	prompt := ui.NewPrompt()
	return prompt.PromptPasswordWithConfirmation("Enter new CA password: ", minLength)
}

// StaticPasswordProvider implements domain.PasswordProvider with a pre-set password.
// Used during re-encryption to provide the new password to the identity provider.
type StaticPasswordProvider struct {
	Password []byte
}

func (s *StaticPasswordProvider) GetMasterPassword(ctx context.Context, cfg domain.PasswordConfig) ([]byte, error) {
	return s.Password, nil
}

func (s *StaticPasswordProvider) GetNewMasterPassword(ctx context.Context, minLength int) ([]byte, error) {
	return s.Password, nil
}
