package dart

import (
	"bytes"
	"fmt"
	"sort"

	"github.com/pulumi/pulumi/pkg/v3/codegen/schema"
)

// generateResource generates a Dart class for a Pulumi resource.
func generateResource(pkg *schema.Package, resource *schema.Resource) ([]byte, error) {
	var buf bytes.Buffer

	className := tokenToQualifiedClassName(resource.Token)
	argsClassName := className + "Args"

	// File header (using regular comments to avoid dangling_library_doc_comments lint warning)
	buf.WriteString(fmt.Sprintf("// Generated resource class for %s.\n", resource.Token))
	buf.WriteString("//\n")
	if resource.Comment != "" {
		for _, line := range sanitizeCommentLines(resource.Comment) {
			buf.WriteString(fmt.Sprintf("// %s\n", line))
		}
	}
	buf.WriteString("\n")

	// Imports
	buf.WriteString("import 'package:pulumi/pulumi.dart';\n")
	buf.WriteString("import 'package:meta/meta.dart';\n")
	buf.WriteString("import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';\n")

	// Collect imports for property types
	imports := collectTypeImports(pkg, resource.InputProperties)
	imports = append(imports, collectTypeImports(pkg, resource.Properties)...)
	imports = dedupeStrings(imports)
	for _, imp := range imports {
		buf.WriteString(fmt.Sprintf("import '%s';\n", imp))
	}
	buf.WriteString("\n")

	// Determine if this is a component resource or custom resource
	isComponent := resource.IsComponent

	// Generate the resource class
	if resource.DeprecationMessage != "" {
		buf.WriteString(fmt.Sprintf("@Deprecated('%s')\n", escapeDartString(resource.DeprecationMessage)))
	}

	baseClass := "CustomResource"
	if isComponent {
		baseClass = "ComponentResource"
	}

	buf.WriteString(fmt.Sprintf("class %s extends %s {\n", className, baseClass))

	// Generate output properties
	for _, prop := range resource.Properties {
		if prop.Comment != "" {
			buf.WriteString(fmt.Sprintf("  /// %s\n", formatPropertyComment(prop.Comment)))
		}
		if prop.DeprecationMessage != "" {
			buf.WriteString(fmt.Sprintf("  @Deprecated('%s')\n", escapeDartString(prop.DeprecationMessage)))
		}
		dartType := typeToDart(prop.Type, false)
		propName := toResourcePropertyName(prop.Name)
		// For optional output properties, use nullable type
		if !prop.IsRequired() {
			buf.WriteString(fmt.Sprintf("  late final Output<%s?> %s;\n\n", dartType, propName))
		} else {
			buf.WriteString(fmt.Sprintf("  late final Output<%s> %s;\n\n", dartType, propName))
		}
	}

	// Private args field
	buf.WriteString(fmt.Sprintf("  final %s _args;\n\n", argsClassName))

	// Constructor
	buf.WriteString(fmt.Sprintf("  /// Creates a new %s resource.\n", className))
	buf.WriteString(fmt.Sprintf("  %s(\n", className))
	buf.WriteString("    String name,\n")
	buf.WriteString(fmt.Sprintf("    %s args, {\n", argsClassName))

	if isComponent {
		buf.WriteString("    ComponentResourceOptions? options,\n")
	} else {
		buf.WriteString("    CustomResourceOptions? options,\n")
	}

	buf.WriteString("  }) : _args = args,\n")
	buf.WriteString(fmt.Sprintf("       super('%s', name, options);\n\n", resource.Token))

	// Override inputs getter
	buf.WriteString("  @override\n")
	buf.WriteString("  Map<String, Input<Object?>?> get inputs => {\n")
	for _, prop := range resource.InputProperties {
		buf.WriteString(fmt.Sprintf("    '%s': _args.%s,\n", prop.Name, toResourceArgsPropertyName(prop.Name)))
	}
	buf.WriteString("  };\n\n")

	// Override processOutputs method
	buf.WriteString("  @override\n")
	buf.WriteString("  @protected\n")
	buf.WriteString("  void processOutputs(Struct properties) {\n")
	buf.WriteString("    super.processOutputs(properties);\n")
	for _, prop := range resource.Properties {
		propName := toResourcePropertyName(prop.Name)
		buf.WriteString(generateOutputPropertyDeserialization(prop, propName))
	}
	buf.WriteString("  }\n")

	buf.WriteString("}\n\n")

	// Generate the Args class
	buf.WriteString(fmt.Sprintf("/// Arguments for creating a %s resource.\n", className))
	buf.WriteString(fmt.Sprintf("class %s {\n", argsClassName))

	// Separate required and optional properties
	var requiredProps, optionalProps []*schema.Property
	for _, prop := range resource.InputProperties {
		if prop.IsRequired() {
			requiredProps = append(requiredProps, prop)
		} else {
			optionalProps = append(optionalProps, prop)
		}
	}

	// Generate property fields
	for _, prop := range resource.InputProperties {
		if prop.Comment != "" {
			buf.WriteString(fmt.Sprintf("  /// %s\n", formatPropertyComment(prop.Comment)))
		}
		if prop.DeprecationMessage != "" {
			buf.WriteString(fmt.Sprintf("  @Deprecated('%s')\n", escapeDartString(prop.DeprecationMessage)))
		}
		dartType := typeToDart(prop.Type, true)
		argsPropName := toResourceArgsPropertyName(prop.Name)
		if !prop.IsRequired() {
			buf.WriteString(fmt.Sprintf("  final Input<%s>? %s;\n\n", dartType, argsPropName))
		} else {
			buf.WriteString(fmt.Sprintf("  final Input<%s> %s;\n\n", dartType, argsPropName))
		}
	}

	// Constructor
	if len(resource.InputProperties) > 0 {
		buf.WriteString(fmt.Sprintf("  %s({\n", argsClassName))
		for _, prop := range requiredProps {
			buf.WriteString(fmt.Sprintf("    required this.%s,\n", toResourceArgsPropertyName(prop.Name)))
		}
		for _, prop := range optionalProps {
			buf.WriteString(fmt.Sprintf("    this.%s,\n", toResourceArgsPropertyName(prop.Name)))
		}
		buf.WriteString("  });\n")
	} else {
		buf.WriteString(fmt.Sprintf("  %s();\n", argsClassName))
	}

	buf.WriteString("}\n")

	return buf.Bytes(), nil
}

