// Integration tests for the Dart language host.
//
// These tests verify the end-to-end behavior of the language host
// working with the Dart SDK and real resource providers.
//
// To run these tests:
//   go test -v -tags=integration -run TestIntegration

//go:build integration
// +build integration

package main

import (
	"context"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"

	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/emptypb"
	structpb "google.golang.org/protobuf/types/known/structpb"

	pulumirpc "github.com/pulumi/pulumi/sdk/v3/proto/go"
)

// MockResourceMonitor is a simple mock for integration testing.
// It records all resource registrations for verification.
type MockResourceMonitor struct {
	pulumirpc.UnimplementedResourceMonitorServer
	mu            sync.Mutex
	resources     []registeredResource
	stackOutputs  map[string]interface{}
	nextID        int
	supportsFeats map[string]bool
}

type registeredResource struct {
	Type   string
	Name   string
	Custom bool
	Inputs *structpb.Struct
	Parent string
	URN    string
	ID     string
}

func NewMockResourceMonitor() *MockResourceMonitor {
	return &MockResourceMonitor{
		stackOutputs:  make(map[string]interface{}),
		supportsFeats: make(map[string]bool),
	}
}

func (m *MockResourceMonitor) SupportsFeature(
	ctx context.Context,
	req *pulumirpc.SupportsFeatureRequest,
) (*pulumirpc.SupportsFeatureResponse, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return &pulumirpc.SupportsFeatureResponse{
		HasSupport: m.supportsFeats[req.Id],
	}, nil
}

func (m *MockResourceMonitor) RegisterResource(
	ctx context.Context,
	req *pulumirpc.RegisterResourceRequest,
) (*pulumirpc.RegisterResourceResponse, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.nextID++
	urn := fmt.Sprintf("urn:pulumi:test-stack::test-project::%s::%s", req.Type, req.Name)
	id := fmt.Sprintf("mock-id-%d", m.nextID)

	// Record the resource
	m.resources = append(m.resources, registeredResource{
		Type:   req.Type,
		Name:   req.Name,
		Custom: req.Custom,
		Inputs: req.Object,
		Parent: req.Parent,
		URN:    urn,
		ID:     id,
	})

	// Create response properties based on input + generated values
	props := &structpb.Struct{
		Fields: make(map[string]*structpb.Value),
	}

	// Copy inputs to outputs (simplified)
	if req.Object != nil {
		for k, v := range req.Object.Fields {
			props.Fields[k] = v
		}
	}

	// For RandomString, generate a mock result
	if req.Type == "random:index/randomString:RandomString" {
		lengthVal := 16
		if l, ok := req.Object.Fields["length"]; ok {
			lengthVal = int(l.GetNumberValue())
		}
		props.Fields["result"] = structpb.NewStringValue(strings.Repeat("x", lengthVal))
		props.Fields["id"] = structpb.NewStringValue(id)
	}

	return &pulumirpc.RegisterResourceResponse{
		Urn:    urn,
		Id:     id,
		Object: props,
	}, nil
}

func (m *MockResourceMonitor) RegisterResourceOutputs(
	ctx context.Context,
	req *pulumirpc.RegisterResourceOutputsRequest,
) (*emptypb.Empty, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Record stack outputs if this is the stack resource
	if strings.Contains(req.Urn, "pulumi:pulumi:Stack") && req.Outputs != nil {
		for k, v := range req.Outputs.Fields {
			m.stackOutputs[k] = v.AsInterface()
		}
	}

	return &emptypb.Empty{}, nil
}

func (m *MockResourceMonitor) ReadResource(
	ctx context.Context,
	req *pulumirpc.ReadResourceRequest,
) (*pulumirpc.ReadResourceResponse, error) {
	return &pulumirpc.ReadResourceResponse{}, nil
}

func (m *MockResourceMonitor) Invoke(
	ctx context.Context,
	req *pulumirpc.ResourceInvokeRequest,
) (*pulumirpc.InvokeResponse, error) {
	return &pulumirpc.InvokeResponse{}, nil
}

func (m *MockResourceMonitor) GetResources() []registeredResource {
	m.mu.Lock()
	defer m.mu.Unlock()
	result := make([]registeredResource, len(m.resources))
	copy(result, m.resources)
	return result
}

// MockEngine is a simple mock for the Pulumi engine.
type MockEngine struct {
	pulumirpc.UnimplementedEngineServer
	mu   sync.Mutex
	logs []logEntry
}

type logEntry struct {
	Severity pulumirpc.LogSeverity
	Message  string
}

func NewMockEngine() *MockEngine {
	return &MockEngine{}
}

