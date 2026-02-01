// Copyright 2026, Pulumi Corporation.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"archive/tar"
	"compress/gzip"
	"fmt"
	"io"
	"os"
	"path/filepath"

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
	schema string,
	extraFiles map[string][]byte,
	loaderTarget string,
	localDependencies map[string]string,
) ([]*codegenrpc.Diagnostic, error) {
	// TODO: Implement Dart code generation from Pulumi schema
	// This will be a significant implementation that generates:
	// - Resource classes
	// - Function wrappers
	// - Type definitions
	// - pubspec.yaml
	return nil, fmt.Errorf("package generation not yet implemented")
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
