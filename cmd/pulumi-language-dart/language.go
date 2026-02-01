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

	"github.com/pulumi/pulumi/sdk/v3/go/common/workspace"
	pulumirpc "github.com/pulumi/pulumi/sdk/v3/proto/go"
	"google.golang.org/protobuf/types/known/emptypb"
)

// DartLanguageHost implements the LanguageRuntime gRPC interface for Dart.
type DartLanguageHost struct {
	pulumirpc.UnimplementedLanguageRuntimeServer

	// executor handles Dart program execution
	executor *DartExecutor

	// deps handles dependency management
	deps *DependencyManager
}

// NewDartLanguageHost creates a new Dart language host.
func NewDartLanguageHost() *DartLanguageHost {
	return &DartLanguageHost{
		executor: NewDartExecutor(),
		deps:     NewDependencyManager(),
	}
}

// GetRequiredPlugins returns the list of plugins required by the Dart program.
//
// This parses pubspec.yaml to find pulumi_* dependencies and maps them to
// plugin requirements.
func (h *DartLanguageHost) GetRequiredPlugins(
	ctx context.Context,
	req *pulumirpc.GetRequiredPluginsRequest,
) (*pulumirpc.GetRequiredPluginsResponse, error) {
	plugins, err := h.deps.GetRequiredPlugins(req.Program)
	if err != nil {
		return nil, fmt.Errorf("failed to get required plugins: %w", err)
	}

	var result []*pulumirpc.PluginDependency
	for _, p := range plugins {
		result = append(result, &pulumirpc.PluginDependency{
			Name:    p.Name,
			Kind:    string(p.Kind),
			Version: p.Version,
			Server:  p.Server,
		})
	}

	return &pulumirpc.GetRequiredPluginsResponse{
		Plugins: result,
	}, nil
}

// Run executes the Dart program.
//
// This is the main entry point for running a Pulumi Dart program. It:
// 1. Sets up environment variables with monitor/engine addresses
// 2. Spawns the Dart process
// 3. Waits for completion and returns the exit code
func (h *DartLanguageHost) Run(
	ctx context.Context,
	req *pulumirpc.RunRequest,
) (*pulumirpc.RunResponse, error) {
	config := ExecutorConfig{
		Program:        req.Program,
		Pwd:            req.Pwd,
		Args:           req.Args,
		Config:         req.Config,
		DryRun:         req.DryRun,
		Parallel:       int(req.Parallel),
		MonitorAddress: req.MonitorAddress,
		EngineAddress:  req.Info.GetRootDirectory(), // Use RootDirectory as a fallback
		Project:        req.Project,
		Stack:          req.Stack,
		Organization:   req.Organization,
	}

	result, err := h.executor.Run(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("failed to run Dart program: %w", err)
	}

	return &pulumirpc.RunResponse{
		Error:  result.Error,
		Bail:   result.Bail,
	}, nil
}

// GetPluginInfo returns metadata about this plugin.
func (h *DartLanguageHost) GetPluginInfo(
	ctx context.Context,
	req *emptypb.Empty,
) (*pulumirpc.PluginInfo, error) {
	return &pulumirpc.PluginInfo{
		Version: version(),
	}, nil
}

// InstallDependencies installs the dependencies for a Dart program.
//
// This runs `dart pub get` in the program directory.
func (h *DartLanguageHost) InstallDependencies(
	req *pulumirpc.InstallDependenciesRequest,
	server pulumirpc.LanguageRuntime_InstallDependenciesServer,
) error {
	return h.deps.InstallDependencies(server.Context(), req.Directory, func(msg string) {
		_ = server.Send(&pulumirpc.InstallDependenciesResponse{
			Stdout: []byte(msg + "\n"),
		})
	})
}

// RuntimeOptionsPrompts returns prompts for runtime configuration.
// Note: This method may not exist in all Pulumi SDK versions.
// Uncomment when supported by the SDK.
/*
func (h *DartLanguageHost) RuntimeOptionsPrompts(
	ctx context.Context,
	req *pulumirpc.RuntimeOptionsRequest,
) (*pulumirpc.RuntimeOptionsResponse, error) {
	// No prompts needed for Dart
	return &pulumirpc.RuntimeOptionsResponse{}, nil
}
*/

