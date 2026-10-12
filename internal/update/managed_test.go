package update

import (
	"bytes"
	"context"
	"errors"
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

func TestManagedInstallationNeverReplacesProgramFiles(t *testing.T) {
	installDir := t.TempDir()
	service := &Service{currentVersion: "0.4.5", executablePath: filepath.Join(installDir, "denova"), installManager: "fnos"}
	if err := os.WriteFile(service.executablePath, []byte("current"), 0o755); err != nil {
		t.Fatal(err)
	}
	archiveName := "denova-v0.5.0-" + platformKey(runtime.GOOS, runtime.GOARCH) + ".tar.gz"
	if _, err := service.InstallLocal(context.Background(), archiveName, bytes.NewReader(nil)); !errors.Is(err, ErrManagedInstall) {
		t.Fatalf("InstallLocal error = %v, want ErrManagedInstall", err)
	}
	if _, err := service.Install(context.Background()); !errors.Is(err, ErrManagedInstall) {
		t.Fatalf("Install error = %v, want ErrManagedInstall", err)
	}
	if _, err := service.Apply(context.Background(), func() {}, 0); !errors.Is(err, ErrManagedInstall) {
		t.Fatalf("Apply error = %v, want ErrManagedInstall", err)
	}
	if _, err := os.Stat(updateDataDir(installDir)); !os.IsNotExist(err) {
		t.Fatalf("managed installation created update state: %v", err)
	}

	release := githubRelease{TagName: "v0.5.0", Assets: []githubAsset{
		{Name: "denova-v0.5.0-" + platformKey(runtime.GOOS, runtime.GOARCH) + ".tar.gz"},
		{Name: "checksums.txt"},
	}}
	unmanaged := &Service{currentVersion: service.currentVersion}
	if !unmanaged.checkRelease(release).CanInstall {
		t.Fatal("fixture release must be installable without a host package manager")
	}
	check := service.checkRelease(release)
	if !check.UpdateAvailable || check.CanInstall || check.ManagedBy != "fnos" {
		t.Fatalf("managed check = %+v, want an available update that cannot be installed in-app", check)
	}
	status, err := service.Status()
	if err != nil || status.ManagedBy != "fnos" {
		t.Fatalf("Status = %+v, %v; want managed_by fnos", status, err)
	}
}
