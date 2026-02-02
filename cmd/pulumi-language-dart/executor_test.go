package main

import (
	"context"
	"os"
	"testing"
)

func TestNewDartExecutor(t *testing.T) {
	executor := NewDartExecutor()
	if executor == nil {
		t.Fatal("NewDartExecutor returned nil")
	}
}

func TestGetDartVersion(t *testing.T) {
	executor := NewDartExecutor()

	version, err := executor.GetDartVersion()
	if err != nil {
		t.Skipf("Skipping test because Dart may not be installed: %v", err)
	}

	if version == "" {
		t.Error("Dart version is empty")
	}

	t.Logf("Found Dart version: %s", version)
}

func TestValidateDartInstallation(t *testing.T) {
	executor := NewDartExecutor()

	err := executor.ValidateDartInstallation()
	if err != nil {
		t.Skipf("Skipping test because Dart may not be installed or is < 3.0: %v", err)
	}
}

func TestFindDart(t *testing.T) {
	executor := NewDartExecutor()

	path, err := executor.findDart()
	if err != nil {
		t.Skipf("Skipping test because Dart may not be installed: %v", err)
	}

	if path == "" {
		t.Error("Dart path is empty")
	}

	t.Logf("Found Dart at: %s", path)
}

func TestFindDart_WithCustomPath(t *testing.T) {
	executor := &DartExecutor{
		dartPath: "/custom/dart/path",
	}

	path, err := executor.findDart()
	if err != nil {
		t.Fatalf("findDart failed: %v", err)
	}

	if path != "/custom/dart/path" {
		t.Errorf("Expected custom path, got %s", path)
	}
}

func TestExecutorConfig(t *testing.T) {
	config := ExecutorConfig{
		Program:        "/path/to/program",
		Pwd:            "/path/to/pwd",
		Args:           []string{"--arg1", "--arg2"},
		Config:         map[string]string{"key": "value"},
		DryRun:         true,
		Parallel:       4,
		MonitorAddress: "localhost:1234",
		EngineAddress:  "localhost:5678",
		Project:        "my-project",
		Stack:          "dev",
		Organization:   "my-org",
		ExecutionMode:  "run",
		BinaryPath:     "",
	}

	if config.Program != "/path/to/program" {
		t.Error("Program not set correctly")
	}
	if config.DryRun != true {
		t.Error("DryRun not set correctly")
	}
	if config.Parallel != 4 {
		t.Error("Parallel not set correctly")
	}
	if config.ExecutionMode != "run" {
		t.Error("ExecutionMode not set correctly")
	}
}

func TestExecutorConfig_BinaryMode(t *testing.T) {
	config := ExecutorConfig{
		Program:       "/path/to/program",
		ExecutionMode: "binary",
		BinaryPath:    "bin/myapp",
	}

	if config.ExecutionMode != "binary" {
		t.Error("ExecutionMode not set correctly")
	}
	if config.BinaryPath != "bin/myapp" {
		t.Error("BinaryPath not set correctly")
	}
}

func TestExecutorConfig_AotMode(t *testing.T) {
	config := ExecutorConfig{
		Program:       "/path/to/program",
		ExecutionMode: "aot",
	}

	if config.ExecutionMode != "aot" {
		t.Error("ExecutionMode not set correctly for AOT")
	}
}

func TestExecutorConfig_QueryMode(t *testing.T) {
	config := ExecutorConfig{
		Program:   "/path/to/program",
		QueryMode: true,
	}

	if config.QueryMode != true {
		t.Error("QueryMode not set correctly")
	}
}

func TestBuildEnvironment(t *testing.T) {
	executor := NewDartExecutor()

	config := ExecutorConfig{
		MonitorAddress: "localhost:1234",
		EngineAddress:  "localhost:5678",
		Project:        "my-project",
		Stack:          "dev",
		Organization:   "my-org",
		Parallel:       4,
		DryRun:         true,
		Config: map[string]string{
			"myapp:key1":       "value1",
			"myapp:nested:key": "value2",
		},
	}

	env := executor.buildEnvironment(config)

	// Check that required env vars are present
	envMap := make(map[string]string)
	for _, e := range env {
		parts := splitEnvVar(e)
		if len(parts) == 2 {
			envMap[parts[0]] = parts[1]
		}
	}

	if envMap["PULUMI_MONITOR"] != "localhost:1234" {
		t.Error("PULUMI_MONITOR not set correctly")
	}
	if envMap["PULUMI_ENGINE"] != "localhost:5678" {
		t.Error("PULUMI_ENGINE not set correctly")
	}
	if envMap["PULUMI_PROJECT"] != "my-project" {
		t.Error("PULUMI_PROJECT not set correctly")
	}
	if envMap["PULUMI_STACK"] != "dev" {
		t.Error("PULUMI_STACK not set correctly")
	}
	if envMap["PULUMI_DRY_RUN"] != "true" {
		t.Error("PULUMI_DRY_RUN not set correctly")
	}
	if envMap["PULUMI_QUERY_MODE"] != "false" {
		t.Error("PULUMI_QUERY_MODE not set correctly (should be false when QueryMode is false)")
	}
	if envMap["PULUMI_CONFIG_MYAPP_KEY1"] != "value1" {
		t.Error("Config key not transformed correctly")
	}
}

