package main

import (
	"archive/tar"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/example/pulumi-dart/pkg/codegen/dart"
	"github.com/hashicorp/hcl/v2"
	"github.com/pulumi/pulumi/pkg/v3/codegen/schema"
	"github.com/pulumi/pulumi/sdk/v3/go/common/workspace"
	codegenrpc "github.com/pulumi/pulumi/sdk/v3/proto/go/codegen"
)

// GenerateProject generates a new Dart Pulumi project from a template.
//
// This function is called when users run `pulumi new dart` to create a new
// Dart Pulumi project. It generates the following files:
//   - Pulumi.yaml: Project configuration with runtime: dart
//   - pubspec.yaml: Dart package configuration with pulumi dependency
//   - bin/main.dart: Entry point with Pulumi.run() boilerplate
//
// The sourceDir may contain PCL files to convert, but for basic template
// generation it will typically be empty or contain minimal PCL.
func GenerateProject(
	sourceDir string,
	targetDir string,
	projectJSON string,
	strict bool,
) error {
	// Parse the project JSON to get project metadata
	var project workspace.Project
	if err := json.Unmarshal([]byte(projectJSON), &project); err != nil {
		return fmt.Errorf("failed to parse project JSON: %w", err)
	}

	// Ensure target directory exists
	if err := os.MkdirAll(targetDir, 0o755); err != nil {
		return fmt.Errorf("failed to create target directory: %w", err)
	}

	// Generate Pulumi.yaml
	if err := generatePulumiYaml(targetDir, project); err != nil {
		return fmt.Errorf("failed to generate Pulumi.yaml: %w", err)
	}

	// Generate pubspec.yaml
	if err := generatePubspecYaml(targetDir, project); err != nil {
		return fmt.Errorf("failed to generate pubspec.yaml: %w", err)
	}

	// Generate bin/main.dart
	if err := generateMainDart(targetDir, project); err != nil {
		return fmt.Errorf("failed to generate bin/main.dart: %w", err)
	}

	// Generate analysis_options.yaml for good Dart practices
	if err := generateAnalysisOptions(targetDir); err != nil {
		return fmt.Errorf("failed to generate analysis_options.yaml: %w", err)
	}

	return nil
}

// generatePulumiYaml creates the Pulumi.yaml project file.
func generatePulumiYaml(targetDir string, project workspace.Project) error {
	var content strings.Builder

	content.WriteString(fmt.Sprintf("name: %s\n", project.Name))

	if project.Description != nil && *project.Description != "" {
		content.WriteString(fmt.Sprintf("description: %s\n", *project.Description))
	}

	content.WriteString("runtime: dart\n")

	return os.WriteFile(filepath.Join(targetDir, "Pulumi.yaml"), []byte(content.String()), 0o644)
}

// generatePubspecYaml creates the pubspec.yaml Dart package file.
func generatePubspecYaml(targetDir string, project workspace.Project) error {
	// Convert project name to valid Dart package name (snake_case, no hyphens)
	packageName := toValidDartPackageName(string(project.Name))

	var content strings.Builder

	content.WriteString(fmt.Sprintf("name: %s\n", packageName))
	content.WriteString("version: 1.0.0\n")

	if project.Description != nil && *project.Description != "" {
		content.WriteString(fmt.Sprintf("description: %s\n", *project.Description))
	} else {
		content.WriteString("description: A Pulumi program written in Dart\n")
	}

	content.WriteString("\nenvironment:\n")
	content.WriteString("  sdk: '>=3.0.0 <4.0.0'\n")

	content.WriteString("\ndependencies:\n")
	content.WriteString("  pulumi: ^0.1.0\n")

	content.WriteString("\ndev_dependencies:\n")
	content.WriteString("  lints: ^3.0.0\n")

	return os.WriteFile(filepath.Join(targetDir, "pubspec.yaml"), []byte(content.String()), 0o644)
}

