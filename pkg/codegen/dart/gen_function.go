package dart

import (
	"bytes"
	"fmt"
	"strings"

	"github.com/pulumi/pulumi/pkg/v3/codegen/schema"
)

// generateFunction generates a Dart function for a Pulumi function invocation.
func generateFunction(pkg *schema.Package, function *schema.Function) ([]byte, error) {
	var buf bytes.Buffer

	funcName := tokenToFunctionName(function.Token)
	argsClassName := toPascalCase(funcName) + "Args"
	resultClassName := toPascalCase(funcName) + "Result"

	// File header
	buf.WriteString(fmt.Sprintf("/// Generated function for %s.\n", function.Token))
	buf.WriteString("///\n")
	if function.Comment != "" {
		for _, line := range strings.Split(function.Comment, "\n") {
			buf.WriteString(fmt.Sprintf("/// %s\n", line))
		}
	}
	buf.WriteString("\n")

	// Imports
	buf.WriteString("import 'package:pulumi/pulumi.dart';\n")

	// Collect imports for property types
	var allProps []*schema.Property
	if function.Inputs != nil {
		allProps = append(allProps, function.Inputs.Properties...)
	}
	if function.ReturnType != nil {
		if objectType, ok := function.ReturnType.(*schema.ObjectType); ok {
			allProps = append(allProps, objectType.Properties...)
		}
	}
	imports := collectObjectTypeImports(pkg, allProps)
	for _, imp := range imports {
		buf.WriteString(fmt.Sprintf("import '%s';\n", imp))
	}
	buf.WriteString("\n")

	// Generate the async function
	if function.DeprecationMessage != "" {
		buf.WriteString(fmt.Sprintf("@Deprecated('%s')\n", escapeDartString(function.DeprecationMessage)))
	}

	// Determine return type
	hasOutputs := function.ReturnType != nil

	if function.Comment != "" {
		for _, line := range strings.Split(function.Comment, "\n") {
			buf.WriteString(fmt.Sprintf("/// %s\n", line))
		}
	}
	if hasOutputs {
		buf.WriteString(fmt.Sprintf("Future<%s> %s({\n", resultClassName, funcName))
	} else {
		buf.WriteString(fmt.Sprintf("Future<void> %s({\n", funcName))
	}

	// Function parameters - simplified inline parameters for common cases
	if function.Inputs != nil {
		for _, prop := range function.Inputs.Properties {
			dartType := typeToDart(prop.Type, true)
			if prop.IsRequired() {
				buf.WriteString(fmt.Sprintf("  required %s %s,\n", dartType, toCamelCase(prop.Name)))
			} else {
				buf.WriteString(fmt.Sprintf("  %s? %s,\n", dartType, toCamelCase(prop.Name)))
			}
		}
	}
	buf.WriteString("  InvokeOptions? options,\n")
	buf.WriteString("}) async {\n")

	// Build args map
	// Note: invokeAsync accepts Map<String, Input<Object?>?> but the values here
	// are plain Dart types wrapped with Input.value()
	buf.WriteString("  final args = <String, Input<Object?>?>{\n")
	if function.Inputs != nil {
		for _, prop := range function.Inputs.Properties {
			propName := toCamelCase(prop.Name)
			if prop.IsRequired() {
				buf.WriteString(fmt.Sprintf("    '%s': Input.value(%s),\n", prop.Name, propName))
			} else {
				buf.WriteString(fmt.Sprintf("    if (%s != null) '%s': Input.value(%s),\n", propName, prop.Name, propName))
			}
		}
	}
	buf.WriteString("  };\n\n")

	// Call the invokeAsync function (returns Future<Map<String, dynamic>>)
	buf.WriteString(fmt.Sprintf("  final result = await invokeAsync('%s', args, options);\n", function.Token))

	if hasOutputs {
		buf.WriteString(fmt.Sprintf("  return %s.fromPropertyMap(result);\n", resultClassName))
	}

	buf.WriteString("}\n\n")

	// Generate Args class if there are inputs
	if function.Inputs != nil && len(function.Inputs.Properties) > 0 {
		argsClass, err := generateFunctionArgs(function, argsClassName)
		if err != nil {
			return nil, err
		}
		buf.Write(argsClass)
		buf.WriteString("\n")
	}

	// Generate Result class if there are outputs
	if hasOutputs {
		resultClass, err := generateFunctionResult(function, resultClassName)
		if err != nil {
			return nil, err
		}
		buf.Write(resultClass)
	}

	return buf.Bytes(), nil
}

