package main

import (
	"strings"
	"testing"

	"denova/config"
)

func TestRemoteAccessKeepsPasswordWhenWizardLeavesItBlank(t *testing.T) {
	dataDir := t.TempDir()
	if err := run([]string{"remote-access", "--data-dir", dataDir, "--username", "writer"}, strings.NewReader("secret\n")); err != nil {
		t.Fatal(err)
	}
	first := readUserSettings(t, dataDir)
	if first.AllowLANAccess == nil || !*first.AllowLANAccess || first.RemoteAccessUsername != "writer" ||
		!config.CheckRemoteAccessPassword(first.RemoteAccessPasswordHash, "secret") {
		t.Fatalf("remote access not enabled: %+v", first)
	}

	if err := run([]string{"remote-access", "--data-dir", dataDir}, strings.NewReader("")); err != nil {
		t.Fatal(err)
	}
	second := readUserSettings(t, dataDir)
	if second.RemoteAccessUsername != "writer" || second.RemoteAccessPasswordHash != first.RemoteAccessPasswordHash {
		t.Fatalf("blank wizard answers changed credentials: %+v", second)
	}
}

func TestRemoteAccessRequiresInitialPassword(t *testing.T) {
	err := run([]string{"remote-access", "--data-dir", t.TempDir(), "--username", "writer"}, strings.NewReader("\n"))
	if err == nil || !strings.Contains(err.Error(), config.ErrRemoteAccessPasswordRequired.Error()) {
		t.Fatalf("error = %v, want password required", err)
	}
}

func readUserSettings(t *testing.T, dataDir string) config.Settings {
	t.Helper()
	settings, err := config.ReadSettingsFile(config.UserConfigPath(dataDir))
	if err != nil {
		t.Fatal(err)
	}
	return settings
}