func (m *MockEngine) Log(ctx context.Context, req *pulumirpc.LogRequest) (*emptypb.Empty, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.logs = append(m.logs, logEntry{
		Severity: req.Severity,
		Message:  req.Message,
	})
	return &emptypb.Empty{}, nil
}

func (m *MockEngine) GetRootResource(
	ctx context.Context,
	req *pulumirpc.GetRootResourceRequest,
) (*pulumirpc.GetRootResourceResponse, error) {
	return &pulumirpc.GetRootResourceResponse{
		Urn: "urn:pulumi:test-stack::test-project::pulumi:pulumi:Stack::test-stack",
	}, nil
}

func (m *MockEngine) SetRootResource(
	ctx context.Context,
	req *pulumirpc.SetRootResourceRequest,
) (*pulumirpc.SetRootResourceResponse, error) {
	return &pulumirpc.SetRootResourceResponse{}, nil
}

// startMockServers starts mock resource monitor and engine servers.
func startMockServers(t *testing.T) (*MockResourceMonitor, *MockEngine, string, string, func()) {
	monitor := NewMockResourceMonitor()
	engine := NewMockEngine()

	// Start monitor server
	monitorLis, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatalf("Failed to listen for monitor: %v", err)
	}
	monitorServer := grpc.NewServer()
	pulumirpc.RegisterResourceMonitorServer(monitorServer, monitor)
	go monitorServer.Serve(monitorLis)

	// Start engine server
	engineLis, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatalf("Failed to listen for engine: %v", err)
	}
	engineServer := grpc.NewServer()
	pulumirpc.RegisterEngineServer(engineServer, engine)
	go engineServer.Serve(engineLis)

	cleanup := func() {
		monitorServer.Stop()
		engineServer.Stop()
	}

	return monitor, engine, monitorLis.Addr().String(), engineLis.Addr().String(), cleanup
}

func TestIntegration_BasicRandomResource(t *testing.T) {
	// Find the test data directory
	testDataDir, err := filepath.Abs("../../tests/integration/testdata/basic_random")
	if err != nil {
		t.Fatalf("Failed to get test data directory: %v", err)
	}

	// Check if the test data exists
	if _, err := os.Stat(testDataDir); os.IsNotExist(err) {
		t.Skipf("Test data directory not found: %s", testDataDir)
	}

	// Run dart pub get to install dependencies
	pubGetCmd := exec.Command("dart", "pub", "get")
	pubGetCmd.Dir = testDataDir
	pubGetCmd.Stdout = os.Stdout
	pubGetCmd.Stderr = os.Stderr
	if err := pubGetCmd.Run(); err != nil {
		t.Fatalf("dart pub get failed: %v", err)
	}

	// Start mock servers
	monitor, _, monitorAddr, engineAddr, cleanup := startMockServers(t)
	defer cleanup()

	// Create the language host
	host := NewDartLanguageHostWithEngine(engineAddr)

	// Run the Dart program
	ctx := context.Background()
	req := &pulumirpc.RunRequest{
		Pwd:            testDataDir,
		MonitorAddress: monitorAddr,
		Project:        "test-project",
		Stack:          "test-stack",
		Info: &pulumirpc.ProgramInfo{
			RootDirectory:    testDataDir,
			ProgramDirectory: testDataDir,
			EntryPoint:       "bin/main.dart",
		},
	}

	resp, err := host.Run(ctx, req)
	if err != nil {
		t.Fatalf("Run failed: %v", err)
	}

	if resp.Error != "" {
		t.Errorf("Program returned error: %s", resp.Error)
	}

	// Verify the resource was registered
	resources := monitor.GetResources()
	if len(resources) == 0 {
		t.Fatal("No resources were registered")
	}

	// Find the RandomString resource
	var randomStringResource *registeredResource
	for _, r := range resources {
		if r.Type == "random:index/randomString:RandomString" {
			randomStringResource = &r
			break
		}
	}

	if randomStringResource == nil {
		t.Fatal("RandomString resource was not registered")
	}

	// Verify resource properties
	if randomStringResource.Name != "test-random-string" {
		t.Errorf("Expected resource name 'test-random-string', got '%s'", randomStringResource.Name)
	}

	if !randomStringResource.Custom {
		t.Error("Expected resource to be a custom resource")
	}

	// Verify inputs
	if randomStringResource.Inputs != nil {
		if length, ok := randomStringResource.Inputs.Fields["length"]; ok {
			if length.GetNumberValue() != 16 {
				t.Errorf("Expected length 16, got %v", length.GetNumberValue())
			}
		} else {
			t.Error("Length input not found")
		}
	}

	t.Logf("Successfully registered resource: %s with URN: %s", randomStringResource.Name, randomStringResource.URN)
}