// generateMainDart creates the bin/main.dart entry point file.
func generateMainDart(targetDir string, project workspace.Project) error {
	binDir := filepath.Join(targetDir, "bin")
	if err := os.MkdirAll(binDir, 0o755); err != nil {
		return err
	}

	content := `/// A Pulumi program written in Dart.
import 'package:pulumi/pulumi.dart';

Future<void> main() async {
  await Pulumi.run((ctx) async {
    // Add your resources here. For example:
    // final bucket = aws.s3.Bucket('my-bucket', aws.s3.BucketArgs());

    // Export values like this:
    // ctx.export('bucketName', bucket.bucket);
  });
}
`

	return os.WriteFile(filepath.Join(binDir, "main.dart"), []byte(content), 0o644)
}

// generateAnalysisOptions creates the analysis_options.yaml file.
func generateAnalysisOptions(targetDir string) error {
	content := `include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
`

	return os.WriteFile(filepath.Join(targetDir, "analysis_options.yaml"), []byte(content), 0o644)
}

// toValidDartPackageName converts a string to a valid Dart package name.
// Dart package names must be lowercase with underscores (snake_case).
func toValidDartPackageName(name string) string {
	// Replace hyphens with underscores
	name = strings.ReplaceAll(name, "-", "_")

	// Convert to lowercase
	name = strings.ToLower(name)

	// Remove any characters that aren't lowercase letters, digits, or underscores
	var result strings.Builder
	for _, r := range name {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '_' {
			result.WriteRune(r)
		}
	}

	// Ensure it doesn't start with a digit
	finalName := result.String()
	if len(finalName) > 0 && finalName[0] >= '0' && finalName[0] <= '9' {
		finalName = "_" + finalName
	}

	// Ensure it's not empty
	if finalName == "" {
		finalName = "pulumi_project"
	}

	return finalName
}

// GeneratePackage generates a Dart SDK for a Pulumi package schema.
func GeneratePackage(
	directory string,
	schemaJSON string,
	extraFiles map[string][]byte,
	loaderTarget string,
	localDependencies map[string]string,
) ([]*codegenrpc.Diagnostic, error) {
	var diagnostics []*codegenrpc.Diagnostic

	// Parse the schema JSON into a PackageSpec
	var spec schema.PackageSpec
	if err := json.Unmarshal([]byte(schemaJSON), &spec); err != nil {
		return nil, fmt.Errorf("failed to parse schema JSON: %w", err)
	}

	// Bind the schema spec to create a Package
	// We use nil loader since we're only generating SDK code and don't need to
	// resolve external references for this use case
	pkg, bindDiags, err := schema.BindSpec(spec, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to bind schema: %w", err)
	}

	// Convert binding diagnostics to RPC diagnostics
	for _, diag := range bindDiags {
		diagnostics = append(diagnostics, &codegenrpc.Diagnostic{
			Severity: convertSeverity(diag.Severity),
			Summary:  diag.Summary,
			Detail:   diag.Detail,
		})
	}

	// Configure the generator options
	options := dart.GeneratorOptions{}

	// Use local dependencies if provided (for development/testing)
	if len(localDependencies) > 0 {
		// Local dependencies could be used to override package paths
		// for testing with local SDK versions
		_ = localDependencies // Reserved for future use
	}

	// Generate the Dart package
	files, err := dart.GeneratePackage(pkg, options)
	if err != nil {
		return diagnostics, fmt.Errorf("failed to generate Dart package: %w", err)
	}

	// Write extra files first (overlays)
	for path, content := range extraFiles {
		outPath := filepath.Join(directory, path)
		if err := os.MkdirAll(filepath.Dir(outPath), 0o755); err != nil {
			return diagnostics, fmt.Errorf("failed to create directory for %s: %w", path, err)
		}
		if err := os.WriteFile(outPath, content, 0o644); err != nil {
			return diagnostics, fmt.Errorf("failed to write extra file %s: %w", path, err)
		}
	}

	// Write generated files to the output directory
	for path, content := range files {
		outPath := filepath.Join(directory, path)
		if err := os.MkdirAll(filepath.Dir(outPath), 0o755); err != nil {
			return diagnostics, fmt.Errorf("failed to create directory for %s: %w", path, err)
		}
		if err := os.WriteFile(outPath, content, 0o644); err != nil {
			return diagnostics, fmt.Errorf("failed to write file %s: %w", path, err)
		}
	}

	return diagnostics, nil
}

