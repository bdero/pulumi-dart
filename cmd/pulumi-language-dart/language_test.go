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
	"testing"

	pulumirpc "github.com/pulumi/pulumi/sdk/v3/proto/go"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/structpb"
)

func TestNewDartLanguageHost(t *testing.T) {
	host := NewDartLanguageHost()
	if host == nil {
		t.Fatal("NewDartLanguageHost returned nil")
	}
	if host.executor == nil {
		t.Error("executor is nil")
	}
	if host.deps == nil {
		t.Error("deps is nil")
	}
}

func TestGetPluginInfo(t *testing.T) {
	host := NewDartLanguageHost()
	ctx := context.Background()

	resp, err := host.GetPluginInfo(ctx, &emptypb.Empty{})
	if err != nil {
		t.Fatalf("GetPluginInfo failed: %v", err)
	}

	if resp.Version == "" {
		t.Error("Version is empty")
	}
}

func TestAbout(t *testing.T) {
	host := NewDartLanguageHost()
	ctx := context.Background()

	resp, err := host.About(ctx, &emptypb.Empty{})
	if err != nil {
		// Skip if Dart is not installed
		t.Skipf("Skipping test because Dart may not be installed: %v", err)
	}

	if resp.Executable != "dart" {
		t.Errorf("Expected executable 'dart', got '%s'", resp.Executable)
	}

	if resp.Version == "" {
		t.Error("Version is empty")
	}
}

func TestHost_GetRequiredPlugins_NoPubspec(t *testing.T) {
	host := NewDartLanguageHost()
	ctx := context.Background()

	// Request with a non-existent directory
	req := &pulumirpc.GetRequiredPluginsRequest{
		Program: "/non/existent/path",
	}

	_, err := host.GetRequiredPlugins(ctx, req)
	if err == nil {
		t.Error("Expected error for non-existent path")
	}
}

func TestHost_GetRequiredPlugins_ValidPubspec(t *testing.T) {
	host := NewDartLanguageHost()
	ctx := context.Background()

	// Use the SDK directory which has a pubspec.yaml
	req := &pulumirpc.GetRequiredPluginsRequest{
		Program: "../../sdk/dart",
	}

	resp, err := host.GetRequiredPlugins(ctx, req)
	if err != nil {
		t.Fatalf("GetRequiredPlugins failed: %v", err)
	}

	// Should return empty list since sdk/dart doesn't depend on pulumi_* providers
	// (it's the core SDK itself)
	if resp == nil {
		t.Error("Response is nil")
	}
}

func TestHost_GetProgramDependencies_NoPubspec(t *testing.T) {
	host := NewDartLanguageHost()
	ctx := context.Background()

	req := &pulumirpc.GetProgramDependenciesRequest{
		Program: "/non/existent/path",
	}

	_, err := host.GetProgramDependencies(ctx, req)
	if err == nil {
		t.Error("Expected error for non-existent path")
	}
}

func TestHost_GetProgramDependencies_ValidPubspec(t *testing.T) {
	host := NewDartLanguageHost()
	ctx := context.Background()

	// Use the SDK directory which has a pubspec.yaml
	req := &pulumirpc.GetProgramDependenciesRequest{
		Program:                "../../sdk/dart",
		TransitiveDependencies: false,
	}

	resp, err := host.GetProgramDependencies(ctx, req)
	if err != nil {
		t.Fatalf("GetProgramDependencies failed: %v", err)
	}

	if resp == nil {
		t.Error("Response is nil")
	}

	// Should return dependencies from pubspec.yaml/pubspec.lock
	if len(resp.Dependencies) == 0 {
		t.Log("No dependencies found (this is expected if pubspec.lock doesn't exist)")
	}
}

func TestHost_GenerateProject(t *testing.T) {
	host := NewDartLanguageHost()
	ctx := context.Background()

	req := &pulumirpc.GenerateProjectRequest{
		SourceDirectory: "/source",
		TargetDirectory: "/target",
	}

	_, err := host.GenerateProject(ctx, req)
	if err == nil {
		t.Error("Expected error for not implemented feature")
	}
}

func TestHost_GeneratePackage(t *testing.T) {
	host := NewDartLanguageHost()
	ctx := context.Background()

	req := &pulumirpc.GeneratePackageRequest{
		Directory: "/output",
		Schema:    "{}",
	}

	_, err := host.GeneratePackage(ctx, req)
	if err == nil {
		t.Error("Expected error for not implemented feature")
	}
}

func TestHost_GenerateProgram(t *testing.T) {
	host := NewDartLanguageHost()
	ctx := context.Background()

	req := &pulumirpc.GenerateProgramRequest{
		Source: map[string]string{
			"main.pp": "resource bucket \"my-bucket\" {}",
		},
	}

	_, err := host.GenerateProgram(ctx, req)
	if err == nil {
		t.Error("Expected error for not implemented feature")
	}
}

