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
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// DartExecutor handles the execution of Dart programs.
type DartExecutor struct {
	// dartPath is the path to the dart executable.
	// If empty, "dart" from PATH is used.
	dartPath string
}

// NewDartExecutor creates a new Dart executor.
func NewDartExecutor() *DartExecutor {
	return &DartExecutor{}
}

// ExecutorConfig contains configuration for running a Dart program.
type ExecutorConfig struct {
	// Program is the path to the Dart program directory.
	Program string
	// Pwd is the working directory.
	Pwd string
	// Args are additional arguments to pass to the program.
	Args []string
	// Config is the Pulumi configuration as a map of key-value pairs.
	Config map[string]string
	// DryRun indicates whether this is a preview (dry-run) operation.
	DryRun bool
	// Parallel is the maximum number of parallel operations.
	Parallel int
	// MonitorAddress is the address of the resource monitor.
	MonitorAddress string
	// EngineAddress is the address of the Pulumi engine.
	EngineAddress string
	// Project is the project name.
	Project string
	// Stack is the stack name.
	Stack string
	// Organization is the organization name.
	Organization string
}

// ExecutorResult contains the result of running a Dart program.
type ExecutorResult struct {
	// Error is the error message if the program failed.
	Error string
	// Bail indicates whether the program requested to bail.
	Bail bool
}

// Run executes the Dart program with the given configuration.
func (e *DartExecutor) Run(ctx context.Context, config ExecutorConfig) (*ExecutorResult, error) {
	// Find the dart executable
	dartPath := e.dartPath
	if dartPath == "" {
		path, err := exec.LookPath("dart")
		if err != nil {
			return nil, fmt.Errorf("dart not found in PATH: %w", err)
		}
		dartPath = path
	}

	// Determine the program path
	programPath := config.Program
	if !filepath.IsAbs(programPath) {
		var err error
		programPath, err = filepath.Abs(programPath)
		if err != nil {
			return nil, fmt.Errorf("failed to resolve program path: %w", err)
		}
	}

	// Build the command arguments
	// We use "dart run" to execute the program
	args := []string{"run"}

	// Add any additional args from config
	args = append(args, config.Args...)

	// Create the command
	cmd := exec.CommandContext(ctx, dartPath, args...)
	cmd.Dir = programPath

	// Set up environment variables
	env := os.Environ()

	// Add Pulumi-specific environment variables
	env = append(env, fmt.Sprintf("PULUMI_MONITOR=%s", config.MonitorAddress))
	env = append(env, fmt.Sprintf("PULUMI_ENGINE=%s", config.EngineAddress))
	env = append(env, fmt.Sprintf("PULUMI_PROJECT=%s", config.Project))
	env = append(env, fmt.Sprintf("PULUMI_STACK=%s", config.Stack))
	env = append(env, fmt.Sprintf("PULUMI_ORGANIZATION=%s", config.Organization))
	env = append(env, fmt.Sprintf("PULUMI_PARALLEL=%d", config.Parallel))

	if config.DryRun {
		env = append(env, "PULUMI_DRY_RUN=true")
	} else {
		env = append(env, "PULUMI_DRY_RUN=false")
	}

	// Add configuration values as environment variables
	for key, value := range config.Config {
		envKey := fmt.Sprintf("PULUMI_CONFIG_%s", strings.ToUpper(strings.ReplaceAll(key, ":", "_")))
		env = append(env, fmt.Sprintf("%s=%s", envKey, value))
	}

	cmd.Env = env

	// Direct stdout and stderr to the parent process
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// Run the command
	err := cmd.Run()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			// Program exited with non-zero status
			return &ExecutorResult{
				Error: fmt.Sprintf("program exited with code %d", exitErr.ExitCode()),
				Bail:  false,
			}, nil
		}
		return nil, fmt.Errorf("failed to run Dart program: %w", err)
	}

	return &ExecutorResult{}, nil
}

// GetDartVersion returns the version of the Dart SDK.
func (e *DartExecutor) GetDartVersion() (string, error) {
	dartPath := e.dartPath
	if dartPath == "" {
		path, err := exec.LookPath("dart")
		if err != nil {
			return "", fmt.Errorf("dart not found in PATH: %w", err)
		}
		dartPath = path
	}

	cmd := exec.Command(dartPath, "--version")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("failed to get Dart version: %w", err)
	}

	// Output format: "Dart SDK version: 3.x.x (stable) ..."
	version := strings.TrimSpace(string(output))

	// Try to extract just the version number
	parts := strings.Fields(version)
	for i, part := range parts {
		if part == "version:" && i+1 < len(parts) {
			return parts[i+1], nil
		}
	}

	return version, nil
}

// ValidateDartInstallation checks that Dart is properly installed.
func (e *DartExecutor) ValidateDartInstallation() error {
	version, err := e.GetDartVersion()
	if err != nil {
		return fmt.Errorf("Dart is not installed or not in PATH: %w", err)
	}

	// Check minimum version (3.0.0)
	// Simple version check - in production would use semver
	if !strings.HasPrefix(version, "3.") {
		return fmt.Errorf("Dart 3.0.0 or higher is required, found %s", version)
	}

	return nil
}
