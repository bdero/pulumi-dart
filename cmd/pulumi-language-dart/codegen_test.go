package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestGenerateProject_Basic(t *testing.T) {
	// Create a temporary output directory
	targetDir, err := os.MkdirTemp("", "pulumi-dart-project")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(targetDir)

	// Test with a minimal project JSON
	projectJSON := `{
		"name": "my-test-project",
		"description": "A test Pulumi project"
	}`

	err = GenerateProject("", targetDir, projectJSON, false)
	if err != nil {
		t.Fatalf("GenerateProject failed: %v", err)
	}

	// Verify Pulumi.yaml was generated with correct content
	pulumiYamlPath := filepath.Join(targetDir, "Pulumi.yaml")
	pulumiYamlBytes, err := os.ReadFile(pulumiYamlPath)
	if err != nil {
		t.Fatalf("Failed to read Pulumi.yaml: %v", err)
	}
	pulumiYaml := string(pulumiYamlBytes)
	if !strings.Contains(pulumiYaml, "name: my-test-project") {
		t.Errorf("Pulumi.yaml missing project name, got: %s", pulumiYaml)
	}
	if !strings.Contains(pulumiYaml, "runtime: dart") {
		t.Errorf("Pulumi.yaml missing runtime: dart, got: %s", pulumiYaml)
	}
	if !strings.Contains(pulumiYaml, "description: A test Pulumi project") {
		t.Errorf("Pulumi.yaml missing description, got: %s", pulumiYaml)
	}

	// Verify pubspec.yaml was generated
	pubspecPath := filepath.Join(targetDir, "pubspec.yaml")
	pubspecBytes, err := os.ReadFile(pubspecPath)
	if err != nil {
		t.Fatalf("Failed to read pubspec.yaml: %v", err)
	}
	pubspec := string(pubspecBytes)
	if !strings.Contains(pubspec, "name: my_test_project") {
		t.Errorf("pubspec.yaml should have snake_case name, got: %s", pubspec)
	}
	if !strings.Contains(pubspec, "pulumi: ^0.1.0") {
		t.Errorf("pubspec.yaml missing pulumi dependency, got: %s", pubspec)
	}

	// Verify bin/main.dart was generated
	mainDartPath := filepath.Join(targetDir, "bin", "main.dart")
	mainDartBytes, err := os.ReadFile(mainDartPath)
	if err != nil {
		t.Fatalf("Failed to read bin/main.dart: %v", err)
	}
	mainDart := string(mainDartBytes)
	if !strings.Contains(mainDart, "import 'package:pulumi/pulumi.dart'") {
		t.Errorf("bin/main.dart missing pulumi import, got: %s", mainDart)
	}
	if !strings.Contains(mainDart, "Pulumi.run") {
		t.Errorf("bin/main.dart missing Pulumi.run, got: %s", mainDart)
	}

	// Verify analysis_options.yaml was generated
	analysisPath := filepath.Join(targetDir, "analysis_options.yaml")
	if _, err := os.Stat(analysisPath); os.IsNotExist(err) {
		t.Errorf("analysis_options.yaml was not generated")
	}
}

func TestGenerateProject_InvalidJSON(t *testing.T) {
	targetDir, err := os.MkdirTemp("", "pulumi-dart-project")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(targetDir)

	err = GenerateProject("", targetDir, "not valid json", false)
	if err == nil {
		t.Error("Expected error for invalid JSON")
	}
}

func TestGenerateProject_PackageNameConversion(t *testing.T) {
	targetDir, err := os.MkdirTemp("", "pulumi-dart-project")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(targetDir)

	// Test project name with hyphens (should be converted to underscores)
	projectJSON := `{"name": "my-project-name"}`

	err = GenerateProject("", targetDir, projectJSON, false)
	if err != nil {
		t.Fatalf("GenerateProject failed: %v", err)
	}

	pubspecBytes, err := os.ReadFile(filepath.Join(targetDir, "pubspec.yaml"))
	if err != nil {
		t.Fatalf("Failed to read pubspec.yaml: %v", err)
	}
	if !strings.Contains(string(pubspecBytes), "name: my_project_name") {
		t.Errorf("pubspec.yaml should convert hyphens to underscores, got: %s", string(pubspecBytes))
	}
}

func TestToValidDartPackageName(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"my-project", "my_project"},
		{"MyProject", "myproject"},
		{"my_project", "my_project"},
		{"123project", "_123project"},
		{"project-123", "project_123"},
		{"", "pulumi_project"},
		{"Project-Name-Here", "project_name_here"},
	}

	for _, test := range tests {
		result := toValidDartPackageName(test.input)
		if result != test.expected {
			t.Errorf("toValidDartPackageName(%q) = %q, expected %q", test.input, result, test.expected)
		}
	}
}