func TestIntegration_LanguageHostGetRequiredPlugins(t *testing.T) {
	testDataDir, err := filepath.Abs("../../tests/integration/testdata/basic_random")
	if err != nil {
		t.Fatalf("Failed to get test data directory: %v", err)
	}

	if _, err := os.Stat(testDataDir); os.IsNotExist(err) {
		t.Skipf("Test data directory not found: %s", testDataDir)
	}

	host := NewDartLanguageHost()
	ctx := context.Background()

	req := &pulumirpc.GetRequiredPluginsRequest{
		Program: testDataDir,
	}

	resp, err := host.GetRequiredPlugins(ctx, req)
	if err != nil {
		t.Fatalf("GetRequiredPlugins failed: %v", err)
	}

	// The basic_random test project doesn't declare pulumi_random as a dependency
	// (it uses the core SDK and manually creates the resource type)
	// So we expect an empty list or we could add pulumi_random dependency
	t.Logf("Found %d required plugins", len(resp.Plugins))
	for _, p := range resp.Plugins {
		t.Logf("  - %s %s (kind: %s)", p.Name, p.Version, p.Kind)
	}
}

func TestIntegration_InstallDependencies(t *testing.T) {
	testDataDir, err := filepath.Abs("../../tests/integration/testdata/basic_random")
	if err != nil {
		t.Fatalf("Failed to get test data directory: %v", err)
	}

	if _, err := os.Stat(testDataDir); os.IsNotExist(err) {
		t.Skipf("Test data directory not found: %s", testDataDir)
	}

	host := NewDartLanguageHost()

	// Create a mock streaming server for InstallDependencies
	req := &pulumirpc.InstallDependenciesRequest{
		Directory: testDataDir,
		IsTerminal: false,
	}

	server := &mockInstallDepsServer{
		ctx:      context.Background(),
		messages: make([]string, 0),
	}

	err = host.InstallDependencies(req, server)
	if err != nil {
		t.Fatalf("InstallDependencies failed: %v", err)
	}

	t.Logf("InstallDependencies completed with %d messages", len(server.messages))
}

// mockInstallDepsServer is a mock streaming server for InstallDependencies
type mockInstallDepsServer struct {
	grpc.ServerStream
	ctx      context.Context
	messages []string
}

func (m *mockInstallDepsServer) Context() context.Context {
	return m.ctx
}

func (m *mockInstallDepsServer) Send(resp *pulumirpc.InstallDependenciesResponse) error {
	m.messages = append(m.messages, string(resp.Stdout))
	return nil
}

func TestIntegration_RunWithDryRun(t *testing.T) {
	// Find the test data directory
	testDataDir, err := filepath.Abs("../../tests/integration/testdata/basic_random")
	if err != nil {
		t.Fatalf("Failed to get test data directory: %v", err)
	}

	if _, err := os.Stat(testDataDir); os.IsNotExist(err) {
		t.Skipf("Test data directory not found: %s", testDataDir)
	}

	// Run dart pub get to install dependencies
	pubGetCmd := exec.Command("dart", "pub", "get")
	pubGetCmd.Dir = testDataDir
	if err := pubGetCmd.Run(); err != nil {
		t.Fatalf("dart pub get failed: %v", err)
	}

	// Start mock servers
	monitor, _, monitorAddr, engineAddr, cleanup := startMockServers(t)
	defer cleanup()

	// Create the language host
	host := NewDartLanguageHostWithEngine(engineAddr)

	// Run the Dart program in dry-run mode
	ctx := context.Background()
	req := &pulumirpc.RunRequest{
		Pwd:            testDataDir,
		MonitorAddress: monitorAddr,
		Project:        "test-project",
		Stack:          "test-stack",
		DryRun:         true, // Enable dry-run mode
		Info: &pulumirpc.ProgramInfo{
			RootDirectory:    testDataDir,
			ProgramDirectory: testDataDir,
			EntryPoint:       "bin/main.dart",
		},
	}

	resp, err := host.Run(ctx, req)
	if err != nil {
		t.Fatalf("Run failed: %v", err)
	}

	if resp.Error != "" {
		t.Errorf("Program returned error: %s", resp.Error)
	}

	// Verify the resource was registered
	resources := monitor.GetResources()
	if len(resources) == 0 {
		t.Fatal("No resources were registered during dry-run")
	}

	t.Logf("Dry-run registered %d resources", len(resources))
}