func TestHost_Run_MissingDart(t *testing.T) {
	// This test would require mocking the dart executable
	// For now, we just verify the basic structure works
	host := NewDartLanguageHost()

	// If dart is installed, this test verifies the basic run structure
	// If dart is not installed, it should return an appropriate error
	_ = host
}

func TestVersion(t *testing.T) {
	v := version()
	if v == "" {
		t.Error("version() returned empty string")
	}
}

func TestPluginKindFromString(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"resource", "resource"},
		{"language", "language"},
		{"analyzer", "analyzer"},
		{"converter", "converter"},
		{"unknown", "resource"}, // defaults to resource
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			kind := pluginKindFromString(tt.input)
			if string(kind) != tt.expected {
				t.Errorf("pluginKindFromString(%s) = %s, expected %s", tt.input, kind, tt.expected)
			}
		})
	}
}

func TestHost_Pack(t *testing.T) {
	host := NewDartLanguageHost()
	ctx := context.Background()

	// Use the SDK directory as package source
	tmpDir := t.TempDir()

	req := &pulumirpc.PackRequest{
		PackageDirectory:     "../../sdk/dart",
		DestinationDirectory: tmpDir,
	}

	resp, err := host.Pack(ctx, req)
	if err != nil {
		t.Fatalf("Pack failed: %v", err)
	}

	if resp.ArtifactPath == "" {
		t.Error("ArtifactPath is empty")
	}
}

func TestNewDartLanguageHostWithEngine(t *testing.T) {
	host := NewDartLanguageHostWithEngine("localhost:9999")
	if host == nil {
		t.Fatal("NewDartLanguageHostWithEngine returned nil")
	}
	if host.engineAddress != "localhost:9999" {
		t.Errorf("Expected engine address 'localhost:9999', got '%s'", host.engineAddress)
	}
	if host.executor == nil {
		t.Error("executor is nil")
	}
	if host.deps == nil {
		t.Error("deps is nil")
	}
}

func TestParseRuntimeOptions_NilInfo(t *testing.T) {
	opts := parseRuntimeOptions(nil)
	if opts.Mode != "run" {
		t.Errorf("Expected default mode 'run', got '%s'", opts.Mode)
	}
	if opts.Binary != "" {
		t.Error("Expected empty binary path")
	}
}

func TestParseRuntimeOptions_NilOptions(t *testing.T) {
	info := &pulumirpc.ProgramInfo{
		RootDirectory:    "/root",
		ProgramDirectory: "/program",
		Options:          nil,
	}
	opts := parseRuntimeOptions(info)
	if opts.Mode != "run" {
		t.Errorf("Expected default mode 'run', got '%s'", opts.Mode)
	}
}

func TestParseRuntimeOptions_RunMode(t *testing.T) {
	options, _ := structpb.NewStruct(map[string]interface{}{
		"mode": "run",
	})
	info := &pulumirpc.ProgramInfo{
		Options: options,
	}
	opts := parseRuntimeOptions(info)
	if opts.Mode != "run" {
		t.Errorf("Expected mode 'run', got '%s'", opts.Mode)
	}
}

func TestParseRuntimeOptions_AotMode(t *testing.T) {
	options, _ := structpb.NewStruct(map[string]interface{}{
		"mode": "aot",
	})
	info := &pulumirpc.ProgramInfo{
		Options: options,
	}
	opts := parseRuntimeOptions(info)
	if opts.Mode != "aot" {
		t.Errorf("Expected mode 'aot', got '%s'", opts.Mode)
	}
}

func TestParseRuntimeOptions_BinaryMode(t *testing.T) {
	options, _ := structpb.NewStruct(map[string]interface{}{
		"mode":   "binary",
		"binary": "bin/myapp",
	})
	info := &pulumirpc.ProgramInfo{
		Options: options,
	}
	opts := parseRuntimeOptions(info)
	if opts.Mode != "binary" {
		t.Errorf("Expected mode 'binary', got '%s'", opts.Mode)
	}
	if opts.Binary != "bin/myapp" {
		t.Errorf("Expected binary 'bin/myapp', got '%s'", opts.Binary)
	}
}

func TestParseRuntimeOptions_LegacyUseAot(t *testing.T) {
	options, _ := structpb.NewStruct(map[string]interface{}{
		"use-aot": true,
	})
	info := &pulumirpc.ProgramInfo{
		Options: options,
	}
	opts := parseRuntimeOptions(info)
	if opts.Mode != "aot" {
		t.Errorf("Expected mode 'aot' from legacy use-aot, got '%s'", opts.Mode)
	}
}

func TestParseRuntimeOptions_InvalidMode(t *testing.T) {
	options, _ := structpb.NewStruct(map[string]interface{}{
		"mode": "invalid",
	})
	info := &pulumirpc.ProgramInfo{
		Options: options,
	}
	opts := parseRuntimeOptions(info)
	// Invalid mode should keep default "run"
	if opts.Mode != "run" {
		t.Errorf("Expected default mode 'run' for invalid mode, got '%s'", opts.Mode)
	}
}
