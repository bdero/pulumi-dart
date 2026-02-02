package dart

import (
	"bytes"
	"fmt"
	"strings"

	"github.com/pulumi/pulumi/pkg/v3/codegen/schema"
)

// generateType generates a Dart class for a complex object type.
func generateType(pkg *schema.Package, objectType *schema.ObjectType) ([]byte, error) {
	var buf bytes.Buffer

	className := tokenToQualifiedClassName(objectType.Token)

	// File header
	buf.WriteString(fmt.Sprintf("/// Generated type class for %s.\n", objectType.Token))
	buf.WriteString("///\n")
	if objectType.Comment != "" {
		for _, line := range strings.Split(objectType.Comment, "\n") {
			buf.WriteString(fmt.Sprintf("/// %s\n", line))
		}
	}
	buf.WriteString("\n")

	// Imports
	buf.WriteString("import 'package:pulumi/pulumi.dart';\n")

	// Collect imports for property types
	imports := collectObjectTypeImports(pkg, objectType.Properties)
	for _, imp := range imports {
		buf.WriteString(fmt.Sprintf("import '%s';\n", imp))
	}
	buf.WriteString("\n")

	// Generate the class
	// Note: ObjectType doesn't have a DeprecationMessage field in the schema

	buf.WriteString(fmt.Sprintf("class %s {\n", className))

	// Separate required and optional properties
	var requiredProps, optionalProps []*schema.Property
	for _, prop := range objectType.Properties {
		if prop.IsRequired() {
			requiredProps = append(requiredProps, prop)
		} else {
			optionalProps = append(optionalProps, prop)
		}
	}

	// Generate property fields
	for _, prop := range objectType.Properties {
		if prop.Comment != "" {
			buf.WriteString(fmt.Sprintf("  /// %s\n", strings.ReplaceAll(prop.Comment, "\n", "\n  /// ")))
		}
		if prop.DeprecationMessage != "" {
			buf.WriteString(fmt.Sprintf("  @Deprecated('%s')\n", escapeDartString(prop.DeprecationMessage)))
		}
		dartType := typeToDart(prop.Type, true)
		if !prop.IsRequired() {
			buf.WriteString(fmt.Sprintf("  final %s? %s;\n\n", dartType, toCamelCase(prop.Name)))
		} else {
			buf.WriteString(fmt.Sprintf("  final %s %s;\n\n", dartType, toCamelCase(prop.Name)))
		}
	}

	// Constructor
	if len(objectType.Properties) > 0 {
		buf.WriteString(fmt.Sprintf("  %s({\n", className))
		for _, prop := range requiredProps {
			buf.WriteString(fmt.Sprintf("    required this.%s,\n", toCamelCase(prop.Name)))
		}
		for _, prop := range optionalProps {
			buf.WriteString(fmt.Sprintf("    this.%s,\n", toCamelCase(prop.Name)))
		}
		buf.WriteString("  });\n\n")
	} else {
		buf.WriteString(fmt.Sprintf("  %s();\n\n", className))
	}

	// Generate fromPropertyValue factory constructor for deserialization
	buf.WriteString(fmt.Sprintf("  /// Creates a %s from a property map.\n", className))
	buf.WriteString(fmt.Sprintf("  factory %s.fromPropertyMap(Map<String, dynamic> properties) {\n", className))
	buf.WriteString(fmt.Sprintf("    return %s(\n", className))
	for _, prop := range requiredProps {
		dartType := typeToDart(prop.Type, true)
		buf.WriteString(fmt.Sprintf("      %s: properties['%s'] as %s,\n",
			toCamelCase(prop.Name), prop.Name, dartType))
	}
	for _, prop := range optionalProps {
		dartType := typeToDart(prop.Type, true)
		buf.WriteString(fmt.Sprintf("      %s: properties['%s'] as %s?,\n",
			toCamelCase(prop.Name), prop.Name, dartType))
	}
	buf.WriteString("    );\n")
	buf.WriteString("  }\n\n")

	// Generate toPropertyMap method for serialization
	buf.WriteString("  /// Converts this object to a property map.\n")
	buf.WriteString("  Map<String, dynamic> toPropertyMap() {\n")
	buf.WriteString("    return {\n")
	for _, prop := range objectType.Properties {
		propName := toCamelCase(prop.Name)
		if prop.IsRequired() {
			buf.WriteString(fmt.Sprintf("      '%s': %s,\n", prop.Name, propName))
		} else {
			buf.WriteString(fmt.Sprintf("      if (%s != null) '%s': %s,\n", propName, prop.Name, propName))
		}
	}
	buf.WriteString("    };\n")
	buf.WriteString("  }\n")

	buf.WriteString("}\n")

	// If this type has input properties, generate an Args class as well
	if objectType.IsInputShape() {
		buf.WriteString("\n")
		argsClass, err := generateTypeArgs(pkg, objectType)
		if err != nil {
			return nil, err
		}
		buf.Write(argsClass)
	}

	return buf.Bytes(), nil
}

// generateTypeArgs generates an Args class for input shapes.
func generateTypeArgs(pkg *schema.Package, objectType *schema.ObjectType) ([]byte, error) {
	var buf bytes.Buffer

	className := tokenToQualifiedClassName(objectType.Token) + "Args"

	buf.WriteString(fmt.Sprintf("/// Input arguments for %s.\n", tokenToQualifiedClassName(objectType.Token)))
	buf.WriteString(fmt.Sprintf("class %s {\n", className))

	// Separate required and optional properties
	var requiredProps, optionalProps []*schema.Property
	for _, prop := range objectType.Properties {
		if prop.IsRequired() {
			requiredProps = append(requiredProps, prop)
		} else {
			optionalProps = append(optionalProps, prop)
		}
	}

	// Generate property fields with Input<T> wrapping
	for _, prop := range objectType.Properties {
		if prop.Comment != "" {
			buf.WriteString(fmt.Sprintf("  /// %s\n", strings.ReplaceAll(prop.Comment, "\n", "\n  /// ")))
		}
		dartType := typeToDart(prop.Type, true)
		if !prop.IsRequired() {
			buf.WriteString(fmt.Sprintf("  final Input<%s>? %s;\n\n", dartType, toCamelCase(prop.Name)))
		} else {
			buf.WriteString(fmt.Sprintf("  final Input<%s> %s;\n\n", dartType, toCamelCase(prop.Name)))
		}
	}

	// Constructor
	if len(objectType.Properties) > 0 {
		buf.WriteString(fmt.Sprintf("  %s({\n", className))
		for _, prop := range requiredProps {
			buf.WriteString(fmt.Sprintf("    required this.%s,\n", toCamelCase(prop.Name)))
		}
		for _, prop := range optionalProps {
			buf.WriteString(fmt.Sprintf("    this.%s,\n", toCamelCase(prop.Name)))
		}
		buf.WriteString("  });\n")
	} else {
		buf.WriteString(fmt.Sprintf("  %s();\n", className))
	}

	buf.WriteString("}\n")

	return buf.Bytes(), nil
}

// collectObjectTypeImports gathers import paths needed for object type properties.
func collectObjectTypeImports(pkg *schema.Package, props []*schema.Property) []string {
	var imports []string
	seen := make(map[string]bool)

	for _, prop := range props {
		collectTypeImportsFromType(pkg, prop.Type, &imports, seen)
	}

	return dedupeStrings(imports)
}