// collectTypeImports gathers import paths needed for property types.
func collectTypeImports(pkg *schema.Package, props []*schema.Property) []string {
	var imports []string
	seen := make(map[string]bool)

	for _, prop := range props {
		collectTypeImportsFromType(pkg, prop.Type, &imports, seen)
	}

	sort.Strings(imports)
	return imports
}

// collectTypeImportsFromType recursively collects imports from a type.
func collectTypeImportsFromType(pkg *schema.Package, t schema.Type, imports *[]string, seen map[string]bool) {
	switch tt := t.(type) {
	case *schema.ArrayType:
		collectTypeImportsFromType(pkg, tt.ElementType, imports, seen)
	case *schema.MapType:
		collectTypeImportsFromType(pkg, tt.ElementType, imports, seen)
	case *schema.ObjectType:
		if !seen[tt.Token] {
			seen[tt.Token] = true
			path := tokenToImportPath(tt.Token)
			if path != "" {
				*imports = append(*imports, path)
			}
		}
	case *schema.EnumType:
		if !seen[tt.Token] {
			seen[tt.Token] = true
			path := tokenToEnumImportPath(tt.Token)
			if path != "" {
				*imports = append(*imports, path)
			}
		}
	case *schema.UnionType:
		for _, element := range tt.ElementTypes {
			collectTypeImportsFromType(pkg, element, imports, seen)
		}
	case *schema.InputType:
		collectTypeImportsFromType(pkg, tt.ElementType, imports, seen)
	case *schema.OptionalType:
		collectTypeImportsFromType(pkg, tt.ElementType, imports, seen)
	}
}

// dedupeStrings removes duplicate strings from a slice.
func dedupeStrings(strs []string) []string {
	seen := make(map[string]bool)
	var result []string
	for _, s := range strs {
		if !seen[s] {
			seen[s] = true
			result = append(result, s)
		}
	}
	return result
}

// generateOutputPropertyDeserialization generates code to deserialize an output property
// from a protobuf Struct field.
func generateOutputPropertyDeserialization(prop *schema.Property, propName string) string {
	var buf bytes.Buffer
	isOptional := !prop.IsRequired()

	// Generate the deserialization based on the underlying type
	valueExpr := generateValueExtraction(prop.Type, prop.Name, isOptional)

	// In Dart, Output.of() doesn't take type parameters on the constructor call -
	// the type is inferred from the argument. So we just use Output.of(value).
	buf.WriteString(fmt.Sprintf("    %s = Output.of(%s);\n", propName, valueExpr))

	return buf.String()
}

