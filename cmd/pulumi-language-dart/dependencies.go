package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/pulumi/pulumi/sdk/v3/go/common/workspace"
	"gopkg.in/yaml.v3"
)

// DependencyManager handles Dart package dependencies.
type DependencyManager struct{}

// NewDependencyManager creates a new dependency manager.
func NewDependencyManager() *DependencyManager {
	return &DependencyManager{}
}

// DependencyInfo represents information about a dependency.
type DependencyInfo struct {
	Name    string
	Version string
}

// Pubspec represents the structure of a pubspec.yaml file.
type Pubspec struct {
	Name         string                 `yaml:"name"`
	Version      string                 `yaml:"version"`
	Dependencies map[string]interface{} `yaml:"dependencies"`
	DevDeps      map[string]interface{} `yaml:"dev_dependencies"`
}

// PubspecLock represents the structure of a pubspec.lock file.
type PubspecLock struct {
	Packages map[string]PubspecLockPackage `yaml:"packages"`
}

// PubspecLockPackage represents a package entry in pubspec.lock.
type PubspecLockPackage struct {
	Dependency  string `yaml:"dependency"`
	Description struct {
		Name string `yaml:"name"`
		URL  string `yaml:"url"`
	} `yaml:"description"`
	Source  string `yaml:"source"`
	Version string `yaml:"version"`
}

// GetRequiredPlugins parses pubspec.yaml to find required Pulumi plugins.
//
// It looks for dependencies starting with "pulumi_" and maps them to
// provider plugin requirements.
func (d *DependencyManager) GetRequiredPlugins(programPath string) ([]PluginInfo, error) {
	pubspecPath := filepath.Join(programPath, "pubspec.yaml")

	data, err := os.ReadFile(pubspecPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read pubspec.yaml: %w", err)
	}

	var pubspec Pubspec
	if err := yaml.Unmarshal(data, &pubspec); err != nil {
		return nil, fmt.Errorf("failed to parse pubspec.yaml: %w", err)
	}

	var plugins []PluginInfo

	// Check dependencies for pulumi_* packages
	for name, versionSpec := range pubspec.Dependencies {
		if strings.HasPrefix(name, "pulumi_") && name != "pulumi" {
			// Extract provider name (e.g., "pulumi_aws" -> "aws")
			providerName := strings.TrimPrefix(name, "pulumi_")

			// Get version from the dependency spec
			version := extractVersion(versionSpec)

			plugins = append(plugins, PluginInfo{
				Name:    providerName,
				Kind:    workspace.ResourcePlugin,
				Version: version,
				Server:  "", // Use default plugin source
			})
		}
	}

	return plugins, nil
}

// extractVersion extracts the version string from a pubspec dependency specification.
func extractVersion(versionSpec interface{}) string {
	switch v := versionSpec.(type) {
	case string:
		// Simple version constraint like "^5.0.0"
		// Remove constraint operators for plugin version
		version := strings.TrimPrefix(v, "^")
		version = strings.TrimPrefix(version, ">=")
		version = strings.TrimPrefix(version, "~")
		version = strings.TrimSpace(version)
		// Take the first version if there's a range
		parts := strings.Split(version, " ")
		if len(parts) > 0 {
			return parts[0]
		}
		return version
	case map[string]interface{}:
		// Git or path dependency - no version info
		return ""
	default:
		return ""
	}
}

// InstallDependencies runs `dart pub get` to install dependencies.
func (d *DependencyManager) InstallDependencies(
	ctx context.Context,
	directory string,
	output func(string),
) error {
	dartPath, err := exec.LookPath("dart")
	if err != nil {
		return fmt.Errorf("dart not found in PATH: %w", err)
	}

	output(fmt.Sprintf("Installing Dart dependencies in %s...", directory))

	cmd := exec.CommandContext(ctx, dartPath, "pub", "get")
	cmd.Dir = directory

	// Stream output
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to run 'dart pub get': %w", err)
	}

	output("Dependencies installed successfully.")
	return nil
}

// GetProgramDependencies returns the list of resolved dependencies from pubspec.lock.
func (d *DependencyManager) GetProgramDependencies(
	programPath string,
	includeTransitive bool,
) ([]DependencyInfo, error) {
	lockPath := filepath.Join(programPath, "pubspec.lock")

	data, err := os.ReadFile(lockPath)
	if err != nil {
		// If lock file doesn't exist, try reading from pubspec.yaml
		return d.getDependenciesFromPubspec(programPath, includeTransitive)
	}

	var lock PubspecLock
	if err := yaml.Unmarshal(data, &lock); err != nil {
		return nil, fmt.Errorf("failed to parse pubspec.lock: %w", err)
	}

	var deps []DependencyInfo

	for name, pkg := range lock.Packages {
		// If not including transitive, only include direct dependencies
		if !includeTransitive && pkg.Dependency != "direct main" && pkg.Dependency != "direct dev" {
			continue
		}

		deps = append(deps, DependencyInfo{
			Name:    name,
			Version: pkg.Version,
		})
	}

	return deps, nil
}

// getDependenciesFromPubspec reads dependencies directly from pubspec.yaml.
func (d *DependencyManager) getDependenciesFromPubspec(
	programPath string,
	includeTransitive bool,
) ([]DependencyInfo, error) {
	pubspecPath := filepath.Join(programPath, "pubspec.yaml")

	data, err := os.ReadFile(pubspecPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read pubspec.yaml: %w", err)
	}

	var pubspec Pubspec
	if err := yaml.Unmarshal(data, &pubspec); err != nil {
		return nil, fmt.Errorf("failed to parse pubspec.yaml: %w", err)
	}

	var deps []DependencyInfo

	for name, versionSpec := range pubspec.Dependencies {
		deps = append(deps, DependencyInfo{
			Name:    name,
			Version: extractVersion(versionSpec),
		})
	}

	return deps, nil
}

// ValidatePubspec checks that the pubspec.yaml file is valid.
func (d *DependencyManager) ValidatePubspec(programPath string) error {
	pubspecPath := filepath.Join(programPath, "pubspec.yaml")

	data, err := os.ReadFile(pubspecPath)
	if err != nil {
		return fmt.Errorf("pubspec.yaml not found: %w", err)
	}

	var pubspec Pubspec
	if err := yaml.Unmarshal(data, &pubspec); err != nil {
		return fmt.Errorf("invalid pubspec.yaml: %w", err)
	}

	if pubspec.Name == "" {
		return fmt.Errorf("pubspec.yaml missing 'name' field")
	}

	// Check for pulumi dependency
	if _, hasPulumi := pubspec.Dependencies["pulumi"]; !hasPulumi {
		return fmt.Errorf("pubspec.yaml is missing 'pulumi' dependency")
	}

	return nil
}
