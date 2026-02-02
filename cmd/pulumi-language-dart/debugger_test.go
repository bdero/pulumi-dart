package main

import (
	"context"
	"testing"
	"time"

	pulumirpc "github.com/pulumi/pulumi/sdk/v3/proto/go"
)

// mockEngineClient is a mock implementation of EngineClient for testing.
type mockEngineClient struct {
	startDebuggingCalled bool
	lastRequest          *pulumirpc.StartDebuggingRequest
	err                  error
}

func (m *mockEngineClient) StartDebugging(ctx context.Context, req *pulumirpc.StartDebuggingRequest) error {
	m.startDebuggingCalled = true
	m.lastRequest = req
	return m.err
}

func TestFindNextAvailablePort(t *testing.T) {
	// Test that we can find an available port
	port, err := findNextAvailablePort(preferredDebugPort)
	if err != nil {
		t.Fatalf("findNextAvailablePort failed: %v", err)
	}

	if port < preferredDebugPort || port >= preferredDebugPort+100 {
		t.Errorf("port %d is outside expected range [%d, %d)", port, preferredDebugPort, preferredDebugPort+100)
	}
}

func TestDebuggerCleanup(t *testing.T) {
	// Test that Cleanup doesn't panic with nil values
	dbg := &dartDebugger{}
	dbg.Cleanup() // Should not panic
}

func TestIsVMServiceReadyMessage(t *testing.T) {
	tests := []struct {
		name     string
		line     string
		expected bool
	}{
		{
			name:     "modern VM service message",
			line:     "The Dart VM service is listening on http://127.0.0.1:12345/",
			expected: true,
		},
		{
			name:     "old Observatory message",
			line:     "Observatory listening on http://127.0.0.1:12345/",
			expected: true,
		},
		{
			name:     "unrelated message",
			line:     "Running main.dart...",
			expected: false,
		},
		{
			name:     "empty line",
			line:     "",
			expected: false,
		},
		{
			name:     "partial match should still work",
			line:     "  VM service is listening on http://localhost:8181/  ",
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isVMServiceReadyMessage(tt.line)
			if result != tt.expected {
				t.Errorf("isVMServiceReadyMessage(%q) = %v, want %v", tt.line, result, tt.expected)
			}
		})
	}
}

func TestDebugCommand(t *testing.T) {
	ctx := context.Background()

	// Test debugCommand creates proper command structure
	cmd, dbg, err := debugCommand(ctx, "dart", "/tmp/test", "", []string{"--arg1"})
	if err != nil {
		t.Fatalf("debugCommand failed: %v", err)
	}

	// Verify debugger struct is populated
	if dbg.Host != "127.0.0.1" {
		t.Errorf("dbg.Host = %q, want %q", dbg.Host, "127.0.0.1")
	}
	if dbg.Port < preferredDebugPort || dbg.Port >= preferredDebugPort+100 {
		t.Errorf("dbg.Port = %d is outside expected range", dbg.Port)
	}
	if dbg.cmd != cmd {
		t.Error("dbg.cmd should reference the returned command")
	}

	// Verify command structure
	if cmd.Path == "" {
		t.Error("cmd.Path should not be empty")
	}
	if cmd.Dir != "/tmp/test" {
		t.Errorf("cmd.Dir = %q, want %q", cmd.Dir, "/tmp/test")
	}
}

func TestDebugCommandWithEntryPoint(t *testing.T) {
	ctx := context.Background()

	// Test with a custom entry point
	cmd, _, err := debugCommand(ctx, "dart", "/tmp/test", "bin/custom.dart", nil)
	if err != nil {
		t.Fatalf("debugCommand failed: %v", err)
	}

	// Check that entry point is included in args
	found := false
	for _, arg := range cmd.Args {
		if arg == "bin/custom.dart" {
			found = true
			break
		}
	}
	if !found {
		t.Error("entry point 'bin/custom.dart' not found in command args")
	}
}

func TestStartDebugging(t *testing.T) {
	ctx := context.Background()
	mockClient := &mockEngineClient{}

	dbg := &dartDebugger{
		Host: "127.0.0.1",
		Port: 12345,
	}

	err := startDebugging(ctx, mockClient, dbg, "Test: Dart Program")
	if err != nil {
		t.Fatalf("startDebugging failed: %v", err)
	}

	if !mockClient.startDebuggingCalled {
		t.Error("StartDebugging was not called on the engine client")
	}

	if mockClient.lastRequest == nil {
		t.Fatal("lastRequest is nil")
	}

	if mockClient.lastRequest.Message != "on port 12345" {
		t.Errorf("Message = %q, want %q", mockClient.lastRequest.Message, "on port 12345")
	}

	// Verify debug config contains expected fields
	config := mockClient.lastRequest.Config.AsMap()
	if config["name"] != "Test: Dart Program" {
		t.Errorf("config[name] = %v, want %v", config["name"], "Test: Dart Program")
	}
	if config["type"] != "dart" {
		t.Errorf("config[type] = %v, want %v", config["type"], "dart")
	}
	if config["request"] != "attach" {
		t.Errorf("config[request] = %v, want %v", config["request"], "attach")
	}
	expectedURI := "http://127.0.0.1:12345/"
	if config["vmServiceUri"] != expectedURI {
		t.Errorf("config[vmServiceUri] = %v, want %v", config["vmServiceUri"], expectedURI)
	}
}

func TestWaitForVMServiceByPollingTimeout(t *testing.T) {
	// Test that waitForVMServiceByPolling times out correctly
	// Use a port that nothing is listening on
	ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
	defer cancel()

	err := waitForVMServiceByPolling(ctx, 59999)
	if err == nil {
		t.Error("expected timeout error, got nil")
	}
}
