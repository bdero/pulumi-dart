package dart

import (
	"crypto/sha256"
	"encoding/hex"
	"regexp"
	"strings"
	"unicode"

	"github.com/pulumi/pulumi/pkg/v3/codegen/schema"
)

// maxFilenameLength is the maximum length for generated filenames.
// This is needed because Windows has a 260 character path limit, and some
// providers (like GCP) have very long type names that can exceed this limit.
// We use 100 characters as a safe maximum for the filename part (excluding
// extension and directory path).
const maxFilenameLength = 100

// resourceReservedNames contains property names that conflict with Resource base class members.
// These names get suffixed with "Value" when used as property names.
var resourceReservedNames = map[string]bool{
	"inputs":           true, // conflicts with Resource.inputs getter
	"processOutputs":   true, // conflicts with Resource.processOutputs method
	"urn":              true, // conflicts with Resource.urn property
	"registered":       true, // conflicts with Resource.registered future
	"hashCode":         true, // conflicts with Object.hashCode
	"runtimeType":      true, // conflicts with Object.runtimeType
	"toString":         true, // conflicts with Object.toString()
	"noSuchMethod":     true, // conflicts with Object.noSuchMethod
	"name":             true, // conflicts with constructor parameter
	"type":             true, // conflicts with Resource.type getter
	"options":          true, // conflicts with Resource.options getter
	"id":               true, // conflicts with CustomResource.id property
	"override":         true, // conflicts with @override annotation visibility
	"properties":       true, // conflicts with processOutputs parameter
}

