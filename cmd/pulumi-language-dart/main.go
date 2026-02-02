// pulumi-language-dart is the Pulumi language host plugin for Dart.
//
// This plugin enables Pulumi to run programs written in Dart. It implements
// the LanguageRuntime gRPC interface to:
//   - Detect and validate Dart runtime installations
//   - Execute Dart programs with the Pulumi SDK
//   - Parse pubspec.yaml for dependencies
//   - Generate Dart SDK code for providers
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"

	"github.com/pulumi/pulumi/sdk/v3/go/common/util/cmdutil"
	"github.com/pulumi/pulumi/sdk/v3/go/common/util/logging"
	"github.com/pulumi/pulumi/sdk/v3/go/common/util/rpcutil"
	pulumirpc "github.com/pulumi/pulumi/sdk/v3/proto/go"
	"google.golang.org/grpc"
)

// Version is set at build time.
var Version string = "0.1.0-dev"

func main() {
	// Set up logging
	logging.InitLogging(false, 0, false)

	// Create a cancelable context
	ctx := context.Background()

	// Run the language host
	if err := run(ctx); err != nil {
		cmdutil.Exit(err)
	}
}

func run(ctx context.Context) error {
	// Parse command line arguments
	// The Pulumi CLI passes arguments like:
	//   --tracing <endpoint>
	//   --logtostderr
	//   --engine <address>
	// We need to start a gRPC server for the CLI to connect to.

	var engineAddress string
	var tracing string
	flag.StringVar(&engineAddress, "engine", "", "Address of the Pulumi engine gRPC server")
	flag.StringVar(&tracing, "tracing", "", "Tracing endpoint")
	flag.Parse()

	// Create the language host with the engine address
	host := NewDartLanguageHostWithEngine(engineAddress)

	// Set up graceful shutdown on interrupt signal.
	// This follows the same pattern as the official Pulumi Go language host.
	// When the Pulumi CLI sends an interrupt (SIGINT on Unix, CTRL_BREAK_EVENT on Windows),
	// we gracefully stop the gRPC server instead of letting it be killed abruptly.
	ctx, cancel := signal.NotifyContext(ctx, os.Interrupt)
	defer cancel()

	// Map the context Done channel to the rpcutil boolean cancel channel.
	// When an interrupt is received, the context is cancelled, which triggers
	// closing of cancelChannel, which in turn tells rpcutil.Serve to gracefully stop.
	cancelChannel := make(chan bool)
	go func() {
		<-ctx.Done()
		cancel() // Deregister handler so we don't catch another interrupt
		close(cancelChannel)
	}()

	// Create a gRPC server
	port, done, err := rpcutil.Serve(0, cancelChannel, []func(*grpc.Server) error{
		func(srv *grpc.Server) error {
			pulumirpc.RegisterLanguageRuntimeServer(srv, host)
			return nil
		},
	}, nil)
	if err != nil {
		return fmt.Errorf("failed to start language host: %w", err)
	}

	// Print the port to stdout so the CLI can connect
	fmt.Printf("%d\n", port)

	// Wait for the server to finish
	if err := <-done; err != nil {
		return fmt.Errorf("language host error: %w", err)
	}

	return nil
}

// version returns the version string for this plugin.
func version() string {
	if Version == "" {
		return "0.1.0-dev"
	}
	return Version
}
