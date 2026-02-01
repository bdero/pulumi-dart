package dart

import (
	"regexp"
	"strings"
	"unicode"

	"github.com/pulumi/pulumi/pkg/v3/codegen/schema"
)

// Dart reserved keywords that need escaping.
var dartReservedWords = map[string]bool{
	"abstract":   true,
	"as":         true,
	"assert":     true,
	"async":      true,
	"await":      true,
	"base":       true,
	"break":      true,
	"case":       true,
	"catch":      true,
	"class":      true,
	"const":      true,
	"continue":   true,
	"covariant":  true,
	"default":    true,
	"deferred":   true,
	"do":         true,
	"dynamic":    true,
	"else":       true,
	"enum":       true,
	"export":     true,
	"extends":    true,
	"extension":  true,
	"external":   true,
	"factory":    true,
	"false":      true,
	"final":      true,
	"finally":    true,
	"for":        true,
	"Function":   true,
	"get":        true,
	"hide":       true,
	"if":         true,
	"implements": true,
	"import":     true,
	"in":         true,
	"interface":  true,
	"is":         true,
	"late":       true,
	"library":    true,
	"mixin":      true,
	"new":        true,
	"null":       true,
	"of":         true,
	"on":         true,
	"operator":   true,
	"part":       true,
	"required":   true,
	"rethrow":    true,
	"return":     true,
	"sealed":     true,
	"set":        true,
	"show":       true,
	"static":     true,
	"super":      true,
	"switch":     true,
	"sync":       true,
	"this":       true,
	"throw":      true,
	"true":       true,
	"try":        true,
	"typedef":    true,
	"var":        true,
	"void":       true,
	"when":       true,
	"while":      true,
	"with":       true,
	"yield":      true,
}

// ToSnakeCase converts a string to snake_case.
func ToSnakeCase(s string) string {
	var result strings.Builder
	for i, r := range s {
		if unicode.IsUpper(r) {
			if i > 0 {
				result.WriteRune('_')
			}
			result.WriteRune(unicode.ToLower(r))
		} else if r == '-' || r == ' ' {
			result.WriteRune('_')
		} else {
			result.WriteRune(r)
		}
	}
	return result.String()
}

// toCamelCase converts a string to camelCase.
func toCamelCase(s string) string {
	// Split on common separators
	parts := regexp.MustCompile(`[-_\s]+`).Split(s, -1)
	if len(parts) == 0 {
		return ""
	}

	var result strings.Builder

	for i, part := range parts {
		if part == "" {
			continue
		}

		if i == 0 {
			// First word is lowercase
			result.WriteString(strings.ToLower(part))
		} else {
			// Subsequent words are title case
			result.WriteString(strings.Title(strings.ToLower(part)))
		}
	}

	name := result.String()

	// Handle reserved words
	if dartReservedWords[name] {
		return name + "_"
	}

	return name
}

// toPascalCase converts a string to PascalCase.
func toPascalCase(s string) string {
	// Split on common separators
	parts := regexp.MustCompile(`[-_\s]+`).Split(s, -1)
	if len(parts) == 0 {
		return ""
	}

	var result strings.Builder

	for _, part := range parts {
		if part == "" {
			continue
		}
		result.WriteString(strings.Title(strings.ToLower(part)))
	}

	return result.String()
}

// tokenToClassName extracts the class name from a Pulumi token.
// Tokens are in the format "pkg:module:Name" or "pkg:module/submodule:Name".
func tokenToClassName(token string) string {
	parts := strings.Split(token, ":")
	if len(parts) < 3 {
		return toPascalCase(token)
	}
	// The last part is the name
	name := parts[len(parts)-1]
	return toPascalCase(name)
}

// tokenToFunctionName extracts a function name from a Pulumi token.
func tokenToFunctionName(token string) string {
	parts := strings.Split(token, ":")
	if len(parts) < 3 {
		return toCamelCase(token)
	}
	// The last part is the name
	name := parts[len(parts)-1]
	return toCamelCase(name)
}