func TestBuildEnvironment_QueryMode(t *testing.T) {
	executor := NewDartExecutor()

	config := ExecutorConfig{
		MonitorAddress: "localhost:1234",
		EngineAddress:  "localhost:5678",
		Project:        "my-project",
		Stack:          "dev",
		Organization:   "my-org",
		Parallel:       4,
		DryRun:         false,
		QueryMode:      true,
	}

	env := executor.buildEnvironment(config)

	// Check that required env vars are present
	envMap := make(map[string]string)
	for _, e := range env {
		parts := splitEnvVar(e)
		if len(parts) == 2 {
			envMap[parts[0]] = parts[1]
		}
	}

	if envMap["PULUMI_QUERY_MODE"] != "true" {
		t.Error("PULUMI_QUERY_MODE not set correctly when QueryMode is true")
	}
	if envMap["PULUMI_DRY_RUN"] != "false" {
		t.Error("PULUMI_DRY_RUN not set correctly")
	}
}

func TestBuildEnvironment_ConfigSecretKeys(t *testing.T) {
	executor := NewDartExecutor()

	config := ExecutorConfig{
		MonitorAddress:   "localhost:1234",
		EngineAddress:    "localhost:5678",
		Project:          "my-project",
		Stack:            "dev",
		Organization:     "my-org",
		Parallel:         4,
		DryRun:           false,
		ConfigSecretKeys: []string{"myapp:password", "myapp:apiKey"},
	}

	env := executor.buildEnvironment(config)

	// Check that required env vars are present
	envMap := make(map[string]string)
	for _, e := range env {
		parts := splitEnvVar(e)
		if len(parts) == 2 {
			envMap[parts[0]] = parts[1]
		}
	}

	secretKeysValue, ok := envMap["PULUMI_CONFIG_SECRET_KEYS"]
	if !ok {
		t.Fatal("PULUMI_CONFIG_SECRET_KEYS not set")
	}

	// Verify it's valid JSON containing the expected keys
	expectedJSON := `["myapp:password","myapp:apiKey"]`
	if secretKeysValue != expectedJSON {
		t.Errorf("PULUMI_CONFIG_SECRET_KEYS not set correctly, got %s, expected %s", secretKeysValue, expectedJSON)
	}
}

func TestBuildEnvironment_ConfigSecretKeys_Empty(t *testing.T) {
	executor := NewDartExecutor()

	config := ExecutorConfig{
		MonitorAddress:   "localhost:1234",
		EngineAddress:    "localhost:5678",
		Project:          "my-project",
		Stack:            "dev",
		Organization:     "my-org",
		Parallel:         4,
		DryRun:           false,
		ConfigSecretKeys: []string{}, // Empty slice
	}

	env := executor.buildEnvironment(config)

	// Check that PULUMI_CONFIG_SECRET_KEYS is not set when empty
	envMap := make(map[string]string)
	for _, e := range env {
		parts := splitEnvVar(e)
		if len(parts) == 2 {
			envMap[parts[0]] = parts[1]
		}
	}

	if _, ok := envMap["PULUMI_CONFIG_SECRET_KEYS"]; ok {
		t.Error("PULUMI_CONFIG_SECRET_KEYS should not be set when ConfigSecretKeys is empty")
	}
}

func TestExecutorConfig_ConfigSecretKeys(t *testing.T) {
	config := ExecutorConfig{
		Program:          "/path/to/program",
		ConfigSecretKeys: []string{"myapp:secret1", "myapp:secret2"},
	}

	if len(config.ConfigSecretKeys) != 2 {
		t.Errorf("Expected 2 secret keys, got %d", len(config.ConfigSecretKeys))
	}
	if config.ConfigSecretKeys[0] != "myapp:secret1" {
		t.Errorf("First secret key not set correctly, got %s", config.ConfigSecretKeys[0])
	}
}

// splitEnvVar splits an environment variable string into key and value
func splitEnvVar(env string) []string {
	for i := 0; i < len(env); i++ {
		if env[i] == '=' {
			return []string{env[:i], env[i+1:]}
		}
	}
	return []string{env}
}

func TestBuildBinaryCommand_MissingPath(t *testing.T) {
	executor := NewDartExecutor()

	config := ExecutorConfig{
		Program:       "/path/to/program",
		ExecutionMode: "binary",
		BinaryPath:    "", // Empty path
	}

	_, err := executor.buildBinaryCommand(nil, config, "/path/to/program")
	if err == nil {
		t.Error("Expected error for missing binary path")
	}
}

func TestBuildBinaryCommand_NonExistent(t *testing.T) {
	executor := NewDartExecutor()

	config := ExecutorConfig{
		Program:       "/path/to/program",
		ExecutionMode: "binary",
		BinaryPath:    "/nonexistent/binary",
	}

	_, err := executor.buildBinaryCommand(nil, config, "/path/to/program")
	if err == nil {
		t.Error("Expected error for non-existent binary")
	}
}

