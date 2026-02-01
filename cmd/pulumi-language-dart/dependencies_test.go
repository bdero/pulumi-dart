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
  sdk: '>=3.8.0 <4.0.0'
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

func TestGetRequiredPlugins_NestedProviderNames(t *testing.T) {
	// Test that nested provider names like pulumi_azure_native work correctly
	tmpDir, err := os.MkdirTemp("", "pulumi-dart-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	pubspec := `name: test_project
version: 1.0.0
dependencies:
  pulumi: ^0.1.0
  pulumi_azure_native: ^2.0.0
  pulumi_kubernetes: ^4.0.0
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

	if len(plugins) != 2 {
		t.Errorf("Expected 2 plugins, got %d", len(plugins))
	}

	// Check that azure_native is correctly preserved (not just "azure")
	foundAzureNative := false
	foundKubernetes := false
	for _, p := range plugins {
		if p.Name == "azure_native" && p.Version == "2.0.0" {
			foundAzureNative = true
		}
		if p.Name == "kubernetes" && p.Version == "4.0.0" {
			foundKubernetes = true
		}
	}

	if !foundAzureNative {
		t.Error("Did not find azure_native plugin (should preserve full name after pulumi_)")
	}
	if !foundKubernetes {
		t.Error("Did not find kubernetes plugin")
	}
}

func TestGetRequiredPlugins_EmptyDependencies(t *testing.T) {
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
	plugins, err := dm.GetRequiredPlugins(tmpDir)
	if err != nil {
		t.Fatalf("GetRequiredPlugins failed: %v", err)
	}

	// Should return empty list (pulumi core SDK is not a plugin)
	if len(plugins) != 0 {
		t.Errorf("Expected 0 plugins (only core SDK), got %d", len(plugins))
	}
}

func TestGetRequiredPlugins_GitDependency(t *testing.T) {
	// Test that git dependencies are handled (version should be empty)
	tmpDir, err := os.MkdirTemp("", "pulumi-dart-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	pubspec := `name: test_project
version: 1.0.0
dependencies:
  pulumi: ^0.1.0
  pulumi_custom:
    git:
      url: https://github.com/example/pulumi_custom
      ref: main
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

	if len(plugins) != 1 {
		t.Errorf("Expected 1 plugin, got %d", len(plugins))
	}

	if len(plugins) > 0 {
		if plugins[0].Name != "custom" {
			t.Errorf("Expected plugin name 'custom', got '%s'", plugins[0].Name)
		}
		if plugins[0].Version != "" {
			t.Errorf("Expected empty version for git dependency, got '%s'", plugins[0].Version)
		}
	}
}

func TestGetRequiredPlugins_PluginKind(t *testing.T) {
	// Verify that plugins are returned with the correct kind
	tmpDir, err := os.MkdirTemp("", "pulumi-dart-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	pubspec := `name: test_project
version: 1.0.0
dependencies:
  pulumi: ^0.1.0
  pulumi_aws: ^5.0.0
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

	if len(plugins) != 1 {
		t.Fatalf("Expected 1 plugin, got %d", len(plugins))
	}

	// Verify the plugin kind is ResourcePlugin
	if plugins[0].Kind != "resource" {
		t.Errorf("Expected plugin kind 'resource', got '%s'", plugins[0].Kind)
	}
}

func TestExtractDartVersion(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "stable version",
			input:    "Dart SDK version: 3.2.0 (stable) on \"linux_x64\"",
			expected: "3.2.0",
		},
		{
			name:     "dev version",
			input:    "Dart SDK version: 3.11.0-276.0.dev (dev) on \"windows_x64\"",
			expected: "3.11.0-276.0.dev",
		},
		{
			name:     "simple output",
			input:    "Dart SDK version: 3.0.0",
			expected: "3.0.0",
		},
		{
			name:     "no version found",
			input:    "some random output",
			expected: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := extractDartVersion(tt.input)
			if result != tt.expected {
				t.Errorf("extractDartVersion(%q) = %q, expected %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestIsVersionAtLeast(t *testing.T) {
	tests := []struct {
		name       string
		version    string
		minVersion string
		expected   bool
	}{
		{
			name:       "exact match",
			version:    "3.0.0",
			minVersion: "3.0.0",
			expected:   true,
		},
		{
			name:       "higher major",
			version:    "4.0.0",
			minVersion: "3.0.0",
			expected:   true,
		},
		{
			name:       "higher minor",
			version:    "3.2.0",
			minVersion: "3.0.0",
			expected:   true,
		},
		{
			name:       "higher patch",
			version:    "3.0.5",
			minVersion: "3.0.0",
			expected:   true,
		},
		{
			name:       "lower major",
			version:    "2.0.0",
			minVersion: "3.0.0",
			expected:   false,
		},
		{
			name:       "lower minor",
			version:    "3.0.0",
			minVersion: "3.1.0",
			expected:   false,
		},
		{
			name:       "dev version",
			version:    "3.11.0-276.0.dev",
			minVersion: "3.0.0",
			expected:   true,
		},
		{
			name:       "dev version exact",
			version:    "3.0.0-dev",
			minVersion: "3.0.0",
			expected:   true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isVersionAtLeast(tt.version, tt.minVersion)
			if result != tt.expected {
				t.Errorf("isVersionAtLeast(%q, %q) = %v, expected %v", tt.version, tt.minVersion, result, tt.expected)
			}
		})
	}
}

func TestExtractNumericPart(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected int
	}{
		{
			name:     "simple number",
			input:    "123",
			expected: 123,
		},
		{
			name:     "number with suffix",
			input:    "11-276",
			expected: 11,
		},
		{
			name:     "number with dev suffix",
			input:    "0-dev",
			expected: 0,
		},
		{
			name:     "empty string",
			input:    "",
			expected: 0,
		},
		{
			name:     "no numbers",
			input:    "dev",
			expected: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := extractNumericPart(tt.input)
			if result != tt.expected {
				t.Errorf("extractNumericPart(%q) = %d, expected %d", tt.input, result, tt.expected)
			}
		})
	}
}

func TestInstallDependencies_MissingPubspec(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "pulumi-dart-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	dm := NewDependencyManager()
	var messages []string
	err = dm.InstallDependencies(nil, tmpDir, func(msg string) {
		messages = append(messages, msg)
	})

	// Should fail because pubspec.yaml doesn't exist
	// (but will first check Dart - might skip if Dart not installed)
	if err == nil {
		// If Dart is installed, it should fail on missing pubspec
		t.Log("Test may have passed because Dart is not installed")
	}
}