// generateValueExtraction generates code to extract a value from a protobuf Value.
// If isOptional is true, the generated expression can return null.
func generateValueExtraction(t schema.Type, fieldName string, isOptional bool) string {
	switch tt := t.(type) {
	case *schema.OptionalType:
		// For optional types, always generate nullable extraction
		return generateValueExtraction(tt.ElementType, fieldName, true)

	case *schema.ArrayType:
		// For arrays, we need to handle the list value
		elemExtract := generateListElementExtraction(tt.ElementType)
		if isOptional {
			return fmt.Sprintf("properties.fields.containsKey('%s') ? properties.fields['%s']!.listValue.values.map((v) => %s).toList() : null", fieldName, fieldName, elemExtract)
		}
		return fmt.Sprintf("properties.fields['%s']?.listValue.values.map((v) => %s).toList() ?? []", fieldName, elemExtract)

	case *schema.MapType:
		// For maps, we need to handle the struct value as a map
		elemExtract := generateMapValueExtraction(tt.ElementType)
		if isOptional {
			return fmt.Sprintf("properties.fields.containsKey('%s') ? Map.fromEntries(properties.fields['%s']!.structValue.fields.entries.map((e) => MapEntry(e.key, %s))) : null", fieldName, fieldName, elemExtract)
		}
		return fmt.Sprintf("Map.fromEntries(properties.fields['%s']?.structValue.fields.entries.map((e) => MapEntry(e.key, %s)) ?? [])", fieldName, elemExtract)

	default:
		// Primitive types
		return generatePrimitiveExtraction(t, fmt.Sprintf("properties.fields['%s']", fieldName), isOptional)
	}
}

// generatePrimitiveExtraction generates code to extract a primitive value from a protobuf Value.
// If isOptional is true, the expression can return null instead of a default value.
func generatePrimitiveExtraction(t schema.Type, valueExpr string, isOptional bool) string {
	switch t {
	case schema.BoolType:
		if isOptional {
			return fmt.Sprintf("%s?.boolValue", valueExpr)
		}
		return fmt.Sprintf("%s?.boolValue ?? false", valueExpr)
	case schema.IntType:
		if isOptional {
			return fmt.Sprintf("%s?.numberValue.toInt()", valueExpr)
		}
		return fmt.Sprintf("(%s?.numberValue ?? 0).toInt()", valueExpr)
	case schema.NumberType:
		if isOptional {
			return fmt.Sprintf("%s?.numberValue", valueExpr)
		}
		return fmt.Sprintf("%s?.numberValue ?? 0.0", valueExpr)
	case schema.StringType:
		if isOptional {
			return fmt.Sprintf("%s?.stringValue", valueExpr)
		}
		return fmt.Sprintf("%s?.stringValue ?? ''", valueExpr)
	default:
		// For complex types (objects, enums), we use dynamic for now
		// The actual deserialization will depend on having proper type converters
		switch tt := t.(type) {
		case *schema.ObjectType:
			className := tokenToQualifiedTypeClassName(tt.Token)
			if isOptional {
				return fmt.Sprintf("%s != null ? %s.fromPropertyMap(PropertyDeserializer.deserializeStruct(%s!.structValue) as Map<String, dynamic>) : null", valueExpr, className, valueExpr)
			}
			return fmt.Sprintf("%s.fromPropertyMap(PropertyDeserializer.deserializeStruct(%s?.structValue ?? Struct()) as Map<String, dynamic>)", className, valueExpr)
		case *schema.EnumType:
			className := tokenToQualifiedTypeClassName(tt.Token)
			if isOptional {
				return fmt.Sprintf("%s?.stringValue != null ? %s.fromValue(%s!.stringValue) : null", valueExpr, className, valueExpr)
			}
			return fmt.Sprintf("%s.fromValue(%s?.stringValue ?? '')", className, valueExpr)
		default:
			if isOptional {
				return fmt.Sprintf("%s?.stringValue", valueExpr)
			}
			return fmt.Sprintf("%s?.stringValue ?? ''", valueExpr)
		}
	}
}

// generateListElementExtraction generates code to extract an element from a list.
func generateListElementExtraction(elemType schema.Type) string {
	switch elemType {
	case schema.BoolType:
		return "v.boolValue"
	case schema.IntType:
		return "v.numberValue.toInt()"
	case schema.NumberType:
		return "v.numberValue"
	case schema.StringType:
		return "v.stringValue"
	default:
		switch tt := elemType.(type) {
		case *schema.ObjectType:
			className := tokenToQualifiedTypeClassName(tt.Token)
			return fmt.Sprintf("%s.fromPropertyMap(PropertyDeserializer.deserializeStruct(v.structValue) as Map<String, dynamic>)", className)
		default:
			return "v.stringValue"
		}
	}
}

// generateMapValueExtraction generates code to extract a value from a map entry.
func generateMapValueExtraction(elemType schema.Type) string {
	switch elemType {
	case schema.BoolType:
		return "e.value.boolValue"
	case schema.IntType:
		return "e.value.numberValue.toInt()"
	case schema.NumberType:
		return "e.value.numberValue"
	case schema.StringType:
		return "e.value.stringValue"
	default:
		switch tt := elemType.(type) {
		case *schema.ObjectType:
			className := tokenToQualifiedTypeClassName(tt.Token)
			return fmt.Sprintf("%s.fromPropertyMap(PropertyDeserializer.deserializeStruct(e.value.structValue) as Map<String, dynamic>)", className)
		default:
			return "e.value.stringValue"
		}
	}
}
