// Command denova-fnos-setup applies fnOS install-wizard answers to the Denova
// user configuration. It is shipped only inside the fnOS package and runs from
// the package lifecycle scripts as the package user, before or between server
// runs, so it reuses the config package instead of editing TOML by hand.
package main

import (
	"bufio"
	"flag"
	"fmt"
	"io"
	"os"
	"strings"

	"denova/config"
)

func main() {
	if err := run(os.Args[1:], os.Stdin); err != nil {
		fmt.Fprintln(os.Stderr, "denova-fnos-setup:", err)
		os.Exit(1)
	}
}

func run(args []string, stdin io.Reader) error {
	if len(args) == 0 || args[0] != "remote-access" {
		return fmt.Errorf("usage: denova-fnos-setup remote-access --data-dir DIR --username NAME < password")
	}
	flags := flag.NewFlagSet("remote-access", flag.ContinueOnError)
	dataDir := flags.String("data-dir", "", "Denova data directory (DENOVA_DIR)")
	username := flags.String("username", "", "remote access username")
	if err := flags.Parse(args[1:]); err != nil {
		return err
	}
	if strings.TrimSpace(*dataDir) == "" {
		return fmt.Errorf("--data-dir is required")
	}
	// The password arrives on stdin so it never appears in process listings.
	password, err := bufio.NewReader(stdin).ReadString('\n')
	if err != nil && err != io.EOF {
		return fmt.Errorf("read password: %w", err)
	}
	return enableRemoteAccess(*dataDir, *username, strings.TrimRight(password, "\r\n"))
}

// enableRemoteAccess turns on LAN listening, because the fnOS desktop reaches
// Denova through the NAS address. A blank password keeps the existing hash so
// re-running the settings wizard does not force a password change.
func enableRemoteAccess(dataDir, username, password string) error {
	if err := os.MkdirAll(dataDir, 0o755); err != nil {
		return fmt.Errorf("create data directory: %w", err)
	}
	_, err := config.MutateUserSettings(dataDir, "", func(current config.Settings) (config.Settings, error) {
		next := current
		enabled := true
		next.AllowLANAccess = &enabled
		if name := strings.TrimSpace(username); name != "" {
			next.RemoteAccessUsername = name
		}
		next.RemoteAccessPassword = password
		return config.PrepareUserSettingsForWrite(current, next)
	})
	if err != nil {
		return fmt.Errorf("update user settings: %w", err)
	}
	return nil
}