// convertSeverity converts an HCL diagnostic severity to RPC diagnostic severity.
func convertSeverity(sev hcl.DiagnosticSeverity) codegenrpc.DiagnosticSeverity {
	switch sev {
	case hcl.DiagError:
		return codegenrpc.DiagnosticSeverity_DIAG_ERROR
	case hcl.DiagWarning:
		return codegenrpc.DiagnosticSeverity_DIAG_WARNING
	default:
		return codegenrpc.DiagnosticSeverity_DIAG_INVALID
	}
}

// GenerateProgram converts PCL (Pulumi Configuration Language) to Dart code.
func GenerateProgram(
	source map[string]string,
) (map[string][]byte, []*codegenrpc.Diagnostic, error) {
	// TODO: Implement PCL to Dart conversion
	return nil, nil, fmt.Errorf("program generation not yet implemented")
}

// PackProject packages a Dart project for deployment.
//
// This creates a tarball containing:
// - pubspec.yaml
// - lib/ directory
// - bin/ directory (if exists)
// - Pulumi.yaml
func PackProject(packageDir string, destDir string) (string, error) {
	projectName := filepath.Base(packageDir)
	tarballName := fmt.Sprintf("%s.tar.gz", projectName)
	tarballPath := filepath.Join(destDir, tarballName)

	// Create the tarball
	file, err := os.Create(tarballPath)
	if err != nil {
		return "", fmt.Errorf("failed to create tarball: %w", err)
	}
	defer file.Close()

	gzWriter := gzip.NewWriter(file)
	defer gzWriter.Close()

	tarWriter := tar.NewWriter(gzWriter)
	defer tarWriter.Close()

	// Files and directories to include
	includes := []string{
		"pubspec.yaml",
		"pubspec.lock",
		"Pulumi.yaml",
		"lib",
		"bin",
	}

	for _, include := range includes {
		path := filepath.Join(packageDir, include)
		if err := addToTarball(tarWriter, path, include); err != nil {
			// Ignore missing optional files
			if !os.IsNotExist(err) {
				return "", fmt.Errorf("failed to add %s to tarball: %w", include, err)
			}
		}
	}

	return tarballPath, nil
}

// addToTarball adds a file or directory to the tarball.
func addToTarball(tw *tar.Writer, sourcePath string, tarPath string) error {
	info, err := os.Stat(sourcePath)
	if err != nil {
		return err
	}

	if info.IsDir() {
		return addDirectoryToTarball(tw, sourcePath, tarPath)
	}

	return addFileToTarball(tw, sourcePath, tarPath, info)
}

// addFileToTarball adds a single file to the tarball.
func addFileToTarball(tw *tar.Writer, sourcePath string, tarPath string, info os.FileInfo) error {
	header, err := tar.FileInfoHeader(info, "")
	if err != nil {
		return err
	}

	header.Name = tarPath

	if err := tw.WriteHeader(header); err != nil {
		return err
	}

	file, err := os.Open(sourcePath)
	if err != nil {
		return err
	}
	defer file.Close()

	_, err = io.Copy(tw, file)
	return err
}

// addDirectoryToTarball recursively adds a directory to the tarball.
func addDirectoryToTarball(tw *tar.Writer, sourceDir string, tarDir string) error {
	return filepath.Walk(sourceDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// Calculate the path within the tarball
		relPath, err := filepath.Rel(sourceDir, path)
		if err != nil {
			return err
		}
		tarPath := filepath.Join(tarDir, relPath)

		if info.IsDir() {
			// Create directory entry
			header := &tar.Header{
				Name:     tarPath + "/",
				Mode:     int64(info.Mode()),
				Typeflag: tar.TypeDir,
				ModTime:  info.ModTime(),
			}
			return tw.WriteHeader(header)
		}

		return addFileToTarball(tw, path, tarPath, info)
	})
}