// About returns information about the Dart runtime.
func (h *DartLanguageHost) About(
	ctx context.Context,
	req *emptypb.Empty,
) (*pulumirpc.AboutResponse, error) {
	dartVersion, err := h.executor.GetDartVersion()
	if err != nil {
		return nil, fmt.Errorf("failed to get Dart version: %w", err)
	}

	return &pulumirpc.AboutResponse{
		Executable: "dart",
		Version:    dartVersion,
	}, nil
}

// GetProgramDependencies returns the dependencies for a Dart program.
//
// This parses pubspec.lock to get the list of resolved dependencies.
func (h *DartLanguageHost) GetProgramDependencies(
	ctx context.Context,
	req *pulumirpc.GetProgramDependenciesRequest,
) (*pulumirpc.GetProgramDependenciesResponse, error) {
	deps, err := h.deps.GetProgramDependencies(req.Program, req.TransitiveDependencies)
	if err != nil {
		return nil, fmt.Errorf("failed to get program dependencies: %w", err)
	}

	var result []*pulumirpc.DependencyInfo
	for _, d := range deps {
		result = append(result, &pulumirpc.DependencyInfo{
			Name:    d.Name,
			Version: d.Version,
		})
	}

	return &pulumirpc.GetProgramDependenciesResponse{
		Dependencies: result,
	}, nil
}

// GenerateProject creates a new Dart Pulumi project from a template.
func (h *DartLanguageHost) GenerateProject(
	ctx context.Context,
	req *pulumirpc.GenerateProjectRequest,
) (*pulumirpc.GenerateProjectResponse, error) {
	err := GenerateProject(req.SourceDirectory, req.TargetDirectory, req.Project, req.Strict)
	if err != nil {
		return nil, fmt.Errorf("failed to generate project: %w", err)
	}

	return &pulumirpc.GenerateProjectResponse{}, nil
}

// GeneratePackage generates a Dart SDK for a Pulumi package.
func (h *DartLanguageHost) GeneratePackage(
	ctx context.Context,
	req *pulumirpc.GeneratePackageRequest,
) (*pulumirpc.GeneratePackageResponse, error) {
	localDeps := make(map[string]string)
	// LocalDependencies field may not exist in all SDK versions
	diagnostics, err := GeneratePackage(req.Directory, req.Schema, req.ExtraFiles, req.LoaderTarget, localDeps)
	if err != nil {
		return nil, fmt.Errorf("failed to generate package: %w", err)
	}

	return &pulumirpc.GeneratePackageResponse{
		Diagnostics: diagnostics,
	}, nil
}

// GenerateProgram converts PCL (Pulumi Configuration Language) to Dart.
func (h *DartLanguageHost) GenerateProgram(
	ctx context.Context,
	req *pulumirpc.GenerateProgramRequest,
) (*pulumirpc.GenerateProgramResponse, error) {
	// PCL to Dart conversion is not yet implemented
	return nil, fmt.Errorf("GenerateProgram is not yet implemented for Dart")
}

// Pack packages the Dart program for deployment.
func (h *DartLanguageHost) Pack(
	ctx context.Context,
	req *pulumirpc.PackRequest,
) (*pulumirpc.PackResponse, error) {
	artifactPath, err := PackProject(req.PackageDirectory, req.DestinationDirectory)
	if err != nil {
		return nil, fmt.Errorf("failed to pack project: %w", err)
	}

	return &pulumirpc.PackResponse{
		ArtifactPath: artifactPath,
	}, nil
}

// pluginKindFromString converts a string to a workspace.PluginKind.
func pluginKindFromString(s string) workspace.PluginKind {
	switch s {
	case "resource":
		return workspace.ResourcePlugin
	case "language":
		return workspace.LanguagePlugin
	case "analyzer":
		return workspace.AnalyzerPlugin
	case "converter":
		return workspace.ConverterPlugin
	default:
		return workspace.ResourcePlugin
	}
}

// PluginInfo represents information about a required plugin.
type PluginInfo struct {
	Name    string
	Kind    workspace.PluginKind
	Version string
	Server  string
}
