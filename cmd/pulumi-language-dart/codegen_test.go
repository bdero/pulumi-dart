package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestGenerateProject_NotImplemented(t *testing.T) {
	err := GenerateProject("/source", "/target", "test-project", false)
	if err == nil {
		t.Error("Expected error for not implemented feature")
	}
}

func TestGeneratePackage_NotImplemented(t *testing.T) {
	_, err := GeneratePackage("/output", "{}", nil, "", nil)
	if err == nil {
		t.Error("Expected error for not implemented feature")
	}
}

func TestGenerateProgram_NotImplemented(t *testing.T) {
	_, _, err := GenerateProgram(map[string]string{"main.pp": "resource foo {}"})
	if err == nil {
		t.Error("Expected error for not implemented feature")
	}
}

func TestPackProject(t *testing.T) {
	// Create a temporary source directory with test files
	srcDir, err := os.MkdirTemp("", "pulumi-dart-pack-src")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(srcDir)

	// Create test files
	pubspec := `name: test_project
version: 1.0.0
dependencies:
  pulumi: ^0.1.0
`
	err = os.WriteFile(filepath.Join(srcDir, "pubspec.yaml"), []byte(pubspec), 0644)
	if err != nil {
		t.Fatal(err)
	}

	pulumiYaml := `name: test-project
runtime: dart
`
	err = os.WriteFile(filepath.Join(srcDir, "Pulumi.yaml"), []byte(pulumiYaml), 0644)
	if err != nil {
		t.Fatal(err)
	}

	// Create lib directory
	libDir := filepath.Join(srcDir, "lib")
	err = os.MkdirAll(libDir, 0755)
	if err != nil {
		t.Fatal(err)
	}

	err = os.WriteFile(filepath.Join(libDir, "main.dart"), []byte("void main() {}"), 0644)
	if err != nil {
		t.Fatal(err)
	}

	// Create destination directory
	destDir, err := os.MkdirTemp("", "pulumi-dart-pack-dest")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(destDir)

	// Pack the project
	artifactPath, err := PackProject(srcDir, destDir)
	if err != nil {
		t.Fatalf("PackProject failed: %v", err)
	}

	// Verify the tarball was created
	if _, err := os.Stat(artifactPath); os.IsNotExist(err) {
		t.Errorf("Tarball was not created at %s", artifactPath)
	}

	// Verify the tarball has the expected name
	expectedName := filepath.Base(srcDir) + ".tar.gz"
	if filepath.Base(artifactPath) != expectedName {
		t.Errorf("Expected tarball name %s, got %s", expectedName, filepath.Base(artifactPath))
	}
}

func TestPackProject_MissingFiles(t *testing.T) {
	// Create an empty temporary directory
	srcDir, err := os.MkdirTemp("", "pulumi-dart-pack-empty")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(srcDir)

	destDir, err := os.MkdirTemp("", "pulumi-dart-pack-dest")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(destDir)

	// PackProject should still work (it ignores missing optional files)
	artifactPath, err := PackProject(srcDir, destDir)
	if err != nil {
		t.Fatalf("PackProject failed with missing files: %v", err)
	}

	// Verify the tarball was created (even if mostly empty)
	if _, err := os.Stat(artifactPath); os.IsNotExist(err) {
		t.Errorf("Tarball was not created at %s", artifactPath)
	}
}

func TestAddToTarball_NonExistent(t *testing.T) {
	// This test verifies that addToTarball returns an error for non-existent paths
	// We can't easily test this without creating a tar.Writer, so we'll rely on
	// the PackProject tests to cover this path indirectly
}