func TestIntegration_RunWithConfig(t *testing.T) {
	// Find the test data directory
	testDataDir, err := filepath.Abs("../../tests/integration/testdata/basic_random")
	if err != nil {
		t.Fatalf("Failed to get test data directory: %v", err)
	}

	if _, err := os.Stat(testDataDir); os.IsNotExist(err) {
		t.Skipf("Test data directory not found: %s", testDataDir)
	}

	// Run dart pub get to install dependencies
	pubGetCmd := exec.Command("dart", "pub", "get")
	pubGetCmd.Dir = testDataDir
	if err := pubGetCmd.Run(); err != nil {
		t.Fatalf("dart pub get failed: %v", err)
	}

	// Start mock servers
	monitor, _, monitorAddr, engineAddr, cleanup := startMockServers(t)
	defer cleanup()

	// Create the language host
	host := NewDartLanguageHostWithEngine(engineAddr)

	// Run the Dart program with config values
	ctx := context.Background()
	req := &pulumirpc.RunRequest{
		Pwd:            testDataDir,
		MonitorAddress: monitorAddr,
		Project:        "test-project",
		Stack:          "test-stack",
		Config: map[string]string{
			"test:key1": "value1",
			"test:key2": "value2",
		},
		Info: &pulumirpc.ProgramInfo{
			RootDirectory:    testDataDir,
			ProgramDirectory: testDataDir,
			EntryPoint:       "bin/main.dart",
		},
	}

	resp, err := host.Run(ctx, req)
	if err != nil {
		t.Fatalf("Run failed: %v", err)
	}

	if resp.Error != "" {
		t.Errorf("Program returned error: %s", resp.Error)
	}

	// Verify the resource was registered
	resources := monitor.GetResources()
	if len(resources) == 0 {
		t.Fatal("No resources were registered")
	}

	t.Logf("Config test registered %d resources", len(resources))
}

func TestIntegration_About(t *testing.T) {
	host := NewDartLanguageHost()
	ctx := context.Background()

	resp, err := host.About(ctx, &pulumirpc.AboutRequest{})
	if err != nil {
		t.Fatalf("About failed: %v", err)
	}

	if resp.Executable != "dart" {
		t.Errorf("Expected executable 'dart', got '%s'", resp.Executable)
	}

	if resp.Version == "" {
		t.Error("Expected non-empty version")
	}

	// Version should start with "3." for Dart 3.x
	if !strings.HasPrefix(resp.Version, "3.") {
		t.Logf("Warning: Dart version %s may not be compatible", resp.Version)
	}

	t.Logf("About: executable=%s, version=%s", resp.Executable, resp.Version)
}

func TestIntegration_GetProgramDependencies(t *testing.T) {
	testDataDir, err := filepath.Abs("../../tests/integration/testdata/basic_random")
	if err != nil {
		t.Fatalf("Failed to get test data directory: %v", err)
	}

	if _, err := os.Stat(testDataDir); os.IsNotExist(err) {
		t.Skipf("Test data directory not found: %s", testDataDir)
	}

	// Run dart pub get to ensure pubspec.lock exists
	pubGetCmd := exec.Command("dart", "pub", "get")
	pubGetCmd.Dir = testDataDir
	if err := pubGetCmd.Run(); err != nil {
		t.Fatalf("dart pub get failed: %v", err)
	}

	host := NewDartLanguageHost()
	ctx := context.Background()

	req := &pulumirpc.GetProgramDependenciesRequest{
		Program:                 testDataDir,
		TransitiveDependencies: false,
	}

	resp, err := host.GetProgramDependencies(ctx, req)
	if err != nil {
		t.Fatalf("GetProgramDependencies failed: %v", err)
	}

	// Should have at least the pulumi dependency
	if len(resp.Dependencies) == 0 {
		t.Error("Expected at least one dependency")
	}

	var foundPulumi bool
	for _, dep := range resp.Dependencies {
		t.Logf("  - %s: %s", dep.Name, dep.Version)
		if dep.Name == "pulumi" {
			foundPulumi = true
		}
	}

	if !foundPulumi {
		t.Error("Expected to find 'pulumi' in dependencies")
	}

	t.Logf("Found %d dependencies", len(resp.Dependencies))
}