func TestExecutorResult(t *testing.T) {
	result := ExecutorResult{
		Error: "test error",
		Bail:  true,
	}

	if result.Error != "test error" {
		t.Error("Error not set correctly")
	}
	if result.Bail != true {
		t.Error("Bail not set correctly")
	}
}

func TestExecutorConfig_WithEntryPoint(t *testing.T) {
	config := ExecutorConfig{
		Program:       "/path/to/program",
		ExecutionMode: "run",
		EntryPoint:    "bin/main.dart",
	}

	if config.EntryPoint != "bin/main.dart" {
		t.Errorf("EntryPoint not set correctly, got %s", config.EntryPoint)
	}
}

func TestBuildRunCommand_WithEntryPoint(t *testing.T) {
	executor := NewDartExecutor()

	config := ExecutorConfig{
		Program:       "/path/to/program",
		ExecutionMode: "run",
		EntryPoint:    "bin/main.dart",
		Args:          []string{"--arg1"},
	}

	ctx := context.Background()
	cmd, err := executor.buildRunCommand(ctx, config, "/path/to/program")
	if err != nil {
		t.Skipf("Skipping test because Dart may not be installed: %v", err)
	}

	// Check that entry point is included in args
	args := cmd.Args
	foundEntryPoint := false
	for _, arg := range args {
		if arg == "bin/main.dart" {
			foundEntryPoint = true
			break
		}
	}

	if !foundEntryPoint {
		t.Errorf("Entry point not found in command args: %v", args)
	}
}

func TestBuildRunCommand_WithoutEntryPoint(t *testing.T) {
	executor := NewDartExecutor()

	config := ExecutorConfig{
		Program:       "/path/to/program",
		ExecutionMode: "run",
		EntryPoint:    "", // Empty entry point
		Args:          []string{"--arg1"},
	}

	ctx := context.Background()
	cmd, err := executor.buildRunCommand(ctx, config, "/path/to/program")
	if err != nil {
		t.Skipf("Skipping test because Dart may not be installed: %v", err)
	}

	// Check that args start with "run" then program args
	// Should NOT have an entry point file
	args := cmd.Args
	if len(args) < 3 {
		t.Fatalf("Expected at least 3 args, got %v", args)
	}

	// args[0] is the dart executable path
	// args[1] should be "run"
	// args[2] should be "--arg1" (not an entry point file)
	if args[1] != "run" {
		t.Errorf("Expected args[1] to be 'run', got %s", args[1])
	}
	if args[2] != "--arg1" {
		t.Errorf("Expected args[2] to be '--arg1', got %s", args[2])
	}
}

func TestAotCommandResult_SnapshotPath(t *testing.T) {
	// Test that aotCommandResult correctly stores the snapshot path for cleanup
	result := aotCommandResult{
		cmd:          nil,
		snapshotPath: "/path/to/.dart_tool/pulumi_aot.aot",
	}

	if result.snapshotPath != "/path/to/.dart_tool/pulumi_aot.aot" {
		t.Errorf("snapshotPath not set correctly, got %s", result.snapshotPath)
	}
}

func TestBuildAotCommand_ReturnsSnapshotPath(t *testing.T) {
	// This test verifies that buildAotCommand returns the snapshot path
	// in the aotCommandResult for cleanup purposes
	executor := NewDartExecutor()

	// Create a temp directory with proper structure
	tempDir := t.TempDir()
	binDir := tempDir + "/bin"
	dartToolDir := tempDir + "/.dart_tool"

	// Create necessary directories
	if err := createDir(binDir); err != nil {
		t.Fatalf("Failed to create bin directory: %v", err)
	}
	if err := createDir(dartToolDir); err != nil {
		t.Fatalf("Failed to create .dart_tool directory: %v", err)
	}

	// Create a minimal main.dart file
	mainDart := binDir + "/main.dart"
	if err := writeFile(mainDart, "void main() {}"); err != nil {
		t.Fatalf("Failed to create main.dart: %v", err)
	}

	config := ExecutorConfig{
		Program:       tempDir,
		ExecutionMode: "aot",
	}

	ctx := context.Background()
	result, err := executor.buildAotCommand(ctx, config, tempDir)
	if err != nil {
		t.Skipf("Skipping test (Dart or dartaotruntime may not be available): %v", err)
	}

	// Verify the snapshot path is set in the result
	expectedSnapshotPath := tempDir + "/.dart_tool/pulumi_aot.aot"
	if result.snapshotPath != expectedSnapshotPath {
		t.Errorf("Expected snapshotPath %s, got %s", expectedSnapshotPath, result.snapshotPath)
	}

	// Verify the command is not nil
	if result.cmd == nil {
		t.Error("Expected cmd to be non-nil")
	}
}

// Helper function to create a directory
func createDir(path string) error {
	return os.MkdirAll(path, 0755)
}

// Helper function to write a file
func writeFile(path, content string) error {
	return os.WriteFile(path, []byte(content), 0644)
}