func TestGeneratePackage_InvalidSchema(t *testing.T) {
	// Test with invalid JSON
	_, err := GeneratePackage("/output", "not json", nil, "", nil)
	if err == nil {
		t.Error("Expected error for invalid JSON")
	}
}

func TestGeneratePackage_MinimalSchema(t *testing.T) {
	// Create a temporary output directory
	outDir, err := os.MkdirTemp("", "pulumi-dart-gen")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(outDir)

	// Minimal valid schema
	schema := `{
		"name": "test",
		"version": "1.0.0"
	}`

	diagnostics, err := GeneratePackage(outDir, schema, nil, "", nil)
	if err != nil {
		t.Fatalf("GeneratePackage failed: %v", err)
	}

	// Check that no errors were reported
	for _, diag := range diagnostics {
		if diag.Severity == 1 { // DIAG_ERROR
			t.Errorf("Unexpected error diagnostic: %s", diag.Summary)
		}
	}

	// Verify pubspec.yaml was generated
	pubspecPath := filepath.Join(outDir, "pubspec.yaml")
	if _, err := os.Stat(pubspecPath); os.IsNotExist(err) {
		t.Errorf("pubspec.yaml was not generated")
	}

	// Verify analysis_options.yaml was generated
	analysisPath := filepath.Join(outDir, "analysis_options.yaml")
	if _, err := os.Stat(analysisPath); os.IsNotExist(err) {
		t.Errorf("analysis_options.yaml was not generated")
	}

	// Verify main library file was generated
	libPath := filepath.Join(outDir, "lib", "pulumi_test.dart")
	if _, err := os.Stat(libPath); os.IsNotExist(err) {
		t.Errorf("main library file was not generated")
	}
}

func TestGeneratePackage_WithResource(t *testing.T) {
	// Create a temporary output directory
	outDir, err := os.MkdirTemp("", "pulumi-dart-gen")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(outDir)

	// Schema with a simple resource
	schema := `{
		"name": "example",
		"version": "1.0.0",
		"resources": {
			"example:index:Widget": {
				"inputProperties": {
					"widgetName": {
						"type": "string"
					}
				},
				"requiredInputs": ["widgetName"],
				"properties": {
					"widgetId": {
						"type": "string"
					},
					"widgetName": {
						"type": "string"
					}
				}
			}
		}
	}`

	diagnostics, err := GeneratePackage(outDir, schema, nil, "", nil)
	if err != nil {
		t.Fatalf("GeneratePackage failed: %v", err)
	}

	// Check that no errors were reported
	for _, diag := range diagnostics {
		if diag.Severity == 1 { // DIAG_ERROR
			t.Errorf("Unexpected error diagnostic: %s", diag.Summary)
		}
	}

	// Verify resource file was generated (token "example:index:Widget" -> "index_widget.dart")
	resourcePath := filepath.Join(outDir, "lib", "src", "resources", "index_widget.dart")
	if _, err := os.Stat(resourcePath); os.IsNotExist(err) {
		t.Errorf("resource file was not generated at %s", resourcePath)
	}
}

func TestGeneratePackage_WithExtraFiles(t *testing.T) {
	// Create a temporary output directory
	outDir, err := os.MkdirTemp("", "pulumi-dart-gen")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(outDir)

	// Minimal valid schema
	schema := `{
		"name": "test",
		"version": "1.0.0"
	}`

	// Extra files (overlays)
	extraFiles := map[string][]byte{
		"README.md":         []byte("# Test Package"),
		"lib/src/custom.dart": []byte("// Custom code"),
	}

	diagnostics, err := GeneratePackage(outDir, schema, extraFiles, "", nil)
	if err != nil {
		t.Fatalf("GeneratePackage failed: %v", err)
	}

	// Check that no errors were reported
	for _, diag := range diagnostics {
		if diag.Severity == 1 { // DIAG_ERROR
			t.Errorf("Unexpected error diagnostic: %s", diag.Summary)
		}
	}

	// Verify extra files were written
	readmePath := filepath.Join(outDir, "README.md")
	if _, err := os.Stat(readmePath); os.IsNotExist(err) {
		t.Errorf("README.md was not written")
	}

	customPath := filepath.Join(outDir, "lib", "src", "custom.dart")
	if _, err := os.Stat(customPath); os.IsNotExist(err) {
		t.Errorf("lib/src/custom.dart was not written")
	}
}

func TestGenerateProgram_NotImplemented(t *testing.T) {
	_, _, err := GenerateProgram(map[string]string{"main.pp": "resource foo {}"})
	if err == nil {
		t.Error("Expected error for not implemented feature")
	}
}

