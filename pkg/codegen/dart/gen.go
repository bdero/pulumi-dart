// Package dart implements Dart code generation for Pulumi packages.
//
// This package generates Dart SDKs from Pulumi package schemas, enabling
// Dart developers to use Pulumi providers in their infrastructure code.
package dart

import (
	"bytes"
	"fmt"
	"path/filepath"
	"strings"

	"github.com/pulumi/pulumi/pkg/v3/codegen/schema"
)

// GeneratorOptions configures the Dart code generator.
type GeneratorOptions struct {
	// PackageName overrides the default package name derived from the schema.
	PackageName string

	// PackageVersion specifies the version for the generated package.
	PackageVersion string

	// PublishTo specifies the pub.dev publisher for the package.
	PublishTo string

	// BasePath specifies the base import path for the generated package.
	BasePath string
}

// Generator generates Dart code from a Pulumi package schema.
type Generator struct {
	pkg     *schema.Package
	options GeneratorOptions
}

// NewGenerator creates a new Dart code generator for the given package schema.
func NewGenerator(pkg *schema.Package, options GeneratorOptions) *Generator {
	return &Generator{
		pkg:     pkg,
		options: options,
	}
}

// GeneratePackage generates a complete Dart package from a Pulumi schema.
//
// The returned map contains file paths (relative to the package root) mapped
// to their contents. The caller is responsible for writing these files to disk.
func GeneratePackage(pkg *schema.Package, options GeneratorOptions) (map[string][]byte, error) {
	g := NewGenerator(pkg, options)
	return g.Generate()
}

// Generate produces all files for the Dart package.
func (g *Generator) Generate() (map[string][]byte, error) {
	files := make(map[string][]byte)

	// Generate pubspec.yaml
	pubspec, err := g.generatePubspec()
	if err != nil {
		return nil, fmt.Errorf("failed to generate pubspec.yaml: %w", err)
	}
	files["pubspec.yaml"] = pubspec

	// Generate analysis_options.yaml
	files["analysis_options.yaml"] = g.generateAnalysisOptions()

	// Generate main library export file
	mainLib, err := g.generateMainLibrary()
	if err != nil {
		return nil, fmt.Errorf("failed to generate main library: %w", err)
	}
	files[filepath.Join("lib", g.packageName()+".dart")] = mainLib

	// Generate types
	typeFiles, err := g.generateTypes()
	if err != nil {
		return nil, fmt.Errorf("failed to generate types: %w", err)
	}
	for path, content := range typeFiles {
		files[path] = content
	}

	// Generate resources
	resourceFiles, err := g.generateResources()
	if err != nil {
		return nil, fmt.Errorf("failed to generate resources: %w", err)
	}
	for path, content := range resourceFiles {
		files[path] = content
	}

	// Generate functions
	functionFiles, err := g.generateFunctions()
	if err != nil {
		return nil, fmt.Errorf("failed to generate functions: %w", err)
	}
	for path, content := range functionFiles {
		files[path] = content
	}

	// Generate enums
	enumFiles, err := g.generateEnums()
	if err != nil {
		return nil, fmt.Errorf("failed to generate enums: %w", err)
	}
	for path, content := range enumFiles {
		files[path] = content
	}

	return files, nil
}

// packageName returns the Dart package name for this schema.
func (g *Generator) packageName() string {
	if g.options.PackageName != "" {
		return g.options.PackageName
	}
	// Convert schema name to Dart package naming convention (snake_case)
	return "pulumi_" + ToSnakeCase(g.pkg.Name)
}

// packageVersion returns the version for the generated package.
func (g *Generator) packageVersion() string {
	if g.options.PackageVersion != "" {
		return g.options.PackageVersion
	}
	if g.pkg.Version != nil {
		return g.pkg.Version.String()
	}
	return "0.0.1"
}

// generatePubspec generates the pubspec.yaml file for the package.
func (g *Generator) generatePubspec() ([]byte, error) {
	var buf bytes.Buffer

	buf.WriteString(fmt.Sprintf("name: %s\n", g.packageName()))
	buf.WriteString(fmt.Sprintf("version: %s\n", g.packageVersion()))

	if g.pkg.Description != "" {
		buf.WriteString(fmt.Sprintf("description: %s\n", g.pkg.Description))
	} else {
		buf.WriteString(fmt.Sprintf("description: Pulumi provider SDK for %s\n", g.pkg.Name))
	}

	if g.pkg.Repository != "" {
		buf.WriteString(fmt.Sprintf("repository: %s\n", g.pkg.Repository))
	}

	if g.pkg.Homepage != "" {
		buf.WriteString(fmt.Sprintf("homepage: %s\n", g.pkg.Homepage))
	}

	buf.WriteString("\nenvironment:\n")
	buf.WriteString("  sdk: '>=3.8.0 <4.0.0'\n")

	buf.WriteString("\ndependencies:\n")
	buf.WriteString("  pulumi: ^0.1.0\n")
	buf.WriteString("  meta: ^1.11.0\n")
	buf.WriteString("  protobuf: ^3.1.0\n")

	buf.WriteString("\ndev_dependencies:\n")
	buf.WriteString("  test: ^1.25.0\n")
	buf.WriteString("  lints: ^3.0.0\n")

	return buf.Bytes(), nil
}

