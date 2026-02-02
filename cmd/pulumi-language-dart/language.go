package main

import (
	"context"
	"fmt"
	"os/exec"

	"github.com/pulumi/pulumi/sdk/v3/go/common/util/logging"
	"github.com/pulumi/pulumi/sdk/v3/go/common/util/rpcutil"
	"github.com/pulumi/pulumi/sdk/v3/go/common/workspace"
	pulumirpc "github.com/pulumi/pulumi/sdk/v3/proto/go"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/protobuf/types/known/emptypb"
)

// DartLanguageHost implements the LanguageRuntime gRPC interface for Dart.
type DartLanguageHost struct {
	pulumirpc.UnimplementedLanguageRuntimeServer

	// executor handles Dart program execution
	executor *DartExecutor

	// deps handles dependency management
	deps *DependencyManager

	// engineAddress is the address of the Pulumi engine gRPC server.
	// This is passed to the Dart program to enable logging and other engine communication.
	engineAddress string
}

// NewDartLanguageHost creates a new Dart language host.
func NewDartLanguageHost() *DartLanguageHost {
	return &DartLanguageHost{
		executor: NewDartExecutor(),
		deps:     NewDependencyManager(),
	}
}

// NewDartLanguageHostWithEngine creates a new Dart language host with an engine address.
func NewDartLanguageHostWithEngine(engineAddress string) *DartLanguageHost {
	return &DartLanguageHost{
		executor:      NewDartExecutor(),
		deps:          NewDependencyManager(),
		engineAddress: engineAddress,
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
// 1. Parses runtime options from ProgramInfo
// 2. Sets up environment variables with monitor/engine addresses
// 3. Spawns the Dart process using the appropriate execution mode
// 4. Waits for completion and returns the exit code
func (h *DartLanguageHost) Run(
	ctx context.Context,
	req *pulumirpc.RunRequest,
) (*pulumirpc.RunResponse, error) {
	// Parse runtime options from ProgramInfo
	opts := parseRuntimeOptions(req.Info)

	// Determine the program directory and entry point
	programDir := req.Pwd
	entryPoint := ""
	if req.Info != nil {
		if req.Info.ProgramDirectory != "" {
			programDir = req.Info.ProgramDirectory
		}
		if req.Info.EntryPoint != "" {
			entryPoint = req.Info.EntryPoint
		}
	}

	// Create engine client if debugger attachment is requested
	var engineClient EngineClient
	if req.GetAttachDebugger() && h.engineAddress != "" {
		client, err := connectToEngine(ctx, h.engineAddress)
		if err != nil {
			logging.V(5).Infof("Failed to connect to engine for debugging: %v", err)
			// Continue without debugger attachment
		} else {
			engineClient = client
		}
	}

	config := ExecutorConfig{
		Program:          programDir,
		Pwd:              req.Pwd,
		Args:             req.Args,
		Config:           req.Config,
		ConfigSecretKeys: req.ConfigSecretKeys,
		DryRun:           req.DryRun,
		QueryMode:        req.QueryMode,
		Parallel:         int(req.Parallel),
		MonitorAddress:   req.MonitorAddress,
		EngineAddress:    h.engineAddress,
		Project:          req.Project,
		Stack:            req.Stack,
		Organization:     req.Organization,
		// Runtime options
		ExecutionMode: opts.Mode,
		BinaryPath:    opts.Binary,
		EntryPoint:    entryPoint,
		// Debugger options
		AttachDebugger: req.GetAttachDebugger(),
		EngineClient:   engineClient,
	}

	result, err := h.executor.Run(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("failed to run Dart program: %w", err)
	}

	return &pulumirpc.RunResponse{
		Error: result.Error,
		Bail:  result.Bail,
	}, nil
}

// RuntimeOptions contains parsed runtime options from Pulumi.yaml.
type RuntimeOptions struct {
	// Mode is the execution mode: "run" (default), "aot", or "binary"
	Mode string
	// Binary is the path to a pre-compiled binary (when Mode is "binary")
	Binary string
}

// parseRuntimeOptions extracts runtime options from ProgramInfo.
func parseRuntimeOptions(info *pulumirpc.ProgramInfo) RuntimeOptions {
	opts := RuntimeOptions{
		Mode: "run", // default mode
	}

	if info == nil || info.Options == nil {
		return opts
	}

	optMap := info.Options.AsMap()

	// Parse execution mode
	if mode, ok := optMap["mode"].(string); ok {
		switch mode {
		case "run", "aot", "binary":
			opts.Mode = mode
		}
	}

	// Parse binary path
	if binary, ok := optMap["binary"].(string); ok {
		opts.Binary = binary
	}

	// Support legacy use-aot option
	if useAot, ok := optMap["use-aot"].(bool); ok && useAot {
		opts.Mode = "aot"
	}

	return opts
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

// RunPlugin executes a plugin program asynchronously.
//
// This is used for running Pulumi plugins (like analyzers) written in Dart.
func (h *DartLanguageHost) RunPlugin(
	req *pulumirpc.RunPluginRequest,
	server pulumirpc.LanguageRuntime_RunPluginServer,
) error {
	// Get the program path from ProgramInfo
	programPath := req.Pwd
	if req.Info != nil && req.Info.ProgramDirectory != "" {
		programPath = req.Info.ProgramDirectory
	}

	// Find dart executable
	dartPath, err := h.executor.findDart()
	if err != nil {
		return fmt.Errorf("dart not found: %w", err)
	}

	// Build command arguments
	args := []string{"run"}
	args = append(args, req.Args...)

	// Create the command
	ctx := server.Context()
	cmd := exec.CommandContext(ctx, dartPath, args...)
	cmd.Dir = programPath

	// Set environment
	cmd.Env = append(cmd.Env, req.Env...)

	// Capture stdout and stderr
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
		return fmt.Errorf("failed to start plugin: %w", err)
	}

	// Stream stdout
	go func() {
		buf := make([]byte, 4096)
		for {
			n, err := stdout.Read(buf)
			if n > 0 {
				_ = server.Send(&pulumirpc.RunPluginResponse{
					Output: &pulumirpc.RunPluginResponse_Stdout{
						Stdout: buf[:n],
					},
				})
			}
			if err != nil {
				break
			}
		}
	}()

	// Stream stderr
	go func() {
		buf := make([]byte, 4096)
		for {
			n, err := stderr.Read(buf)
			if n > 0 {
				_ = server.Send(&pulumirpc.RunPluginResponse{
					Output: &pulumirpc.RunPluginResponse_Stderr{
						Stderr: buf[:n],
					},
				})
			}
			if err != nil {
				break
			}
		}
	}()

	// Wait for the command to finish
	err = cmd.Wait()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return server.Send(&pulumirpc.RunPluginResponse{
				Output: &pulumirpc.RunPluginResponse_Exitcode{
					Exitcode: int32(exitErr.ExitCode()),
				},
			})
		}
		return fmt.Errorf("plugin execution failed: %w", err)
	}

	// Send success exit code
	return server.Send(&pulumirpc.RunPluginResponse{
		Output: &pulumirpc.RunPluginResponse_Exitcode{
			Exitcode: 0,
		},
	})
}

