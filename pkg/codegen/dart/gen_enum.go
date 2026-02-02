package dart

import (
	"bytes"
	"fmt"
	"strings"

	"github.com/pulumi/pulumi/pkg/v3/codegen/schema"
)

// generateEnum generates a Dart enum type from a Pulumi schema enum.
func generateEnum(pkg *schema.Package, enumType *schema.EnumType) ([]byte, error) {
	var buf bytes.Buffer

	enumName := tokenToQualifiedTypeClassName(enumType.Token)

	// File header
	buf.WriteString(fmt.Sprintf("/// Generated enum type for %s.\n", enumType.Token))
	buf.WriteString("///\n")
	if enumType.Comment != "" {
		for _, line := range sanitizeCommentLines(enumType.Comment) {
			buf.WriteString(fmt.Sprintf("/// %s\n", line))
		}
	}
	buf.WriteString("\n")

	// Determine the underlying type for the enum value
	underlyingType := "String"
	switch enumType.ElementType {
	case schema.IntType:
		underlyingType = "int"
	case schema.NumberType:
		underlyingType = "double"
	case schema.BoolType:
		underlyingType = "bool"
	}

	// Generate the enum using Dart's enhanced enums
	// Note: EnumType itself doesn't have a DeprecationMessage field in the schema

	buf.WriteString(fmt.Sprintf("enum %s {\n", enumName))

	// Track used case names to avoid duplicates
	usedNames := make(map[string]int)

	// Generate enum values
	for i, value := range enumType.Elements {
		// Generate documentation comment
		if value.Comment != "" {
			buf.WriteString(fmt.Sprintf("  /// %s\n", formatPropertyComment(value.Comment)))
		}

		// Deprecation annotation
		if value.DeprecationMessage != "" {
			buf.WriteString(fmt.Sprintf("  @Deprecated('%s')\n", escapeDartString(value.DeprecationMessage)))
		}

		// Generate the enum case name
		// Use Name if provided, otherwise derive from Value
		enumValueName := value.Name
		if enumValueName == "" {
			// Fall back to using the value itself as the name
			if strVal, ok := value.Value.(string); ok {
				enumValueName = strVal
			} else {
				enumValueName = fmt.Sprintf("%v", value.Value)
			}
		}
		caseName := toEnumCaseName(enumValueName)

		// Handle duplicate names by appending a numeric suffix
		if count, exists := usedNames[caseName]; exists {
			usedNames[caseName] = count + 1
			caseName = fmt.Sprintf("%s%d", caseName, count+1)
		} else {
			usedNames[caseName] = 1
		}

		// Format the value based on type
		var valueStr string
		switch v := value.Value.(type) {
		case string:
			valueStr = fmt.Sprintf("'%s'", escapeDartString(v))
		case int:
			valueStr = fmt.Sprintf("%d", v)
		case int64:
			valueStr = fmt.Sprintf("%d", v)
		case float64:
			valueStr = fmt.Sprintf("%g", v)
		case bool:
			valueStr = fmt.Sprintf("%t", v)
		default:
			valueStr = fmt.Sprintf("'%v'", value.Value)
		}

		// Write the enum case
		if i < len(enumType.Elements)-1 {
			buf.WriteString(fmt.Sprintf("  %s._(%s),\n\n", caseName, valueStr))
		} else {
			buf.WriteString(fmt.Sprintf("  %s._(%s);\n\n", caseName, valueStr))
		}
	}

	// Generate the value field and constructor
	buf.WriteString(fmt.Sprintf("  /// The underlying value of this enum member.\n"))
	buf.WriteString(fmt.Sprintf("  final %s value;\n\n", underlyingType))
	buf.WriteString(fmt.Sprintf("  const %s._(this.value);\n\n", enumName))

	// Generate toString override
	buf.WriteString("  @override\n")
	buf.WriteString("  String toString() => value.toString();\n\n")

	// Generate fromValue factory for deserialization
	buf.WriteString(fmt.Sprintf("  /// Returns the enum member matching the given value.\n"))
	buf.WriteString(fmt.Sprintf("  ///\n"))
	buf.WriteString(fmt.Sprintf("  /// Throws [ArgumentError] if no member matches.\n"))
	buf.WriteString(fmt.Sprintf("  static %s fromValue(%s value) {\n", enumName, underlyingType))
	buf.WriteString(fmt.Sprintf("    return %s.values.firstWhere(\n", enumName))
	buf.WriteString("      (e) => e.value == value,\n")
	buf.WriteString(fmt.Sprintf("      orElse: () => throw ArgumentError('Unknown %s value: $value'),\n", enumName))
	buf.WriteString("    );\n")
	buf.WriteString("  }\n\n")

	// Generate tryFromValue for safe deserialization
	buf.WriteString(fmt.Sprintf("  /// Returns the enum member matching the given value, or null if not found.\n"))
	buf.WriteString(fmt.Sprintf("  static %s? tryFromValue(%s value) {\n", enumName, underlyingType))
	buf.WriteString("    try {\n")
	buf.WriteString(fmt.Sprintf("      return %s.fromValue(value);\n", enumName))
	buf.WriteString("    } on ArgumentError {\n")
	buf.WriteString("      return null;\n")
	buf.WriteString("    }\n")
	buf.WriteString("  }\n")

	buf.WriteString("}\n")

	return buf.Bytes(), nil
}

// toEnumCaseName converts a value name to a valid Dart enum case name.
func toEnumCaseName(name string) string {
	// Handle special cases for common enum patterns
	name = strings.TrimSpace(name)

	// Handle reserved words BEFORE conversion, since toCamelCase adds "_" suffix
	reservedWords := map[string]string{
		"default": "defaultValue",
		"class":   "classValue",
		"switch":  "switchValue",
		"case":    "caseValue",
		"new":     "newValue",
		"null":    "nullValue",
		"true":    "trueValue",
		"false":   "falseValue",
		"in":      "inValue",
		"is":      "isValue",
		"as":      "asValue",
	}

	// Check if the lowercased name is a reserved word
	lowerName := strings.ToLower(name)
	if replacement, ok := reservedWords[lowerName]; ok {
		return replacement
	}

	// If it starts with a digit, prefix with 'v'
	if len(name) > 0 && name[0] >= '0' && name[0] <= '9' {
		name = "v" + name
	}

	// Convert to camelCase
	result := toCamelCase(name)

	// Handle empty or invalid names
	if result == "" || result == "_" {
		return "unknown"
	}

	return result
}
