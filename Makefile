# Makefile for pulumi-dart
# Common development tasks for building, testing, and packaging

.PHONY: all build build-all test test-go test-dart test-integration lint clean help
.PHONY: install install-deps generate-proto generate-sdk dist release

# Configuration
VERSION ?= dev
OUTPUT_DIR ?= dist
GO_MODULE_LANG := cmd/pulumi-language-dart
GO_MODULE_CODEGEN := pkg/codegen/dart
DART_SDK := sdk/dart
TESTS_DIR := tests/integration
BINARY_NAME := pulumi-language-dart

# Build flags
GO_BUILD_FLAGS := -ldflags="-s -w"
GO_BUILD_FLAGS_RELEASE := -ldflags="-s -w -X main.Version=$(VERSION)"

# Platforms for cross-compilation
PLATFORMS := linux-amd64 linux-arm64 darwin-amd64 darwin-arm64 windows-amd64

# Detect OS for local builds
ifeq ($(OS),Windows_NT)
    BINARY_EXT := .exe
    SHELL_PREFIX :=
else
    BINARY_EXT :=
    SHELL_PREFIX :=
endif

# Default target
all: build test

#------------------------------------------------------------------------------
# Build targets
#------------------------------------------------------------------------------

## build: Build the language host for the current platform
build:
	@echo "Building pulumi-language-dart..."
	cd $(GO_MODULE_LANG) && go build -o $(BINARY_NAME)$(BINARY_EXT) .
	@echo "Built: $(GO_MODULE_LANG)/$(BINARY_NAME)$(BINARY_EXT)"

## build-all: Build for all supported platforms
build-all: $(addprefix build-,$(PLATFORMS))

build-linux-amd64:
	@echo "Building for linux-amd64..."
	@mkdir -p $(OUTPUT_DIR)/linux-amd64
	cd $(GO_MODULE_LANG) && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build $(GO_BUILD_FLAGS) -o ../../$(OUTPUT_DIR)/linux-amd64/$(BINARY_NAME) .

build-linux-arm64:
	@echo "Building for linux-arm64..."
	@mkdir -p $(OUTPUT_DIR)/linux-arm64
	cd $(GO_MODULE_LANG) && GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build $(GO_BUILD_FLAGS) -o ../../$(OUTPUT_DIR)/linux-arm64/$(BINARY_NAME) .

build-darwin-amd64:
	@echo "Building for darwin-amd64..."
	@mkdir -p $(OUTPUT_DIR)/darwin-amd64
	cd $(GO_MODULE_LANG) && GOOS=darwin GOARCH=amd64 CGO_ENABLED=0 go build $(GO_BUILD_FLAGS) -o ../../$(OUTPUT_DIR)/darwin-amd64/$(BINARY_NAME) .

build-darwin-arm64:
	@echo "Building for darwin-arm64..."
	@mkdir -p $(OUTPUT_DIR)/darwin-arm64
	cd $(GO_MODULE_LANG) && GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go build $(GO_BUILD_FLAGS) -o ../../$(OUTPUT_DIR)/darwin-arm64/$(BINARY_NAME) .

build-windows-amd64:
	@echo "Building for windows-amd64..."
	@mkdir -p $(OUTPUT_DIR)/windows-amd64
	cd $(GO_MODULE_LANG) && GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build $(GO_BUILD_FLAGS) -o ../../$(OUTPUT_DIR)/windows-amd64/$(BINARY_NAME).exe .

#------------------------------------------------------------------------------
# Test targets
#------------------------------------------------------------------------------

## test: Run all tests
test: test-go test-dart

## test-go: Run Go tests (language host and codegen)
test-go: test-lang test-codegen

## test-lang: Run language host tests
test-lang:
	@echo "Testing language host..."
	cd $(GO_MODULE_LANG) && go test -v -race -coverprofile=coverage.out ./...

## test-codegen: Run codegen tests
test-codegen:
	@echo "Testing codegen..."
	cd $(GO_MODULE_CODEGEN) && go test -v -race -coverprofile=coverage.out ./...

## test-dart: Run Dart SDK tests
test-dart:
	@echo "Testing Dart SDK..."
	cd $(DART_SDK) && dart test

## test-integration: Run integration tests
test-integration: build
	@echo "Testing integration..."
	cd $(TESTS_DIR) && dart test

## test-e2e: Run end-to-end tests with real Pulumi CLI
test-e2e: build
	@echo "Running E2E tests..."
	cd $(TESTS_DIR) && PULUMI_DART_E2E=true dart test test/pulumi_cli_test.dart