// generateFunctionArgs generates an Args class for function inputs.
func generateFunctionArgs(function *schema.Function, className string) ([]byte, error) {
	var buf bytes.Buffer

	buf.WriteString(fmt.Sprintf("/// Arguments for the %s function.\n", tokenToFunctionName(function.Token)))
	buf.WriteString(fmt.Sprintf("class %s {\n", className))

	if function.Inputs != nil {
		// Separate required and optional properties
		var requiredProps, optionalProps []*schema.Property
		for _, prop := range function.Inputs.Properties {
			if prop.IsRequired() {
				requiredProps = append(requiredProps, prop)
			} else {
				optionalProps = append(optionalProps, prop)
			}
		}

		// Generate property fields
		for _, prop := range function.Inputs.Properties {
			if prop.Comment != "" {
				buf.WriteString(fmt.Sprintf("  /// %s\n", strings.ReplaceAll(prop.Comment, "\n", "\n  /// ")))
			}
			dartType := typeToDart(prop.Type, true)
			if !prop.IsRequired() {
				buf.WriteString(fmt.Sprintf("  final %s? %s;\n\n", dartType, toCamelCase(prop.Name)))
			} else {
				buf.WriteString(fmt.Sprintf("  final %s %s;\n\n", dartType, toCamelCase(prop.Name)))
			}
		}

		// Constructor
		buf.WriteString(fmt.Sprintf("  %s({\n", className))
		for _, prop := range requiredProps {
			buf.WriteString(fmt.Sprintf("    required this.%s,\n", toCamelCase(prop.Name)))
		}
		for _, prop := range optionalProps {
			buf.WriteString(fmt.Sprintf("    this.%s,\n", toCamelCase(prop.Name)))
		}
		buf.WriteString("  });\n\n")

		// toPropertyMap method
		buf.WriteString("  /// Converts this object to a property map.\n")
		buf.WriteString("  Map<String, dynamic> toPropertyMap() {\n")
		buf.WriteString("    return {\n")
		for _, prop := range function.Inputs.Properties {
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
	} else {
		buf.WriteString(fmt.Sprintf("  %s();\n", className))
	}

	buf.WriteString("}\n")

	return buf.Bytes(), nil
}

// generateFunctionResult generates a Result class for function outputs.
func generateFunctionResult(function *schema.Function, className string) ([]byte, error) {
	var buf bytes.Buffer

	buf.WriteString(fmt.Sprintf("/// Result of the %s function.\n", tokenToFunctionName(function.Token)))
	buf.WriteString(fmt.Sprintf("class %s {\n", className))

	// Get output properties
	var props []*schema.Property
	if function.ReturnType != nil {
		if objectType, ok := function.ReturnType.(*schema.ObjectType); ok {
			props = objectType.Properties
		}
	}

	if len(props) > 0 {
		// Separate required and optional properties
		var requiredProps, optionalProps []*schema.Property
		for _, prop := range props {
			if prop.IsRequired() {
				requiredProps = append(requiredProps, prop)
			} else {
				optionalProps = append(optionalProps, prop)
			}
		}

		// Generate property fields
		for _, prop := range props {
			if prop.Comment != "" {
				buf.WriteString(fmt.Sprintf("  /// %s\n", strings.ReplaceAll(prop.Comment, "\n", "\n  /// ")))
			}
			dartType := typeToDart(prop.Type, true)
			if !prop.IsRequired() {
				buf.WriteString(fmt.Sprintf("  final %s? %s;\n\n", dartType, toCamelCase(prop.Name)))
			} else {
				buf.WriteString(fmt.Sprintf("  final %s %s;\n\n", dartType, toCamelCase(prop.Name)))
			}
		}

		// Constructor
		buf.WriteString(fmt.Sprintf("  %s({\n", className))
		for _, prop := range requiredProps {
			buf.WriteString(fmt.Sprintf("    required this.%s,\n", toCamelCase(prop.Name)))
		}
		for _, prop := range optionalProps {
			buf.WriteString(fmt.Sprintf("    this.%s,\n", toCamelCase(prop.Name)))
		}
		buf.WriteString("  });\n\n")

		// fromPropertyMap factory
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
		buf.WriteString("  }\n")
	} else {
		buf.WriteString(fmt.Sprintf("  %s();\n", className))
	}

	buf.WriteString("}\n")

	return buf.Bytes(), nil
}