// About returns information about the Dart runtime.
func (h *DartLanguageHost) About(
	ctx context.Context,
	req *pulumirpc.AboutRequest,
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

// Handshake is the first call made by the engine to a language host.
func (h *DartLanguageHost) Handshake(
	ctx context.Context,
	req *pulumirpc.LanguageHandshakeRequest,
) (*pulumirpc.LanguageHandshakeResponse, error) {
	return &pulumirpc.LanguageHandshakeResponse{}, nil
}

// GetRequiredPackages returns the list of packages required by the Dart program.
func (h *DartLanguageHost) GetRequiredPackages(
	ctx context.Context,
	req *pulumirpc.GetRequiredPackagesRequest,
) (*pulumirpc.GetRequiredPackagesResponse, error) {
	plugins, err := h.deps.GetRequiredPlugins(req.Info.ProgramDirectory)
	if err != nil {
		return nil, fmt.Errorf("failed to get required packages: %w", err)
	}

	var result []*pulumirpc.PackageDependency
	for _, p := range plugins {
		result = append(result, &pulumirpc.PackageDependency{
			Name:    p.Name,
			Kind:    string(p.Kind),
			Version: p.Version,
		})
	}

	return &pulumirpc.GetRequiredPackagesResponse{
		Packages: result,
	}, nil
}

// RuntimeOptionsPrompts returns additional prompts to ask during `pulumi new`.
func (h *DartLanguageHost) RuntimeOptionsPrompts(
	ctx context.Context,
	req *pulumirpc.RuntimeOptionsRequest,
) (*pulumirpc.RuntimeOptionsResponse, error) {
	return &pulumirpc.RuntimeOptionsResponse{}, nil
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

// engineClientWrapper wraps the pulumirpc.EngineClient to implement our EngineClient interface.
type engineClientWrapper struct {
	client pulumirpc.EngineClient
}

// StartDebugging implements the EngineClient interface.
func (w *engineClientWrapper) StartDebugging(ctx context.Context, req *pulumirpc.StartDebuggingRequest) error {
	_, err := w.client.StartDebugging(ctx, req)
	return err
}

// connectToEngine creates a gRPC connection to the Pulumi engine.
func connectToEngine(ctx context.Context, address string) (EngineClient, error) {
	conn, err := grpc.NewClient(
		address,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		rpcutil.GrpcChannelOptions(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to engine at %s: %w", address, err)
	}

	client := pulumirpc.NewEngineClient(conn)
	return &engineClientWrapper{client: client}, nil
}
