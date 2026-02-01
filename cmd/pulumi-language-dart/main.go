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

	// Create a gRPC server
	port, done, err := rpcutil.Serve(0, nil, []func(*grpc.Server) error{
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
