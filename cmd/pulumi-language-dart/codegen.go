package main

import (
	"archive/tar"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/example/pulumi-dart/pkg/codegen/dart"
	"github.com/hashicorp/hcl/v2"
	"github.com/pulumi/pulumi/pkg/v3/codegen/schema"
	codegenrpc "github.com/pulumi/pulumi/sdk/v3/proto/go/codegen"
)

// GenerateProject generates a new Dart Pulumi project from a template.
func GenerateProject(
	sourceDir string,
	targetDir string,
	project string,
	strict bool,
) error {
	// TODO: Implement project generation from templates
	// This will copy template files and customize them for the project
	return fmt.Errorf("project generation not yet implemented")
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
