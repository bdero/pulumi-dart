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
//
// This verifies that Dart is installed and meets the minimum version requirement
// (3.0.0+), then runs `dart pub get` to install all dependencies defined in
// pubspec.yaml. Output is streamed to the provided callback function.
func (d *DependencyManager) InstallDependencies(
	ctx context.Context,
	directory string,
	output func(string),
) error {
	dartPath, err := exec.LookPath("dart")
	if err != nil {
		return fmt.Errorf("dart not found in PATH: %w", err)
	}

	// Verify Dart version meets minimum requirements
	if err := d.verifyDartVersion(dartPath, output); err != nil {
		return err
	}

	// Verify pubspec.yaml exists
	pubspecPath := filepath.Join(directory, "pubspec.yaml")
	if _, err := os.Stat(pubspecPath); os.IsNotExist(err) {
		return fmt.Errorf("pubspec.yaml not found in %s", directory)
	}

	output(fmt.Sprintf("Installing Dart dependencies in %s...", directory))

	cmd := exec.CommandContext(ctx, dartPath, "pub", "get")
	cmd.Dir = directory

	// Capture stdout and stderr to stream to the output callback
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("failed to create stdout pipe: %w", err)
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return fmt.Errorf("failed to create stderr pipe: %w", err)
	}

	// Start the command
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start 'dart pub get': %w", err)
	}

	// Stream stdout
	go func() {
		buf := make([]byte, 1024)
		for {
			n, err := stdout.Read(buf)
			if n > 0 {
				output(string(buf[:n]))
			}
			if err != nil {
				break
			}
		}
	}()

	// Stream stderr
	go func() {
		buf := make([]byte, 1024)
		for {
			n, err := stderr.Read(buf)
			if n > 0 {
				output(string(buf[:n]))
			}
			if err != nil {
				break
			}
		}
	}()

	// Wait for the command to finish
	if err := cmd.Wait(); err != nil {
		return fmt.Errorf("failed to run 'dart pub get': %w", err)
	}

	output("Dependencies installed successfully.")
	return nil
}

// verifyDartVersion checks that the Dart SDK version meets the minimum requirement.
func (d *DependencyManager) verifyDartVersion(dartPath string, output func(string)) error {
	cmd := exec.Command(dartPath, "--version")
	versionOutput, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to get Dart version: %w", err)
	}

	versionStr := strings.TrimSpace(string(versionOutput))
	output(fmt.Sprintf("Found %s", versionStr))

	// Parse version - output format: "Dart SDK version: 3.x.x (stable) ..."
	version := extractDartVersion(versionStr)
	if version == "" {
		return fmt.Errorf("could not parse Dart version from: %s", versionStr)
	}

	// Check minimum version (3.0.0)
	if !isVersionAtLeast(version, "3.0.0") {
		return fmt.Errorf("Dart 3.0.0 or higher is required, found %s", version)
	}

	return nil
}

// extractDartVersion extracts the version number from Dart's --version output.
func extractDartVersion(output string) string {
	// Output format: "Dart SDK version: 3.x.x (stable) ..."
	parts := strings.Fields(output)
	for i, part := range parts {
		if part == "version:" && i+1 < len(parts) {
			return parts[i+1]
		}
	}
	return ""
}

// isVersionAtLeast checks if version is at least minVersion.
// Uses simple string comparison which works for semantic versions.
func isVersionAtLeast(version, minVersion string) bool {
	// Split versions into parts
	vParts := strings.Split(version, ".")
	minParts := strings.Split(minVersion, ".")

	// Compare each part
	for i := 0; i < len(minParts) && i < len(vParts); i++ {
		// Extract numeric part (handle versions like "3.11.0-276.0.dev")
		vNum := extractNumericPart(vParts[i])
		minNum := extractNumericPart(minParts[i])

		if vNum > minNum {
			return true
		}
		if vNum < minNum {
			return false
		}
	}

	// If all compared parts are equal, version is at least minVersion
	return len(vParts) >= len(minParts)
}

// extractNumericPart extracts the leading numeric part from a version component.
func extractNumericPart(s string) int {
	num := 0
	for _, c := range s {
		if c >= '0' && c <= '9' {
			num = num*10 + int(c-'0')
		} else {
			break
		}
	}
	return num
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
