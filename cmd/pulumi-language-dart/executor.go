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
	// ExecutionMode is the mode for running the Dart program: "run", "aot", or "binary".
	ExecutionMode string
	// BinaryPath is the path to a pre-compiled binary (when ExecutionMode is "binary").
	BinaryPath string
	// EntryPoint is the entry point file to run (e.g., "bin/main.dart").
	// If empty, "dart run" uses the default entry point based on the package name.
	EntryPoint string
	// AttachDebugger indicates whether to run the program under a debugger.
	AttachDebugger bool
	// EngineClient is the gRPC client for communicating with the Pulumi engine.
	// Required when AttachDebugger is true to notify the engine of the debug session.
	EngineClient EngineClient
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
	// Determine the program path
	programPath := config.Program
	if !filepath.IsAbs(programPath) {
		var err error
		programPath, err = filepath.Abs(programPath)
		if err != nil {
			return nil, fmt.Errorf("failed to resolve program path: %w", err)
		}
	}

	// Handle debug attachment mode
	if config.AttachDebugger {
		return e.runWithDebugger(ctx, config, programPath)
	}

	// Build the command based on execution mode
	var cmd *exec.Cmd
	var aotSnapshotPath string // Track AOT snapshot for cleanup

	switch config.ExecutionMode {
	case "binary":
		var err error
		cmd, err = e.buildBinaryCommand(ctx, config, programPath)
		if err != nil {
			return nil, err
		}
	case "aot":
		aotResult, err := e.buildAotCommand(ctx, config, programPath)
		if err != nil {
			return nil, err
		}
		cmd = aotResult.cmd
		aotSnapshotPath = aotResult.snapshotPath
	default: // "run" mode
		var err error
		cmd, err = e.buildRunCommand(ctx, config, programPath)
		if err != nil {
			return nil, err
		}
	}

	// Clean up AOT snapshot after execution (if applicable)
	if aotSnapshotPath != "" {
		defer func() {
			// Remove the AOT snapshot file to avoid stale artifacts
			_ = os.Remove(aotSnapshotPath)
		}()
	}

	// Set up environment variables
	env := e.buildEnvironment(config)
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

// runWithDebugger runs the Dart program with debugger attachment enabled.
// This starts the Dart VM with the VM service enabled and notifies the engine.
func (e *DartExecutor) runWithDebugger(ctx context.Context, config ExecutorConfig, programPath string) (*ExecutorResult, error) {
	dartPath, err := e.findDart()
	if err != nil {
		return nil, fmt.Errorf("dart not found in PATH: %w", err)
	}

	// Create the debug command
	cmd, dbg, err := debugCommand(ctx, dartPath, programPath, config.EntryPoint, config.Args)
	if err != nil {
		return nil, fmt.Errorf("failed to create debug command: %w", err)
	}
	defer dbg.Cleanup()

	// Set up environment variables
	env := e.buildEnvironment(config)
	cmd.Env = env

	// Direct stdout and stderr to the parent process
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// Start the command (don't wait for completion yet)
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("failed to start Dart program with debugger: %w", err)
	}

	// Wait for VM service to be available
	if err := waitForVMServiceByPolling(ctx, dbg.Port); err != nil {
		// If we can't connect to VM service, kill the process and return error
		_ = cmd.Process.Kill()
		return nil, fmt.Errorf("failed to start VM service: %w", err)
	}

	// Notify the engine about the debugging session
	if config.EngineClient != nil {
		// Start debugging notification in a goroutine so we don't block
		go func() {
			err := startDebugging(ctx, config.EngineClient, dbg, "Pulumi: Program (Dart)")
			if err != nil {
				// Log the error but don't fail the program
				fmt.Fprintf(os.Stderr, "Warning: failed to notify engine about debugger: %v\n", err)
			}
		}()
	}

	// Wait for the command to finish
	err = cmd.Wait()
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

// buildRunCommand creates a command for "dart run" execution mode.
func (e *DartExecutor) buildRunCommand(ctx context.Context, config ExecutorConfig, programPath string) (*exec.Cmd, error) {
	dartPath, err := e.findDart()
	if err != nil {
		return nil, fmt.Errorf("dart not found in PATH: %w", err)
	}

	// Build the command arguments using "dart run"
	args := []string{"run"}

	// Add entry point if specified
	if config.EntryPoint != "" {
		args = append(args, config.EntryPoint)
	}

	args = append(args, config.Args...)

	cmd := exec.CommandContext(ctx, dartPath, args...)
	cmd.Dir = programPath

	return cmd, nil
}