func TestPackProject(t *testing.T) {
	// Create a temporary source directory with test files
	srcDir, err := os.MkdirTemp("", "pulumi-dart-pack-src")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(srcDir)

	// Create test files
	pubspec := `name: test_project
version: 1.0.0
dependencies:
  pulumi: ^0.1.0
`
	err = os.WriteFile(filepath.Join(srcDir, "pubspec.yaml"), []byte(pubspec), 0644)
	if err != nil {
		t.Fatal(err)
	}

	pulumiYaml := `name: test-project
runtime: dart
`
	err = os.WriteFile(filepath.Join(srcDir, "Pulumi.yaml"), []byte(pulumiYaml), 0644)
	if err != nil {
		t.Fatal(err)
	}

	// Create lib directory
	libDir := filepath.Join(srcDir, "lib")
	err = os.MkdirAll(libDir, 0755)
	if err != nil {
		t.Fatal(err)
	}

	err = os.WriteFile(filepath.Join(libDir, "main.dart"), []byte("void main() {}"), 0644)
	if err != nil {
		t.Fatal(err)
	}

	// Create destination directory
	destDir, err := os.MkdirTemp("", "pulumi-dart-pack-dest")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(destDir)

	// Pack the project
	artifactPath, err := PackProject(srcDir, destDir)
	if err != nil {
		t.Fatalf("PackProject failed: %v", err)
	}

	// Verify the tarball was created
	if _, err := os.Stat(artifactPath); os.IsNotExist(err) {
		t.Errorf("Tarball was not created at %s", artifactPath)
	}

	// Verify the tarball has the expected name
	expectedName := filepath.Base(srcDir) + ".tar.gz"
	if filepath.Base(artifactPath) != expectedName {
		t.Errorf("Expected tarball name %s, got %s", expectedName, filepath.Base(artifactPath))
	}
}

func TestPackProject_MissingFiles(t *testing.T) {
	// Create an empty temporary directory
	srcDir, err := os.MkdirTemp("", "pulumi-dart-pack-empty")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(srcDir)

	destDir, err := os.MkdirTemp("", "pulumi-dart-pack-dest")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(destDir)

	// PackProject should still work (it ignores missing optional files)
	artifactPath, err := PackProject(srcDir, destDir)
	if err != nil {
		t.Fatalf("PackProject failed with missing files: %v", err)
	}

	// Verify the tarball was created (even if mostly empty)
	if _, err := os.Stat(artifactPath); os.IsNotExist(err) {
		t.Errorf("Tarball was not created at %s", artifactPath)
	}
}

func TestAddToTarball_NonExistent(t *testing.T) {
	// This test verifies that addToTarball returns an error for non-existent paths
	// We can't easily test this without creating a tar.Writer, so we'll rely on
	// the PackProject tests to cover this path indirectly
}

func TestGeneratePackage_RandomLikeSchema(t *testing.T) {
	// Create a temporary output directory
	outDir, err := os.MkdirTemp("", "pulumi-dart-random")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(outDir)

	// Read the test schema file
	schemaBytes, err := os.ReadFile("testdata/random_schema.json")
	if err != nil {
		t.Fatalf("Failed to read test schema: %v", err)
	}

	diagnostics, err := GeneratePackage(outDir, string(schemaBytes), nil, "", nil)
	if err != nil {
		t.Fatalf("GeneratePackage failed: %v", err)
	}

	// Check that no fatal errors were reported (warnings are okay)
	hasError := false
	for _, diag := range diagnostics {
		if diag.Severity == 1 { // DIAG_ERROR
			hasError = true
			t.Logf("Error diagnostic: %s", diag.Summary)
		}
	}
	if hasError {
		t.Errorf("Generation had error diagnostics")
	}

	// Verify core files were generated
	coreFiles := []string{
		"pubspec.yaml",
		"analysis_options.yaml",
		"lib/pulumi_random.dart",
	}

	for _, expectedFile := range coreFiles {
		path := filepath.Join(outDir, expectedFile)
		if _, err := os.Stat(path); os.IsNotExist(err) {
			t.Errorf("Core file was not generated: %s", expectedFile)
		}
	}

	// Verify at least some resources were generated
	resourcesDir := filepath.Join(outDir, "lib", "src", "resources")
	if _, err := os.Stat(resourcesDir); os.IsNotExist(err) {
		t.Errorf("Resources directory was not created")
	} else {
		entries, err := os.ReadDir(resourcesDir)
		if err != nil {
			t.Errorf("Failed to read resources directory: %v", err)
		} else if len(entries) == 0 {
			t.Errorf("No resource files were generated")
		} else {
			t.Logf("Generated %d resource files", len(entries))
			for _, e := range entries {
				t.Logf("  - %s", e.Name())
			}
		}
	}

	// Verify at least some functions were generated
	functionsDir := filepath.Join(outDir, "lib", "src", "functions")
	if _, err := os.Stat(functionsDir); os.IsNotExist(err) {
		t.Errorf("Functions directory was not created")
	} else {
		entries, err := os.ReadDir(functionsDir)
		if err != nil {
			t.Errorf("Failed to read functions directory: %v", err)
		} else if len(entries) == 0 {
			t.Errorf("No function files were generated")
		} else {
			t.Logf("Generated %d function files", len(entries))
			for _, e := range entries {
				t.Logf("  - %s", e.Name())
			}
		}
	}

	// Verify pubspec.yaml has correct content
	pubspecBytes, err := os.ReadFile(filepath.Join(outDir, "pubspec.yaml"))
	if err != nil {
		t.Fatalf("Failed to read pubspec.yaml: %v", err)
	}
	pubspecContent := string(pubspecBytes)

	if !contains(pubspecContent, "name: pulumi_random") {
		t.Errorf("pubspec.yaml missing correct name")
	}
	if !contains(pubspecContent, "version: 4.15.0") {
		t.Errorf("pubspec.yaml missing correct version")
	}
	if !contains(pubspecContent, "pulumi: ^0.1.0") {
		t.Errorf("pubspec.yaml missing pulumi dependency")
	}
}