#------------------------------------------------------------------------------
# Coverage targets
#------------------------------------------------------------------------------

## coverage: Generate combined coverage report
coverage: test-go
	@echo "Coverage reports generated:"
	@echo "  - $(GO_MODULE_LANG)/coverage.out"
	@echo "  - $(GO_MODULE_CODEGEN)/coverage.out"

#------------------------------------------------------------------------------
# Code generation targets
#------------------------------------------------------------------------------

## generate-proto: Regenerate protocol buffer files
generate-proto:
	@echo "Generating proto files..."
	./scripts/generate_proto.sh

## generate-sdk: Generate a provider SDK (usage: make generate-sdk PROVIDER=pulumi-random)
generate-sdk: build
ifndef PROVIDER
	$(error PROVIDER is required. Usage: make generate-sdk PROVIDER=pulumi-random)
endif
	@echo "Generating SDK for $(PROVIDER)..."
	./scripts/gen-provider.sh $(PROVIDER)

#------------------------------------------------------------------------------
# Installation targets
#------------------------------------------------------------------------------

## install-deps: Install all project dependencies
install-deps:
	@echo "Installing Go dependencies..."
	cd $(GO_MODULE_LANG) && go mod download
	cd $(GO_MODULE_CODEGEN) && go mod download
	@echo "Installing Dart dependencies..."
	cd $(DART_SDK) && dart pub get
	cd $(TESTS_DIR) && dart pub get

## install: Install the language host to GOPATH/bin
install:
	@echo "Installing pulumi-language-dart..."
	cd $(GO_MODULE_LANG) && go install .

#------------------------------------------------------------------------------
# Distribution targets
#------------------------------------------------------------------------------

## dist: Create distribution archives for all platforms
dist: build-all
	@echo "Creating distribution archives..."
	@for platform in $(PLATFORMS); do \
		echo "  Creating archive for $$platform..."; \
		if echo "$$platform" | grep -q "windows"; then \
			cd $(OUTPUT_DIR)/$$platform && tar -czvf ../$(BINARY_NAME)-$(VERSION)-$$platform.tar.gz $(BINARY_NAME).exe; \
		else \
			cd $(OUTPUT_DIR)/$$platform && tar -czvf ../$(BINARY_NAME)-$(VERSION)-$$platform.tar.gz $(BINARY_NAME); \
		fi; \
		cd - > /dev/null; \
	done
	@echo "Distribution archives created in $(OUTPUT_DIR)/"
	@ls -la $(OUTPUT_DIR)/*.tar.gz

## release: Create a versioned release (usage: make release VERSION=v0.1.0)
release:
ifeq ($(VERSION),dev)
	$(error VERSION is required. Usage: make release VERSION=v0.1.0)
endif
	@echo "Creating release $(VERSION)..."
	$(MAKE) dist VERSION=$(VERSION)
	@echo "Release $(VERSION) complete!"
	@echo "To publish, run: git tag $(VERSION) && git push origin $(VERSION)"

#------------------------------------------------------------------------------
# Utility targets
#------------------------------------------------------------------------------

## lint: Run linters
lint:
	@echo "Running Go linters..."
	cd $(GO_MODULE_LANG) && go vet ./...
	cd $(GO_MODULE_CODEGEN) && go vet ./...
	@echo "Running Dart analyzer..."
	cd $(DART_SDK) && dart analyze

## clean: Remove build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(OUTPUT_DIR)
	rm -f $(GO_MODULE_LANG)/$(BINARY_NAME)
	rm -f $(GO_MODULE_LANG)/$(BINARY_NAME).exe
	rm -f $(GO_MODULE_LANG)/coverage.out
	rm -f $(GO_MODULE_CODEGEN)/coverage.out
	@echo "Clean complete."

## help: Show this help message
help:
	@echo "pulumi-dart Makefile"
	@echo ""
	@echo "Usage: make [target] [VAR=value]"
	@echo ""
	@echo "Targets:"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /' | column -t -s ':'
	@echo ""
	@echo "Variables:"
	@echo "  VERSION     Version string for releases (default: dev)"
	@echo "  OUTPUT_DIR  Output directory for builds (default: dist)"
	@echo "  PROVIDER    Provider name for SDK generation"
	@echo ""
	@echo "Examples:"
	@echo "  make                    # Build and test"
	@echo "  make build              # Build for current platform"
	@echo "  make build-all          # Build for all platforms"
	@echo "  make test               # Run all tests"
	@echo "  make dist VERSION=v0.1.0  # Create release archives"
	@echo "  make generate-sdk PROVIDER=pulumi-random"