// generateAnalysisOptions generates the analysis_options.yaml file.
func (g *Generator) generateAnalysisOptions() []byte {
	return []byte(`include: package:lints/recommended.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    - prefer_final_locals
    - prefer_single_quotes
    - sort_constructors_first
    - sort_unnamed_constructors_first
`)
}

// generateMainLibrary generates the main library export file.
func (g *Generator) generateMainLibrary() ([]byte, error) {
	var buf bytes.Buffer

	buf.WriteString(fmt.Sprintf("/// Pulumi SDK for the %s provider.\n", g.pkg.Name))
	buf.WriteString("///\n")
	if g.pkg.Description != "" {
		buf.WriteString(fmt.Sprintf("/// %s\n", g.pkg.Description))
	}
	buf.WriteString(fmt.Sprintf("library %s;\n\n", g.packageName()))

	// Export all generated modules
	// This will be populated by the specific generators
	// Use maps to track exports and avoid duplicates
	exportedTypes := make(map[string]bool)
	exportedEnums := make(map[string]bool)

	buf.WriteString("// Types\n")
	for _, typ := range g.pkg.Types {
		// Only export ObjectTypes with valid tokens - skip built-in types
		objectType, isObject := typ.(*schema.ObjectType)
		if !isObject {
			continue
		}
		// Skip types that don't have a proper token (e.g., built-in types)
		if !strings.Contains(objectType.Token, ":") {
			continue
		}
		name := tokenToModulePath(objectType.Token)
		if name != "" && !exportedTypes[name] {
			exportedTypes[name] = true
			buf.WriteString(fmt.Sprintf("export 'src/types/%s.dart';\n", name))
		}
	}

	buf.WriteString("\n// Enums\n")
	for _, typ := range g.pkg.Types {
		enumType, isEnum := typ.(*schema.EnumType)
		if !isEnum {
			continue
		}
		// Skip enums that don't have a proper token
		if !strings.Contains(enumType.Token, ":") {
			continue
		}
		name := tokenToModulePath(enumType.Token)
		if name != "" && !exportedEnums[name] {
			exportedEnums[name] = true
			buf.WriteString(fmt.Sprintf("export 'src/enums/%s.dart';\n", name))
		}
	}

	buf.WriteString("\n// Resources\n")
	for _, resource := range g.pkg.Resources {
		name := tokenToModulePath(resource.Token)
		if name != "" {
			buf.WriteString(fmt.Sprintf("export 'src/resources/%s.dart';\n", name))
		}
	}

	buf.WriteString("\n// Functions\n")
	for _, function := range g.pkg.Functions {
		name := tokenToModulePath(function.Token)
		if name != "" {
			buf.WriteString(fmt.Sprintf("export 'src/functions/%s.dart';\n", name))
		}
	}

	return buf.Bytes(), nil
}

// generateTypes generates Dart classes for complex types in the schema.
func (g *Generator) generateTypes() (map[string][]byte, error) {
	files := make(map[string][]byte)

	for _, typ := range g.pkg.Types {
		// Skip enums, they're handled separately
		if _, isEnum := typ.(*schema.EnumType); isEnum {
			continue
		}

		objectType, ok := typ.(*schema.ObjectType)
		if !ok {
			continue
		}

		content, err := generateType(g.pkg, objectType)
		if err != nil {
			return nil, fmt.Errorf("failed to generate type %s: %w", objectType.Token, err)
		}

		name := tokenToModulePath(objectType.Token)
		if name != "" {
			files[filepath.Join("lib", "src", "types", name+".dart")] = content
		}
	}

	return files, nil
}

// generateResources generates Dart classes for resources in the schema.
func (g *Generator) generateResources() (map[string][]byte, error) {
	files := make(map[string][]byte)

	for _, resource := range g.pkg.Resources {
		content, err := generateResource(g.pkg, resource)
		if err != nil {
			return nil, fmt.Errorf("failed to generate resource %s: %w", resource.Token, err)
		}

		name := tokenToModulePath(resource.Token)
		if name != "" {
			files[filepath.Join("lib", "src", "resources", name+".dart")] = content
		}
	}

	return files, nil
}

// generateFunctions generates Dart functions for invocations in the schema.
func (g *Generator) generateFunctions() (map[string][]byte, error) {
	files := make(map[string][]byte)

	for _, function := range g.pkg.Functions {
		content, err := generateFunction(g.pkg, function)
		if err != nil {
			return nil, fmt.Errorf("failed to generate function %s: %w", function.Token, err)
		}

		name := tokenToModulePath(function.Token)
		if name != "" {
			files[filepath.Join("lib", "src", "functions", name+".dart")] = content
		}
	}

	return files, nil
}

// generateEnums generates Dart enums from schema enum types.
func (g *Generator) generateEnums() (map[string][]byte, error) {
	files := make(map[string][]byte)

	for _, typ := range g.pkg.Types {
		enumType, ok := typ.(*schema.EnumType)
		if !ok {
			continue
		}

		content, err := generateEnum(g.pkg, enumType)
		if err != nil {
			return nil, fmt.Errorf("failed to generate enum %s: %w", enumType.Token, err)
		}

		name := tokenToModulePath(enumType.Token)
		if name != "" {
			files[filepath.Join("lib", "src", "enums", name+".dart")] = content
		}
	}

	return files, nil
}
