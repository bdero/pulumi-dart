package main

import (
	"bufio"
	"context"
	"fmt"
	"net"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/pulumi/pulumi/sdk/v3/go/common/util/logging"
	pulumirpc "github.com/pulumi/pulumi/sdk/v3/proto/go"
	"google.golang.org/protobuf/types/known/structpb"
)

// EngineClient is an interface for the Pulumi engine client.
// This allows for easier testing and decouples the debugger from the full gRPC client.
type EngineClient interface {
	StartDebugging(ctx context.Context, req *pulumirpc.StartDebuggingRequest) error
}

// dartDebugger manages the Dart debug adapter process.
type dartDebugger struct {
	// cmd is the debug adapter process
	cmd *exec.Cmd
	// Host is the address the debug adapter is listening on
	Host string
	// Port is the port the debug adapter is listening on
	Port int
}

// preferredDebugPort is the default port to try for the debug adapter
const preferredDebugPort = 12345

// debugStartupTimeout is how long to wait for the debug adapter to start
const debugStartupTimeout = 30 * time.Second

// Cleanup terminates the debug adapter process and releases resources.
func (d *dartDebugger) Cleanup() {
	if d.cmd != nil && d.cmd.Process != nil {
		_ = d.cmd.Process.Kill()
	}
}

// findNextAvailablePort finds an available TCP port starting from the preferred port.
func findNextAvailablePort(start int) (int, error) {
	for port := start; port < start+100; port++ {
		listener, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", port))
		if err == nil {
			listener.Close()
			return port, nil
		}
	}
	return 0, fmt.Errorf("no available port found starting from %d", start)
}

// debugCommand creates a command that runs under the Dart debugger.
// It returns the command to execute, a debugger struct for management, and any error.
func debugCommand(ctx context.Context, dartPath string, programPath string, entryPoint string, args []string) (*exec.Cmd, *dartDebugger, error) {
	// Find an available port for the VM service
	port, err := findNextAvailablePort(preferredDebugPort)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to find available port: %w", err)
	}

	// Build command arguments for debugging
	// Use --enable-vm-service to allow debugger attachment
	// Use --pause-isolates-on-start so the debugger can attach before execution
	cmdArgs := []string{
		"run",
		fmt.Sprintf("--enable-vm-service=%d", port),
		"--pause-isolates-on-start",
		"--disable-service-auth-codes",
	}

	if entryPoint != "" {
		cmdArgs = append(cmdArgs, entryPoint)
	}

	cmdArgs = append(cmdArgs, args...)

	cmd := exec.CommandContext(ctx, dartPath, cmdArgs...)
	cmd.Dir = programPath

	dbg := &dartDebugger{
		cmd:  cmd,
		Host: "127.0.0.1",
		Port: port,
	}

	return cmd, dbg, nil
}

// startDebugging notifies the Pulumi engine that a debugger is ready.
func startDebugging(ctx context.Context, engineClient EngineClient, dbg *dartDebugger, name string) error {
	// Create the debug configuration for DAP clients
	// This follows the VS Code debug adapter protocol configuration format
	debugConfig, err := structpb.NewStruct(map[string]any{
		"name":         name,
		"type":         "dart",
		"request":      "attach",
		"vmServiceUri": fmt.Sprintf("http://%s:%d/", dbg.Host, dbg.Port),
	})
	if err != nil {
		return fmt.Errorf("failed to create debug config: %w", err)
	}

	message := fmt.Sprintf("on port %d", dbg.Port)
	err = engineClient.StartDebugging(ctx, &pulumirpc.StartDebuggingRequest{
		Config:  debugConfig,
		Message: message,
	})
	if err != nil {
		return fmt.Errorf("failed to start debugging: %w", err)
	}

	return nil
}

// waitForVMService waits for the Dart VM service to be ready by monitoring the output.
// It reads from stdout/stderr looking for the VM service URI message.
func waitForVMService(ctx context.Context, stdout, stderr *bufio.Scanner, port int) error {
	// Create a context with timeout
	ctx, cancel := context.WithTimeout(ctx, debugStartupTimeout)
	defer cancel()

	vmServiceReady := make(chan struct{})
	errChan := make(chan error, 1)

	// Monitor stdout for VM service URI
	go func() {
		for stdout.Scan() {
			line := stdout.Text()
			logging.V(9).Infof("Dart debug stdout: %s", line)

			// Check for VM service URI message
			// Example: "The Dart VM service is listening on http://127.0.0.1:12345/"
			if isVMServiceReadyMessage(line) {
				select {
				case vmServiceReady <- struct{}{}:
				default:
				}
				return
			}

			// Forward to parent stdout
			fmt.Println(line)
		}
	}()

	// Monitor stderr for VM service URI (some Dart versions output to stderr)
	go func() {
		for stderr.Scan() {
			line := stderr.Text()
			logging.V(9).Infof("Dart debug stderr: %s", line)

			// Check for VM service URI message
			if isVMServiceReadyMessage(line) {
				select {
				case vmServiceReady <- struct{}{}:
				default:
				}
				return
			}

			// Forward to parent stderr
			fmt.Fprintln(os.Stderr, line)
		}
	}()

	// Wait for VM service to be ready with timeout
	select {
	case <-vmServiceReady:
		logging.V(5).Infof("Dart VM service ready on port %d", port)
		return nil
	case err := <-errChan:
		return err
	case <-ctx.Done():
		return fmt.Errorf("timeout waiting for Dart VM service on port %d", port)
	}
}

// isVMServiceReadyMessage checks if a line contains the VM service URI message.
func isVMServiceReadyMessage(line string) bool {
	// The Dart VM outputs: "The Dart VM service is listening on http://..."
	// or "Observatory listening on http://..." (older versions)
	return strings.Contains(line, "VM service is listening on") ||
		strings.Contains(line, "Observatory listening on")
}

// waitForVMServiceByPolling waits for the VM service by polling the port.
// This is a fallback method if output scanning doesn't work.
func waitForVMServiceByPolling(ctx context.Context, port int) error {
	// Create a context with timeout
	ctx, cancel := context.WithTimeout(ctx, debugStartupTimeout)
	defer cancel()

	// Poll for the VM service to be available
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return fmt.Errorf("timeout waiting for Dart VM service on port %d", port)
		case <-ticker.C:
			// Try to connect to the VM service
			conn, err := net.DialTimeout("tcp", fmt.Sprintf("127.0.0.1:%d", port), 100*time.Millisecond)
			if err == nil {
				conn.Close()
				return nil
			}
		}
	}
}