// tokenToModulePath extracts a module path from a Pulumi token.
func tokenToModulePath(token string) string {
	parts := strings.Split(token, ":")
	if len(parts) < 3 {
		return ToSnakeCase(token)
	}

	// Get the module part (second element) and the name (last element)
	module := parts[1]
	name := parts[len(parts)-1]

	// Handle submodules (e.g., "s3/bucket" -> "s3_bucket")
	module = strings.ReplaceAll(module, "/", "_")

	// Convert each part to snake_case separately, then join
	return ToSnakeCase(module) + "_" + ToSnakeCase(name)
}

// tokenToImportPath generates an import path for a type token.
func tokenToImportPath(token string) string {
	modulePath := tokenToModulePath(token)
	if modulePath == "" {
		return ""
	}
	return "../types/" + modulePath + ".dart"
}

// tokenToEnumImportPath generates an import path for an enum token.
func tokenToEnumImportPath(token string) string {
	modulePath := tokenToModulePath(token)
	if modulePath == "" {
		return ""
	}
	return "../enums/" + modulePath + ".dart"
}

// typeToDart converts a Pulumi schema type to a Dart type string.
func typeToDart(t schema.Type, unwrapInputs bool) string {
	switch tt := t.(type) {
	case *schema.ArrayType:
		elementType := typeToDart(tt.ElementType, unwrapInputs)
		return "List<" + elementType + ">"

	case *schema.MapType:
		elementType := typeToDart(tt.ElementType, unwrapInputs)
		return "Map<String, " + elementType + ">"

	case *schema.ObjectType:
		return tokenToClassName(tt.Token)

	case *schema.EnumType:
		return tokenToClassName(tt.Token)

	case *schema.TokenType:
		if tt.UnderlyingType != nil {
			return typeToDart(tt.UnderlyingType, unwrapInputs)
		}
		return tokenToClassName(tt.Token)

	case *schema.UnionType:
		// For union types, use Object as Dart doesn't have native union support
		// In the future, we could generate a sealed class for this
		if len(tt.ElementTypes) == 2 {
			// Check if one is an optional type for optional handling
			for _, elem := range tt.ElementTypes {
				if _, isOptional := elem.(*schema.OptionalType); isOptional {
					continue
				}
				// Return the non-optional type
				return typeToDart(elem, unwrapInputs)
			}
		}
		return "Object"

	case *schema.InputType:
		if unwrapInputs {
			return typeToDart(tt.ElementType, unwrapInputs)
		}
		return "Input<" + typeToDart(tt.ElementType, true) + ">"

	case *schema.OptionalType:
		return typeToDart(tt.ElementType, unwrapInputs)

	case *schema.ResourceType:
		return tokenToClassName(tt.Token)

	default:
		// Primitive types
		switch t {
		case schema.BoolType:
			return "bool"
		case schema.IntType:
			return "int"
		case schema.NumberType:
			return "double"
		case schema.StringType:
			return "String"
		case schema.ArchiveType:
			return "Archive"
		case schema.AssetType:
			return "Asset"
		case schema.JSONType:
			return "Object"
		case schema.AnyType:
			return "Object"
		default:
			return "Object"
		}
	}
}

// escapeDartString escapes a string for use in Dart source code.
func escapeDartString(s string) string {
	s = strings.ReplaceAll(s, "\\", "\\\\")
	s = strings.ReplaceAll(s, "'", "\\'")
	s = strings.ReplaceAll(s, "\n", "\\n")
	s = strings.ReplaceAll(s, "\r", "\\r")
	s = strings.ReplaceAll(s, "\t", "\\t")
	s = strings.ReplaceAll(s, "$", "\\$")
	return s
}

// makeValidIdentifier ensures a string is a valid Dart identifier.
func makeValidIdentifier(s string) string {
	if s == "" {
		return "_"
	}

	// Replace invalid characters
	s = regexp.MustCompile(`[^a-zA-Z0-9_]`).ReplaceAllString(s, "_")

	// Ensure it doesn't start with a digit
	if len(s) > 0 && s[0] >= '0' && s[0] <= '9' {
		s = "_" + s
	}

	// Handle reserved words
	if dartReservedWords[s] {
		s = s + "_"
	}

	return s
}