// aotCommandResult contains the command and cleanup info for AOT execution.
type aotCommandResult struct {
	cmd          *exec.Cmd
	snapshotPath string // Path to the AOT snapshot that should be cleaned up
}

// buildAotCommand creates a command for AOT execution mode.
// This compiles the Dart program to an AOT snapshot and runs it with dartaotruntime.
// Returns the command and the snapshot path for cleanup.
func (e *DartExecutor) buildAotCommand(ctx context.Context, config ExecutorConfig, programPath string) (*aotCommandResult, error) {
	dartPath, err := e.findDart()
	if err != nil {
		return nil, fmt.Errorf("dart not found in PATH: %w", err)
	}

	// First, compile to AOT snapshot
	snapshotPath := filepath.Join(programPath, ".dart_tool", "pulumi_aot.aot")
	mainFile := filepath.Join(programPath, "bin", "main.dart")

	// Check if bin/main.dart exists, otherwise try lib/main.dart
	if _, err := os.Stat(mainFile); os.IsNotExist(err) {
		mainFile = filepath.Join(programPath, "lib", "main.dart")
		if _, err := os.Stat(mainFile); os.IsNotExist(err) {
			return nil, fmt.Errorf("cannot find main.dart in bin/ or lib/ directories")
		}
	}

	// Ensure .dart_tool directory exists
	if err := os.MkdirAll(filepath.Dir(snapshotPath), 0755); err != nil {
		return nil, fmt.Errorf("failed to create .dart_tool directory: %w", err)
	}

	// Compile to AOT snapshot
	compileCmd := exec.CommandContext(ctx, dartPath, "compile", "aot-snapshot", "-o", snapshotPath, mainFile)
	compileCmd.Dir = programPath
	compileCmd.Stdout = os.Stdout
	compileCmd.Stderr = os.Stderr

	if err := compileCmd.Run(); err != nil {
		return nil, fmt.Errorf("failed to compile AOT snapshot: %w", err)
	}

	// Find dartaotruntime
	dartaotruntime, err := e.findDartAotRuntime()
	if err != nil {
		return nil, fmt.Errorf("dartaotruntime not found: %w", err)
	}

	// Run the AOT snapshot
	args := []string{snapshotPath}
	args = append(args, config.Args...)

	cmd := exec.CommandContext(ctx, dartaotruntime, args...)
	cmd.Dir = programPath

	return &aotCommandResult{
		cmd:          cmd,
		snapshotPath: snapshotPath,
	}, nil
}

// buildBinaryCommand creates a command for pre-compiled binary execution mode.
func (e *DartExecutor) buildBinaryCommand(ctx context.Context, config ExecutorConfig, programPath string) (*exec.Cmd, error) {
	if config.BinaryPath == "" {
		return nil, fmt.Errorf("binary path not specified in runtime options")
	}

	// Resolve binary path relative to program directory
	binaryPath := config.BinaryPath
	if !filepath.IsAbs(binaryPath) {
		binaryPath = filepath.Join(programPath, binaryPath)
	}

	// Verify binary exists
	if _, err := os.Stat(binaryPath); os.IsNotExist(err) {
		return nil, fmt.Errorf("binary not found at %s", binaryPath)
	}

	args := config.Args

	cmd := exec.CommandContext(ctx, binaryPath, args...)
	cmd.Dir = programPath

	return cmd, nil
}

// buildEnvironment creates the environment variables for the Dart program.
func (e *DartExecutor) buildEnvironment(config ExecutorConfig) []string {
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

	return env
}

// findDartAotRuntime returns the path to the dartaotruntime executable.
func (e *DartExecutor) findDartAotRuntime() (string, error) {
	// dartaotruntime is typically in the same directory as dart
	dartPath, err := e.findDart()
	if err != nil {
		return "", err
	}

	// Try dartaotruntime in the same directory
	dartDir := filepath.Dir(dartPath)
	aotRuntimePath := filepath.Join(dartDir, "dartaotruntime")
	if _, err := os.Stat(aotRuntimePath); err == nil {
		return aotRuntimePath, nil
	}

	// On Windows, try with .exe extension
	aotRuntimePath = filepath.Join(dartDir, "dartaotruntime.exe")
	if _, err := os.Stat(aotRuntimePath); err == nil {
		return aotRuntimePath, nil
	}

	// Try looking in PATH
	if path, err := exec.LookPath("dartaotruntime"); err == nil {
		return path, nil
	}

	return "", fmt.Errorf("dartaotruntime not found in dart directory or PATH")
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

// findDart returns the path to the dart executable.
func (e *DartExecutor) findDart() (string, error) {
	if e.dartPath != "" {
		return e.dartPath, nil
	}
	return exec.LookPath("dart")
}