// objectReservedNames contains property names that conflict with Object base class members.
// These names get suffixed with "Value" when used as property names in any class.
var objectReservedNames = map[string]bool{
	"hashCode":    true, // conflicts with Object.hashCode
	"runtimeType": true, // conflicts with Object.runtimeType
	"toString":    true, // conflicts with Object.toString()
	"noSuchMethod": true, // conflicts with Object.noSuchMethod
}

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
// If the string has no separators and already starts with a lowercase letter,
// it is assumed to be already in camelCase and is returned as-is (preserving
// the casing of subsequent characters).
func toCamelCase(s string) string {
	// Split on common separators
	parts := regexp.MustCompile(`[-_\s]+`).Split(s, -1)
	if len(parts) == 0 {
		return ""
	}

	// If there's only one part and it already starts with lowercase,
	// assume it's already camelCase and preserve it
	if len(parts) == 1 && len(s) > 0 && unicode.IsLower(rune(s[0])) {
		name := s
		// Handle reserved words
		if dartReservedWords[name] {
			return name + "_"
		}
		return name
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
// If the string has no separators, it simply capitalizes the first letter
// and preserves the rest of the casing (handles both camelCase and PascalCase input).
func toPascalCase(s string) string {
	if len(s) == 0 {
		return ""
	}

	// Split on common separators
	parts := regexp.MustCompile(`[-_\s]+`).Split(s, -1)
	if len(parts) == 0 {
		return ""
	}

	// If there's only one part with no separators, just capitalize the first letter
	// This handles both "getAvailabilityZones" -> "GetAvailabilityZones"
	// and "MyClass" -> "MyClass"
	if len(parts) == 1 {
		return strings.ToUpper(string(s[0])) + s[1:]
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
// This returns just the type name without module prefix, suitable for resources
// and functions which are less likely to have name collisions.
func tokenToClassName(token string) string {
	parts := strings.Split(token, ":")
	if len(parts) < 3 {
		return toPascalCase(token)
	}
	// The last part is the name
	name := parts[len(parts)-1]
	return toPascalCase(name)
}

// tokenToQualifiedClassName extracts a qualified class name from a Pulumi token.
// Tokens are in the format "pkg:module:Name" or "pkg:module/submodule:Name".
// This includes the module name as a prefix to avoid collisions when the same
// type name exists in different modules (e.g., "bigquery:AppProfile" and
// "bigtable:AppProfile" become "BigqueryAppProfile" and "BigtableAppProfile").
func tokenToQualifiedClassName(token string) string {
	parts := strings.Split(token, ":")
	if len(parts) < 3 {
		return toPascalCase(token)
	}

	// Get the module part (second element) and the name (last element)
	module := parts[1]
	name := parts[len(parts)-1]

	// Handle submodules (e.g., "s3/bucket" -> "s3Bucket")
	// We take only the first part of the module path to keep names shorter
	if idx := strings.Index(module, "/"); idx != -1 {
		module = module[:idx]
	}

	// Combine module and name: "bigquery" + "AppProfile" -> "BigqueryAppProfile"
	return toPascalCase(module) + toPascalCase(name)
}

// isTypeToken returns true if the token represents a type (as opposed to a resource).
// Types have PascalCase in the submodule path (e.g., "gcp:bigquery/DatasetAccess:DatasetAccess")
// while resources have camelCase (e.g., "gcp:bigquery/datasetAccess:DatasetAccess").
func isTypeToken(token string) bool {
	parts := strings.Split(token, ":")
	if len(parts) < 3 {
		return false
	}
	module := parts[1]
	// Check if there's a submodule path
	if idx := strings.Index(module, "/"); idx != -1 {
		submodule := module[idx+1:]
		// If the submodule starts with an uppercase letter, it's a type
		if len(submodule) > 0 && submodule[0] >= 'A' && submodule[0] <= 'Z' {
			return true
		}
	}
	return false
}

// tokenToQualifiedTypeClassName is like tokenToQualifiedClassName but may append
// a suffix to avoid collisions between types and resources with the same name.
// When a type's token indicates it could collide with a resource (both have the
// same module and name), this function ensures uniqueness.
func tokenToQualifiedTypeClassName(token string) string {
	baseName := tokenToQualifiedClassName(token)
	// Types that could collide with resources get a "Type" suffix
	// A type token has PascalCase in the submodule path, indicating it's a
	// standalone type that might share a name with a resource
	if isTypeToken(token) {
		return baseName + "Type"
	}
	// Types whose name ends with "Result" would collide with function result
	// classes (which are named FunctionNameResult), so add "Type" suffix
	if strings.HasSuffix(baseName, "Result") {
		return baseName + "Type"
	}
	return baseName
}

// tokenToFunctionName extracts a qualified function name from a Pulumi token.
// Similar to tokenToQualifiedClassName, this includes the module name as a prefix
// to avoid collisions when the same function name exists in different modules
// (e.g., "alloydb:getInstance" and "compute:getInstance" become
// "alloydbGetInstance" and "computeGetInstance").
func tokenToFunctionName(token string) string {
	parts := strings.Split(token, ":")
	if len(parts) < 3 {
		return makeValidIdentifier(toCamelCase(token))
	}

	// Get the module part (second element) and the name (last element)
	module := parts[1]
	name := parts[len(parts)-1]

	// Handle submodules (e.g., "s3/bucket" -> just "s3")
	// We take only the first part of the module path to keep names shorter
	if idx := strings.Index(module, "/"); idx != -1 {
		module = module[:idx]
	}

	// If the name contains a slash, take only the part after the slash
	if idx := strings.LastIndex(name, "/"); idx != -1 {
		name = name[idx+1:]
	}

	// Combine module and name: "alloydb" + "getInstance" -> "alloydbGetInstance"
	return makeValidIdentifier(toCamelCase(module) + toPascalCase(name))
}

// tokenToModulePath extracts a module path from a Pulumi token.
// If the resulting path exceeds maxFilenameLength, it is truncated and
// a hash suffix is appended to ensure uniqueness.
func tokenToModulePath(token string) string {
	parts := strings.Split(token, ":")
	if len(parts) < 3 {
		return truncateFilename(ToSnakeCase(token))
	}

	// Get the module part (second element) and the name (last element)
	module := parts[1]
	name := parts[len(parts)-1]

	// Handle submodules (e.g., "s3/bucket" -> "s3_bucket")
	module = strings.ReplaceAll(module, "/", "_")

	// Convert each part to snake_case separately, then join
	result := ToSnakeCase(module) + "_" + ToSnakeCase(name)

	return truncateFilename(result)
}

// truncateFilename truncates a filename to maxFilenameLength characters.
// If truncation is needed, it appends a hash suffix to ensure uniqueness.
func truncateFilename(name string) string {
	if len(name) <= maxFilenameLength {
		return name
	}

	// Generate a short hash of the original name for uniqueness
	hash := sha256.Sum256([]byte(name))
	hashSuffix := "_" + hex.EncodeToString(hash[:])[:8]

	// Truncate the name to fit the hash suffix within maxFilenameLength
	truncateAt := maxFilenameLength - len(hashSuffix)
	if truncateAt < 0 {
		truncateAt = 0
	}

	return name[:truncateAt] + hashSuffix
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
		return tokenToQualifiedTypeClassName(tt.Token)

	case *schema.EnumType:
		return tokenToQualifiedTypeClassName(tt.Token)

	case *schema.TokenType:
		if tt.UnderlyingType != nil {
			return typeToDart(tt.UnderlyingType, unwrapInputs)
		}
		return tokenToClassName(tt.Token)

	case *schema.UnionType:
		// For union types, we have several strategies:
		// 1. If it's a two-element union where one is Optional, return the non-optional type
		// 2. Otherwise, return Object as Dart doesn't have native union support
		// Note: In the future, we could generate a sealed class for complex unions
		if len(tt.ElementTypes) == 2 {
			// Check if exactly one is an optional type
			var nonOptionalType schema.Type
			var hasOptional bool
			for _, elem := range tt.ElementTypes {
				if _, isOptional := elem.(*schema.OptionalType); isOptional {
					hasOptional = true
				} else {
					nonOptionalType = elem
				}
			}
			// Only return the non-optional type if one element was optional
			if hasOptional && nonOptionalType != nil {
				return typeToDart(nonOptionalType, unwrapInputs)
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
			// TODO: Implement Archive type in Dart SDK
			return "Object"
		case schema.AssetType:
			// TODO: Implement Asset type in Dart SDK
			return "Object"
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

// toResourcePropertyName converts a property name to a valid Dart identifier
// that doesn't conflict with Resource base class members.
func toResourcePropertyName(name string) string {
	camelName := toCamelCase(name)
	if resourceReservedNames[camelName] {
		return camelName + "Value"
	}
	return camelName
}

// toResourceArgsPropertyName converts a property name to a valid Dart identifier
// for use in Args classes (which don't inherit from Resource, so have fewer conflicts).
func toResourceArgsPropertyName(name string) string {
	camelName := toCamelCase(name)
	if objectReservedNames[camelName] {
		return camelName + "Value"
	}
	return camelName
}
