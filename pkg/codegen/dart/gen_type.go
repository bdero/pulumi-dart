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

	className := tokenToQualifiedTypeClassName(objectType.Token)

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
		expr := generatePropertyMapExtraction(prop.Type, fmt.Sprintf("properties['%s']", prop.Name), false)
		buf.WriteString(fmt.Sprintf("      %s: %s,\n", toCamelCase(prop.Name), expr))
	}
	for _, prop := range optionalProps {
		expr := generatePropertyMapExtraction(prop.Type, fmt.Sprintf("properties['%s']", prop.Name), true)
		buf.WriteString(fmt.Sprintf("      %s: %s,\n", toCamelCase(prop.Name), expr))
	}
	buf.WriteString("    );\n")
	buf.WriteString("  }\n\n")

	// Generate toPropertyMap method for serialization
	buf.WriteString("  /// Converts this object to a property map.\n")
	buf.WriteString("  Map<String, dynamic> toPropertyMap() {\n")
	buf.WriteString("    return {\n")
	for _, prop := range objectType.Properties {
		propName := toCamelCase(prop.Name)
		valueExpr := generateToPropertyMapValue(prop.Type, propName)
		if prop.IsRequired() {
			buf.WriteString(fmt.Sprintf("      '%s': %s,\n", prop.Name, valueExpr))
		} else {
			buf.WriteString(fmt.Sprintf("      if (%s != null) '%s': %s,\n", propName, prop.Name, valueExpr))
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

	className := tokenToQualifiedTypeClassName(objectType.Token) + "Args"

	buf.WriteString(fmt.Sprintf("/// Input arguments for %s.\n", tokenToQualifiedTypeClassName(objectType.Token)))
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

// generatePropertyMapExtraction generates a Dart expression to extract a value from a property map.
// This handles nested ObjectTypes by calling their fromPropertyMap factory constructor.
func generatePropertyMapExtraction(t schema.Type, valueExpr string, isOptional bool) string {
	switch tt := t.(type) {
	case *schema.OptionalType:
		return generatePropertyMapExtraction(tt.ElementType, valueExpr, true)

	case *schema.ArrayType:
		dartType := typeToDart(tt.ElementType, true)
		elemExtract := generatePropertyMapListElementExtraction(tt.ElementType)
		if isOptional {
			return fmt.Sprintf("%s != null ? (%s as List).map((e) => %s).toList() : null", valueExpr, valueExpr, elemExtract)
		}
		return fmt.Sprintf("(%s as List?)?.map((e) => %s).toList() ?? <%s>[]", valueExpr, elemExtract, dartType)

	case *schema.MapType:
		dartType := typeToDart(tt.ElementType, true)
		elemExtract := generatePropertyMapMapValueExtraction(tt.ElementType)
		if isOptional {
			return fmt.Sprintf("%s != null ? (%s as Map<String, dynamic>).map((k, v) => MapEntry(k, %s)) : null", valueExpr, valueExpr, elemExtract)
		}
		return fmt.Sprintf("(%s as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, %s)) ?? <String, %s>{}", valueExpr, elemExtract, dartType)

	case *schema.ObjectType:
		className := tokenToQualifiedTypeClassName(tt.Token)
		if isOptional {
			return fmt.Sprintf("%s != null ? %s.fromPropertyMap(%s as Map<String, dynamic>) : null", valueExpr, className, valueExpr)
		}
		return fmt.Sprintf("%s.fromPropertyMap(%s as Map<String, dynamic>)", className, valueExpr)

	case *schema.EnumType:
		className := tokenToQualifiedTypeClassName(tt.Token)
		if isOptional {
			return fmt.Sprintf("%s != null ? %s.fromValue(%s) : null", valueExpr, className, valueExpr)
		}
		return fmt.Sprintf("%s.fromValue(%s)", className, valueExpr)

	default:
		// Primitive types - just cast
		dartType := typeToDart(t, true)
		if isOptional {
			return fmt.Sprintf("%s as %s?", valueExpr, dartType)
		}
		return fmt.Sprintf("%s as %s", valueExpr, dartType)
	}
}

// generatePropertyMapListElementExtraction generates code to extract a list element from a property map.
// The variable 'e' refers to each element in the list being mapped.
func generatePropertyMapListElementExtraction(elemType schema.Type) string {
	switch tt := elemType.(type) {
	case *schema.OptionalType:
		// Handle optional element types
		return generatePropertyMapListElementExtraction(tt.ElementType)
	case *schema.ArrayType:
		// Nested array: List<List<T>> - need to recursively map inner list
		innerExtract := generatePropertyMapListElementExtractionWithVar(tt.ElementType, "inner")
		return fmt.Sprintf("(e as List).map((inner) => %s).toList()", innerExtract)
	case *schema.MapType:
		// Array of maps: List<Map<String, T>> - need to map inner map values
		innerExtract := generatePropertyMapMapValueExtractionWithVar(tt.ElementType, "mapVal")
		return fmt.Sprintf("(e as Map<String, dynamic>).map((mapKey, mapVal) => MapEntry(mapKey, %s))", innerExtract)
	case *schema.ObjectType:
		className := tokenToQualifiedTypeClassName(tt.Token)
		return fmt.Sprintf("%s.fromPropertyMap(e as Map<String, dynamic>)", className)
	case *schema.EnumType:
		className := tokenToQualifiedTypeClassName(tt.Token)
		return fmt.Sprintf("%s.fromValue(e)", className)
	default:
		dartType := typeToDart(elemType, true)
		return fmt.Sprintf("e as %s", dartType)
	}
}

// generatePropertyMapListElementExtractionWithVar is like generatePropertyMapListElementExtraction
// but uses a custom variable name for nested mapping scenarios.
func generatePropertyMapListElementExtractionWithVar(elemType schema.Type, varName string) string {
	switch tt := elemType.(type) {
	case *schema.OptionalType:
		return generatePropertyMapListElementExtractionWithVar(tt.ElementType, varName)
	case *schema.ArrayType:
		// Deeply nested arrays - use unique var names to avoid shadowing
		innerVar := varName + "Inner"
		innerExtract := generatePropertyMapListElementExtractionWithVar(tt.ElementType, innerVar)
		return fmt.Sprintf("(%s as List).map((%s) => %s).toList()", varName, innerVar, innerExtract)
	case *schema.MapType:
		innerVar := varName + "Val"
		innerExtract := generatePropertyMapMapValueExtractionWithVar(tt.ElementType, innerVar)
		return fmt.Sprintf("(%s as Map<String, dynamic>).map((%sKey, %s) => MapEntry(%sKey, %s))", varName, varName, innerVar, varName, innerExtract)
	case *schema.ObjectType:
		className := tokenToQualifiedTypeClassName(tt.Token)
		return fmt.Sprintf("%s.fromPropertyMap(%s as Map<String, dynamic>)", className, varName)
	case *schema.EnumType:
		className := tokenToQualifiedTypeClassName(tt.Token)
		return fmt.Sprintf("%s.fromValue(%s)", className, varName)
	default:
		dartType := typeToDart(elemType, true)
		return fmt.Sprintf("%s as %s", varName, dartType)
	}
}

// generatePropertyMapMapValueExtraction generates code to extract a map value from a property map.
// The variable 'v' refers to each value in the map being mapped.
func generatePropertyMapMapValueExtraction(elemType schema.Type) string {
	switch tt := elemType.(type) {
	case *schema.OptionalType:
		return generatePropertyMapMapValueExtraction(tt.ElementType)
	case *schema.ArrayType:
		// Map of arrays: Map<String, List<T>> - need to map inner list
		innerExtract := generatePropertyMapListElementExtractionWithVar(tt.ElementType, "listElem")
		return fmt.Sprintf("(v as List).map((listElem) => %s).toList()", innerExtract)
	case *schema.MapType:
		// Nested maps: Map<String, Map<String, T>> - need to recursively map inner map
		innerExtract := generatePropertyMapMapValueExtractionWithVar(tt.ElementType, "innerVal")
		return fmt.Sprintf("(v as Map<String, dynamic>).map((innerKey, innerVal) => MapEntry(innerKey, %s))", innerExtract)
	case *schema.ObjectType:
		className := tokenToQualifiedTypeClassName(tt.Token)
		return fmt.Sprintf("%s.fromPropertyMap(v as Map<String, dynamic>)", className)
	case *schema.EnumType:
		className := tokenToQualifiedTypeClassName(tt.Token)
		return fmt.Sprintf("%s.fromValue(v)", className)
	default:
		dartType := typeToDart(elemType, true)
		return fmt.Sprintf("v as %s", dartType)
	}
}

// generatePropertyMapMapValueExtractionWithVar is like generatePropertyMapMapValueExtraction
// but uses a custom variable name for nested mapping scenarios.
func generatePropertyMapMapValueExtractionWithVar(elemType schema.Type, varName string) string {
	switch tt := elemType.(type) {
	case *schema.OptionalType:
		return generatePropertyMapMapValueExtractionWithVar(tt.ElementType, varName)
	case *schema.ArrayType:
		innerVar := varName + "Elem"
		innerExtract := generatePropertyMapListElementExtractionWithVar(tt.ElementType, innerVar)
		return fmt.Sprintf("(%s as List).map((%s) => %s).toList()", varName, innerVar, innerExtract)
	case *schema.MapType:
		innerVar := varName + "Inner"
		innerExtract := generatePropertyMapMapValueExtractionWithVar(tt.ElementType, innerVar)
		return fmt.Sprintf("(%s as Map<String, dynamic>).map((%sKey, %s) => MapEntry(%sKey, %s))", varName, varName, innerVar, varName, innerExtract)
	case *schema.ObjectType:
		className := tokenToQualifiedTypeClassName(tt.Token)
		return fmt.Sprintf("%s.fromPropertyMap(%s as Map<String, dynamic>)", className, varName)
	case *schema.EnumType:
		className := tokenToQualifiedTypeClassName(tt.Token)
		return fmt.Sprintf("%s.fromValue(%s)", className, varName)
	default:
		dartType := typeToDart(elemType, true)
		return fmt.Sprintf("%s as %s", varName, dartType)
	}
}

// generateToPropertyMapValue generates a Dart expression for serializing a value to a property map.
// This handles nested ObjectTypes by calling their toPropertyMap method.
func generateToPropertyMapValue(t schema.Type, valueExpr string) string {
	switch tt := t.(type) {
	case *schema.OptionalType:
		// For optional types, add null-aware call
		innerExpr := generateToPropertyMapValue(tt.ElementType, valueExpr)
		// If the inner expression is different from the value (has transformation), add null check
		if innerExpr != valueExpr {
			return fmt.Sprintf("%s != null ? %s : null", valueExpr, generateToPropertyMapValue(tt.ElementType, valueExpr+"!"))
		}
		return valueExpr

	case *schema.ArrayType:
		elemTransform := generateToPropertyMapListElement(tt.ElementType)
		if elemTransform != "e" {
			return fmt.Sprintf("%s.map((e) => %s).toList()", valueExpr, elemTransform)
		}
		return valueExpr

	case *schema.MapType:
		elemTransform := generateToPropertyMapMapValue(tt.ElementType)
		if elemTransform != "v" {
			return fmt.Sprintf("%s.map((k, v) => MapEntry(k, %s))", valueExpr, elemTransform)
		}
		return valueExpr

	case *schema.ObjectType:
		return fmt.Sprintf("%s.toPropertyMap()", valueExpr)

	case *schema.EnumType:
		return fmt.Sprintf("%s.value", valueExpr)

	default:
		return valueExpr
	}
}

// generateToPropertyMapListElement generates code to serialize a list element.
func generateToPropertyMapListElement(elemType schema.Type) string {
	switch tt := elemType.(type) {
	case *schema.ObjectType:
		return "e.toPropertyMap()"
	case *schema.EnumType:
		_ = tt
		return "e.value"
	default:
		return "e"
	}
}

// generateToPropertyMapMapValue generates code to serialize a map value.
func generateToPropertyMapMapValue(elemType schema.Type) string {
	switch tt := elemType.(type) {
	case *schema.ObjectType:
		return "v.toPropertyMap()"
	case *schema.EnumType:
		_ = tt
		return "v.value"
	default:
		return "v"
	}
}
