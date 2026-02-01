package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestNewDependencyManager(t *testing.T) {
	dm := NewDependencyManager()
	if dm == nil {
		t.Fatal("NewDependencyManager returned nil")
	}
}

func TestExtractVersion(t *testing.T) {
	tests := []struct {
		name     string
		input    interface{}
		expected string
	}{
		{
			name:     "simple version",
			input:    "5.0.0",
			expected: "5.0.0",
		},
		{
			name:     "caret version",
			input:    "^5.0.0",
			expected: "5.0.0",
		},
		{
			name:     "greater than or equal",
			input:    ">=5.0.0",
			expected: "5.0.0",
		},
		{
			name:     "tilde version",
			input:    "~5.0.0",
			expected: "5.0.0",
		},
		{
			name:     "version range",
			input:    ">=5.0.0 <6.0.0",
			expected: "5.0.0",
		},
		{
			name:     "git dependency",
			input:    map[string]interface{}{"git": "https://github.com/example/repo"},
			expected: "",
		},
		{
			name:     "path dependency",
			input:    map[string]interface{}{"path": "../local"},
			expected: "",
		},
		{
			name:     "nil input",
			input:    nil,
			expected: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := extractVersion(tt.input)
			if result != tt.expected {
				t.Errorf("extractVersion(%v) = %s, expected %s", tt.input, result, tt.expected)
			}
		})
	}
}

func TestGetRequiredPlugins_ValidPubspec(t *testing.T) {
	// Create a temporary directory with a test pubspec.yaml
	tmpDir, err := os.MkdirTemp("", "pulumi-dart-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	pubspec := `name: test_project
version: 1.0.0
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  pulumi: ^0.1.0
  pulumi_aws: ^5.0.0
  pulumi_random: ^4.0.0
  http: ^1.0.0
`

	err = os.WriteFile(filepath.Join(tmpDir, "pubspec.yaml"), []byte(pubspec), 0644)
	if err != nil {
		t.Fatal(err)
	}

	dm := NewDependencyManager()
	plugins, err := dm.GetRequiredPlugins(tmpDir)
	if err != nil {
		t.Fatalf("GetRequiredPlugins failed: %v", err)
	}

	// Should find pulumi_aws and pulumi_random, but not pulumi (core SDK) or http
	if len(plugins) != 2 {
		t.Errorf("Expected 2 plugins, got %d", len(plugins))
	}

	foundAws := false
	foundRandom := false
	for _, p := range plugins {
		if p.Name == "aws" && p.Version == "5.0.0" {
			foundAws = true
		}
		if p.Name == "random" && p.Version == "4.0.0" {
			foundRandom = true
		}
	}

	if !foundAws {
		t.Error("Did not find aws plugin")
	}
	if !foundRandom {
		t.Error("Did not find random plugin")
	}
}

func TestGetRequiredPlugins_MissingPubspec(t *testing.T) {
	dm := NewDependencyManager()
	_, err := dm.GetRequiredPlugins("/non/existent/path")
	if err == nil {
		t.Error("Expected error for missing pubspec.yaml")
	}
}

func TestGetProgramDependencies_FromPubspec(t *testing.T) {
	// Create a temporary directory with a test pubspec.yaml
	tmpDir, err := os.MkdirTemp("", "pulumi-dart-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	pubspec := `name: test_project
version: 1.0.0
dependencies:
  pulumi: ^0.1.0
  http: ^1.0.0
`

	err = os.WriteFile(filepath.Join(tmpDir, "pubspec.yaml"), []byte(pubspec), 0644)
	if err != nil {
		t.Fatal(err)
	}

	dm := NewDependencyManager()
	deps, err := dm.GetProgramDependencies(tmpDir, false)
	if err != nil {
		t.Fatalf("GetProgramDependencies failed: %v", err)
	}

	if len(deps) != 2 {
		t.Errorf("Expected 2 dependencies, got %d", len(deps))
	}
}

func TestGetProgramDependencies_FromLock(t *testing.T) {
	// Create a temporary directory with pubspec.yaml and pubspec.lock
	tmpDir, err := os.MkdirTemp("", "pulumi-dart-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	pubspec := `name: test_project
version: 1.0.0
dependencies:
  http: ^1.0.0
`

	lock := `packages:
  http:
    dependency: "direct main"
    description:
      name: http
      url: "https://pub.dev"
    source: hosted
    version: "1.0.0"
  meta:
    dependency: transitive
    description:
      name: meta
      url: "https://pub.dev"
    source: hosted
    version: "1.11.0"
`

	err = os.WriteFile(filepath.Join(tmpDir, "pubspec.yaml"), []byte(pubspec), 0644)
	if err != nil {
		t.Fatal(err)
	}
	err = os.WriteFile(filepath.Join(tmpDir, "pubspec.lock"), []byte(lock), 0644)
	if err != nil {
		t.Fatal(err)
	}

	dm := NewDependencyManager()

	// Test without transitive dependencies
	deps, err := dm.GetProgramDependencies(tmpDir, false)
	if err != nil {
		t.Fatalf("GetProgramDependencies failed: %v", err)
	}

	if len(deps) != 1 {
		t.Errorf("Expected 1 direct dependency, got %d", len(deps))
	}

	// Test with transitive dependencies
	deps, err = dm.GetProgramDependencies(tmpDir, true)
	if err != nil {
		t.Fatalf("GetProgramDependencies failed: %v", err)
	}

	if len(deps) != 2 {
		t.Errorf("Expected 2 dependencies (including transitive), got %d", len(deps))
	}
}

func TestValidatePubspec_Valid(t *testing.T) {
	// Create a temporary directory with a valid pubspec.yaml
	tmpDir, err := os.MkdirTemp("", "pulumi-dart-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	pubspec := `name: test_project
version: 1.0.0
dependencies:
  pulumi: ^0.1.0
`

	err = os.WriteFile(filepath.Join(tmpDir, "pubspec.yaml"), []byte(pubspec), 0644)
	if err != nil {
		t.Fatal(err)
	}

	dm := NewDependencyManager()
	err = dm.ValidatePubspec(tmpDir)
	if err != nil {
		t.Errorf("ValidatePubspec failed for valid pubspec: %v", err)
	}
}

func TestValidatePubspec_MissingName(t *testing.T) {
	// Create a temporary directory with an invalid pubspec.yaml
	tmpDir, err := os.MkdirTemp("", "pulumi-dart-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	pubspec := `version: 1.0.0
dependencies:
  pulumi: ^0.1.0
`

	err = os.WriteFile(filepath.Join(tmpDir, "pubspec.yaml"), []byte(pubspec), 0644)
	if err != nil {
		t.Fatal(err)
	}

	dm := NewDependencyManager()
	err = dm.ValidatePubspec(tmpDir)
	if err == nil {
		t.Error("Expected error for missing name field")
	}
}

func TestValidatePubspec_MissingPulumi(t *testing.T) {
	// Create a temporary directory with pubspec.yaml missing pulumi dependency
	tmpDir, err := os.MkdirTemp("", "pulumi-dart-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	pubspec := `name: test_project
version: 1.0.0
dependencies:
  http: ^1.0.0
`

	err = os.WriteFile(filepath.Join(tmpDir, "pubspec.yaml"), []byte(pubspec), 0644)
	if err != nil {
		t.Fatal(err)
	}

	dm := NewDependencyManager()
	err = dm.ValidatePubspec(tmpDir)
	if err == nil {
		t.Error("Expected error for missing pulumi dependency")
	}
}