func TestIntegration_GetProgramDependencies_Transitive(t *testing.T) {
	testDataDir, err := filepath.Abs("../../tests/integration/testdata/basic_random")
	if err != nil {
		t.Fatalf("Failed to get test data directory: %v", err)
	}

	if _, err := os.Stat(testDataDir); os.IsNotExist(err) {
		t.Skipf("Test data directory not found: %s", testDataDir)
	}

	// Run dart pub get to ensure pubspec.lock exists
	pubGetCmd := exec.Command("dart", "pub", "get")
	pubGetCmd.Dir = testDataDir
	if err := pubGetCmd.Run(); err != nil {
		t.Fatalf("dart pub get failed: %v", err)
	}

	host := NewDartLanguageHost()
	ctx := context.Background()

	req := &pulumirpc.GetProgramDependenciesRequest{
		Program:                 testDataDir,
		TransitiveDependencies: true,
	}

	resp, err := host.GetProgramDependencies(ctx, req)
	if err != nil {
		t.Fatalf("GetProgramDependencies (transitive) failed: %v", err)
	}

	// Transitive dependencies should include more packages
	t.Logf("Found %d transitive dependencies", len(resp.Dependencies))

	// Should have transitive deps like grpc, protobuf, etc.
	if len(resp.Dependencies) < 5 {
		t.Logf("Warning: Expected more transitive dependencies, got %d", len(resp.Dependencies))
	}
}

func TestIntegration_RunInvalidProgram(t *testing.T) {
	// Create a temporary directory with an invalid Dart program
	tempDir, err := os.MkdirTemp("", "pulumi-dart-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir)

	// Create an invalid pubspec.yaml
	pubspecContent := `name: invalid_test
description: Test with invalid Dart code
version: 0.1.0
publish_to: none

environment:
  sdk: '>=3.0.0 <4.0.0'
`
	if err := os.WriteFile(filepath.Join(tempDir, "pubspec.yaml"), []byte(pubspecContent), 0644); err != nil {
		t.Fatalf("Failed to write pubspec.yaml: %v", err)
	}

	// Create bin directory
	binDir := filepath.Join(tempDir, "bin")
	if err := os.MkdirAll(binDir, 0755); err != nil {
		t.Fatalf("Failed to create bin directory: %v", err)
	}

	// Create an invalid Dart file (syntax error)
	invalidCode := `void main() {
  print("This is incomplete...
}
`
	if err := os.WriteFile(filepath.Join(binDir, "main.dart"), []byte(invalidCode), 0644); err != nil {
		t.Fatalf("Failed to write main.dart: %v", err)
	}

	// Start mock servers
	_, _, monitorAddr, engineAddr, cleanup := startMockServers(t)
	defer cleanup()

	// Create the language host
	host := NewDartLanguageHostWithEngine(engineAddr)

	// Try to run the invalid program
	ctx := context.Background()
	req := &pulumirpc.RunRequest{
		Pwd:            tempDir,
		MonitorAddress: monitorAddr,
		Project:        "test-project",
		Stack:          "test-stack",
		Info: &pulumirpc.ProgramInfo{
			RootDirectory:    tempDir,
			ProgramDirectory: tempDir,
			EntryPoint:       "bin/main.dart",
		},
	}

	resp, err := host.Run(ctx, req)
	if err != nil {
		// This is also acceptable - the executor might return an error
		t.Logf("Run returned error as expected: %v", err)
		return
	}

	// If we get a response, it should have an error
	if resp.Error == "" {
		t.Error("Expected error from running invalid program")
	} else {
		t.Logf("Got expected error: %s", resp.Error)
	}
}

func TestIntegration_Handshake(t *testing.T) {
	host := NewDartLanguageHost()
	ctx := context.Background()

	resp, err := host.Handshake(ctx, &pulumirpc.LanguageHandshakeRequest{})
	if err != nil {
		t.Fatalf("Handshake failed: %v", err)
	}

	// Handshake should return an empty response for now
	if resp == nil {
		t.Error("Expected non-nil response")
	}

	t.Log("Handshake completed successfully")
}

func TestIntegration_GetPluginInfo(t *testing.T) {
	host := NewDartLanguageHost()
	ctx := context.Background()

	resp, err := host.GetPluginInfo(ctx, &emptypb.Empty{})
	if err != nil {
		t.Fatalf("GetPluginInfo failed: %v", err)
	}

	if resp.Version == "" {
		t.Error("Expected non-empty version")
	}

	t.Logf("Plugin version: %s", resp.Version)
}

func TestIntegration_RuntimeOptionsPrompts(t *testing.T) {
	host := NewDartLanguageHost()
	ctx := context.Background()

	resp, err := host.RuntimeOptionsPrompts(ctx, &pulumirpc.RuntimeOptionsRequest{})
	if err != nil {
		t.Fatalf("RuntimeOptionsPrompts failed: %v", err)
	}

	// Should return an empty response (no prompts for now)
	if resp == nil {
		t.Error("Expected non-nil response")
	}

	t.Log("RuntimeOptionsPrompts completed successfully")
}
