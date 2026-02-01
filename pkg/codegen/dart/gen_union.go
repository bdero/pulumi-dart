package dart

import (
	"bytes"
	"fmt"
	"strings"

	"github.com/pulumi/pulumi/pkg/v3/codegen/schema"
)

// UnionTypeInfo contains information needed to generate a sealed class for a union type.
type UnionTypeInfo struct {
	Name         string
	ElementTypes []schema.Type
	Token        string
}

// generateUnionType generates a Dart sealed class for a union type.
// Union types in Pulumi schemas are represented as sealed class hierarchies in Dart 3.0+.
func generateUnionType(pkg *schema.Package, info *UnionTypeInfo) ([]byte, error) {
	var buf bytes.Buffer

	className := info.Name

	// File header
	buf.WriteString(fmt.Sprintf("/// Generated union type for %s.\n", info.Token))
	buf.WriteString("///\n")
	buf.WriteString("/// This is a sealed class representing a union of multiple types.\n")
	buf.WriteString("/// Use pattern matching (switch expressions) to handle each variant.\n")
	buf.WriteString("\n")

	// Imports
	buf.WriteString("import 'package:pulumi/pulumi.dart';\n")

	// Collect imports for element types
	imports := collectUnionTypeImports(pkg, info.ElementTypes)
	for _, imp := range imports {
		buf.WriteString(fmt.Sprintf("import '%s';\n", imp))
	}
	buf.WriteString("\n")

	// Generate the sealed base class
	buf.WriteString(fmt.Sprintf("sealed class %s {\n", className))
	buf.WriteString(fmt.Sprintf("  const %s();\n\n", className))

	// Generate factory constructors for each variant
	for i, elemType := range info.ElementTypes {
		variantName := getUnionVariantName(elemType, i)
		dartType := typeToDart(elemType, true)
		buf.WriteString(fmt.Sprintf("  /// Creates a %s variant.\n", variantName))
		buf.WriteString(fmt.Sprintf("  factory %s.%s(%s value) = %s%s;\n\n",
			className, toCamelCase(variantName), dartType, className, variantName))
	}

	// Generate a method to get the underlying value as Object
	buf.WriteString("  /// Returns the underlying value.\n")
	buf.WriteString("  Object get value;\n")
	buf.WriteString("}\n\n")

	// Generate subclasses for each variant
	for i, elemType := range info.ElementTypes {
		variantName := getUnionVariantName(elemType, i)
		dartType := typeToDart(elemType, true)
		subclassName := className + variantName

		buf.WriteString(fmt.Sprintf("/// Variant for %s values in %s.\n", dartType, className))
		buf.WriteString(fmt.Sprintf("final class %s extends %s {\n", subclassName, className))
		buf.WriteString(fmt.Sprintf("  @override\n"))
		buf.WriteString(fmt.Sprintf("  final %s value;\n\n", dartType))
		buf.WriteString(fmt.Sprintf("  const %s(this.value);\n\n", subclassName))

		// Override toString for debugging
		buf.WriteString("  @override\n")
		buf.WriteString(fmt.Sprintf("  String toString() => '%s($value)';\n\n", subclassName))

		// Override equality
		buf.WriteString("  @override\n")
		buf.WriteString("  bool operator ==(Object other) =>\n")
		buf.WriteString(fmt.Sprintf("      identical(this, other) ||\n"))
		buf.WriteString(fmt.Sprintf("      other is %s && other.value == value;\n\n", subclassName))

		buf.WriteString("  @override\n")
		buf.WriteString("  int get hashCode => value.hashCode;\n")
		buf.WriteString("}\n")

		if i < len(info.ElementTypes)-1 {
			buf.WriteString("\n")
		}
	}

	return buf.Bytes(), nil
}

// getUnionVariantName generates a variant name for a type in a union.
func getUnionVariantName(t schema.Type, index int) string {
	switch tt := t.(type) {
	case *schema.ObjectType:
		return tokenToClassName(tt.Token)
	case *schema.EnumType:
		return tokenToClassName(tt.Token)
	case *schema.ArrayType:
		elementName := getUnionVariantName(tt.ElementType, 0)
		return elementName + "List"
	case *schema.MapType:
		elementName := getUnionVariantName(tt.ElementType, 0)
		return elementName + "Map"
	case *schema.ResourceType:
		return tokenToClassName(tt.Token)
	case *schema.TokenType:
		if tt.UnderlyingType != nil {
			return getUnionVariantName(tt.UnderlyingType, index)
		}
		return tokenToClassName(tt.Token)
	default:
		// Primitive types
		switch t {
		case schema.BoolType:
			return "Bool"
		case schema.IntType:
			return "Int"
		case schema.NumberType:
			return "Double"
		case schema.StringType:
			return "String"
		case schema.ArchiveType:
			return "Archive"
		case schema.AssetType:
			return "Asset"
		case schema.JSONType:
			return "Json"
		case schema.AnyType:
			return "Any"
		default:
			return fmt.Sprintf("Variant%d", index)
		}
	}
}

// collectUnionTypeImports gathers import paths needed for union type variants.
func collectUnionTypeImports(pkg *schema.Package, types []schema.Type) []string {
	var imports []string
	seen := make(map[string]bool)

	for _, t := range types {
		collectTypeImportsFromType(pkg, t, &imports, seen)
	}

	return dedupeStrings(imports)
}

// isComplexUnion checks if a union type requires a sealed class representation.
// Returns true for unions that have more than one distinct, non-optional type.
func isComplexUnion(unionType *schema.UnionType) bool {
	if len(unionType.ElementTypes) <= 1 {
		return false
	}

	// Count non-optional types
	nonOptionalCount := 0
	for _, elem := range unionType.ElementTypes {
		if _, isOptional := elem.(*schema.OptionalType); !isOptional {
			nonOptionalCount++
		}
	}

	// A complex union has more than one non-optional type
	return nonOptionalCount > 1
}

// generateUnionTypeName creates a name for a generated union type based on its elements.
func generateUnionTypeName(unionType *schema.UnionType) string {
	var names []string
	for i, elem := range unionType.ElementTypes {
		if _, isOptional := elem.(*schema.OptionalType); !isOptional {
			names = append(names, getUnionVariantName(elem, i))
		}
	}
	if len(names) == 0 {
		return "UnionType"
	}
	return strings.Join(names, "Or")
}