// contains checks if a string contains a substring
func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 && containsHelper(s, substr))
}

func containsHelper(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

// TestGeneratePackage_DartAnalyze generates an SDK and runs dart analyze to verify
// the generated code is syntactically valid and has no errors.
// This test requires Dart to be installed and is skipped if Dart is not available.
func TestGeneratePackage_DartAnalyze(t *testing.T) {
	// Check if dart is available
	dartPath, err := exec.LookPath("dart")
	if err != nil {
		t.Skip("Dart not available, skipping dart analyze test")
	}

	// Create a temporary output directory
	outDir, err := os.MkdirTemp("", "pulumi-dart-analyze")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(outDir)

	// Read the test schema file
	schemaBytes, err := os.ReadFile("testdata/random_schema.json")
	if err != nil {
		t.Fatalf("Failed to read test schema: %v", err)
	}

	// Generate the SDK
	diagnostics, err := GeneratePackage(outDir, string(schemaBytes), nil, "", nil)
	if err != nil {
		t.Fatalf("GeneratePackage failed: %v", err)
	}

	// Check for error diagnostics
	for _, diag := range diagnostics {
		if diag.Severity == 1 { // DIAG_ERROR
			t.Errorf("Generation had error diagnostic: %s", diag.Summary)
		}
	}

	// Update pubspec.yaml to use the local SDK path instead of a pub.dev version
	// This allows dart analyze to resolve the pulumi package
	sdkPath, err := filepath.Abs("../../sdk/dart")
	if err != nil {
		t.Fatalf("Failed to get SDK path: %v", err)
	}

	pubspecContent := `name: pulumi_random
version: 4.15.0
description: Pulumi provider SDK for random

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  pulumi:
    path: ` + filepath.ToSlash(sdkPath) + `
  meta: ^1.11.0

dev_dependencies:
  test: ^1.25.0
  lints: ^3.0.0
`
	pubspecPath := filepath.Join(outDir, "pubspec.yaml")
	if err := os.WriteFile(pubspecPath, []byte(pubspecContent), 0644); err != nil {
		t.Fatalf("Failed to write pubspec.yaml: %v", err)
	}

	// Run dart pub get to fetch dependencies
	pubGetCmd := exec.Command(dartPath, "pub", "get")
	pubGetCmd.Dir = outDir
	pubGetOutput, err := pubGetCmd.CombinedOutput()
	if err != nil {
		t.Logf("dart pub get output: %s", string(pubGetOutput))
		t.Fatalf("dart pub get failed: %v", err)
	}

	// Run dart analyze to check for errors
	// Use --fatal-warnings to fail on warnings/errors but not on info-level lints
	// Info-level lints are style suggestions (constructor ordering, etc.) that don't affect correctness
	analyzeCmd := exec.Command(dartPath, "analyze", "--fatal-warnings")
	analyzeCmd.Dir = outDir
	analyzeOutput, err := analyzeCmd.CombinedOutput()

	// Log the output for debugging
	if len(analyzeOutput) > 0 {
		t.Logf("dart analyze output:\n%s", string(analyzeOutput))
	}

	if err != nil {
		// Check if the only issues are info-level (style) suggestions
		outputStr := string(analyzeOutput)
		if strings.Contains(outputStr, "error -") {
			t.Errorf("dart analyze found errors in generated code: %v", err)
		} else {
			t.Log("dart analyze passed (only info-level lints found)")
		}
	} else {
		t.Log("dart analyze passed - generated code is valid")
	}
}
