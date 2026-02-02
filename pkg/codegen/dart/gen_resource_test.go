package dart

import (
	"strings"
	"testing"

	"github.com/pulumi/pulumi/pkg/v3/codegen/schema"
)

func TestGenerateResource(t *testing.T) {
	pkg := &schema.Package{
		Name: "test",
	}

	t.Run("simple custom resource", func(t *testing.T) {
		resource := &schema.Resource{
			Token:       "test:index:MyResource",
			Comment:     "A test resource for demonstration.",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "name", Type: schema.StringType, Comment: "The resource name."},
				{Name: "count", Type: schema.IntType},
			},
			Properties: []*schema.Property{
				{Name: "id", Type: schema.StringType},
				{Name: "arn", Type: schema.StringType, Comment: "The ARN of the resource."},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Check imports
		if !strings.Contains(result, "import 'package:pulumi/pulumi.dart';") {
			t.Error("Expected pulumi import not found")
		}
		if !strings.Contains(result, "import 'package:meta/meta.dart';") {
			t.Error("Expected meta import not found")
		}
		if !strings.Contains(result, "import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';") {
			t.Error("Expected protobuf struct import not found")
		}

		// Check class declaration - extends CustomResource
		if !strings.Contains(result, "class MyResource extends CustomResource {") {
			t.Error("Expected CustomResource class declaration not found")
		}

		// Check output properties with late final Output<T>
		if !strings.Contains(result, "late final Output<String> id;") {
			t.Error("Expected id output property not found")
		}
		if !strings.Contains(result, "late final Output<String> arn;") {
			t.Error("Expected arn output property not found")
		}

		// Check _args field
		if !strings.Contains(result, "final MyResourceArgs _args;") {
			t.Error("Expected _args field not found")
		}

		// Check constructor
		if !strings.Contains(result, "MyResource(") {
			t.Error("Expected constructor not found")
		}
		if !strings.Contains(result, "String name,") {
			t.Error("Expected name parameter in constructor not found")
		}
		if !strings.Contains(result, "MyResourceArgs args,") {
			t.Error("Expected args parameter in constructor not found")
		}
		if !strings.Contains(result, "CustomResourceOptions? options,") {
			t.Error("Expected options parameter in constructor not found")
		}
		if !strings.Contains(result, "super('test:index:MyResource', name, options)") {
			t.Error("Expected super call with token not found")
		}

		// Check inputs getter with correct type
		if !strings.Contains(result, "Map<String, Input<Object?>?> get inputs =>") {
			t.Error("Expected inputs getter with correct type not found")
		}
		if !strings.Contains(result, "'name': _args.name,") {
			t.Error("Expected name input not found")
		}
		if !strings.Contains(result, "'count': _args.count,") {
			t.Error("Expected count input not found")
		}

		// Check processOutputs with Struct parameter
		if !strings.Contains(result, "void processOutputs(Struct properties) {") {
			t.Error("Expected processOutputs with Struct parameter not found")
		}
		if !strings.Contains(result, "super.processOutputs(properties);") {
			t.Error("Expected super.processOutputs call not found")
		}

		// Check documentation
		if !strings.Contains(result, "/// A test resource for demonstration.") {
			t.Error("Expected resource documentation not found")
		}
		if !strings.Contains(result, "/// The resource name.") {
			t.Error("Expected property documentation not found")
		}
		if !strings.Contains(result, "/// The ARN of the resource.") {
			t.Error("Expected output property documentation not found")
		}
	})

	t.Run("component resource", func(t *testing.T) {
		resource := &schema.Resource{
			Token:       "test:index:MyComponent",
			IsComponent: true,
			InputProperties: []*schema.Property{
				{Name: "config", Type: schema.StringType},
			},
			Properties: []*schema.Property{
				{Name: "endpoint", Type: schema.StringType},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Check extends ComponentResource
		if !strings.Contains(result, "class MyComponent extends ComponentResource {") {
			t.Error("Expected ComponentResource class declaration not found")
		}

		// Check ComponentResourceOptions
		if !strings.Contains(result, "ComponentResourceOptions? options,") {
			t.Error("Expected ComponentResourceOptions parameter not found")
		}
	})

	t.Run("resource with optional properties", func(t *testing.T) {
		resource := &schema.Resource{
			Token:       "test:index:OptionalResource",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "required_field", Type: schema.StringType},
				{Name: "optional_field", Type: &schema.OptionalType{ElementType: schema.StringType}},
			},
			Properties: []*schema.Property{
				{Name: "output_field", Type: schema.StringType},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Check Args class with required and optional
		if !strings.Contains(result, "final Input<String> requiredField;") {
			t.Error("Expected required Input field not found")
		}
		if !strings.Contains(result, "final Input<String>? optionalField;") {
			t.Error("Expected optional Input field not found")
		}

		// Check constructor with required/optional
		if !strings.Contains(result, "required this.requiredField,") {
			t.Error("Expected required constructor parameter not found")
		}
		if !strings.Contains(result, "this.optionalField,") {
			t.Error("Expected optional constructor parameter not found")
		}
	})

	t.Run("resource with array and map properties", func(t *testing.T) {
		resource := &schema.Resource{
			Token:       "test:index:ComplexResource",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "tags", Type: &schema.MapType{ElementType: schema.StringType}},
				{Name: "items", Type: &schema.ArrayType{ElementType: schema.IntType}},
			},
			Properties: []*schema.Property{
				{Name: "output_tags", Type: &schema.MapType{ElementType: schema.StringType}},
				{Name: "output_items", Type: &schema.ArrayType{ElementType: schema.IntType}},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Check Input types for complex properties
		if !strings.Contains(result, "final Input<Map<String, String>> tags;") {
			t.Error("Expected Input<Map<String, String>> property not found")
		}
		if !strings.Contains(result, "final Input<List<int>> items;") {
			t.Error("Expected Input<List<int>> property not found")
		}

		// Check Output types for complex output properties
		if !strings.Contains(result, "late final Output<Map<String, String>> outputTags;") {
			t.Error("Expected Output<Map<String, String>> output property not found")
		}
		if !strings.Contains(result, "late final Output<List<int>> outputItems;") {
			t.Error("Expected Output<List<int>> output property not found")
		}
	})

	t.Run("resource with deprecated properties", func(t *testing.T) {
		resource := &schema.Resource{
			Token:              "test:index:DeprecatedResource",
			DeprecationMessage: "Use NewResource instead.",
			IsComponent:        false,
			InputProperties: []*schema.Property{
				{
					Name:               "old_field",
					Type:               schema.StringType,
					DeprecationMessage: "Use new_field instead.",
				},
			},
			Properties: []*schema.Property{
				{Name: "output", Type: schema.StringType},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Check class deprecation
		if !strings.Contains(result, "@Deprecated('Use NewResource instead.')") {
			t.Error("Expected class @Deprecated annotation not found")
		}

		// Check property deprecation
		if !strings.Contains(result, "@Deprecated('Use new_field instead.')") {
			t.Error("Expected property @Deprecated annotation not found")
		}
	})

	t.Run("resource with nested object types", func(t *testing.T) {
		nestedType := &schema.ObjectType{
			Token: "test:index:NestedType",
		}

		resource := &schema.Resource{
			Token:       "test:index:NestedResource",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "config", Type: nestedType},
			},
			Properties: []*schema.Property{
				{Name: "result", Type: nestedType},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Check import for nested type
		if !strings.Contains(result, "import '../types/index_nested_type.dart';") {
			t.Error("Expected import for nested type not found")
		}

		// Check Input<IndexNestedType> for input property
		if !strings.Contains(result, "final Input<IndexNestedType> config;") {
			t.Error("Expected Input<IndexNestedType> property not found")
		}

		// Check Output<IndexNestedType> for output property
		if !strings.Contains(result, "late final Output<IndexNestedType> result;") {
			t.Error("Expected Output<IndexNestedType> output property not found")
		}
	})

	t.Run("resource with enum types", func(t *testing.T) {
		enumType := &schema.EnumType{
			Token:       "test:index:MyEnum",
			ElementType: schema.StringType,
		}

		resource := &schema.Resource{
			Token:       "test:index:EnumResource",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "status", Type: enumType},
			},
			Properties: []*schema.Property{
				{Name: "current_status", Type: enumType},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Check import for enum type
		if !strings.Contains(result, "import '../enums/index_my_enum.dart';") {
			t.Error("Expected import for enum type not found")
		}

		// Check Input<IndexMyEnum> for input property
		if !strings.Contains(result, "final Input<IndexMyEnum> status;") {
			t.Error("Expected Input<IndexMyEnum> property not found")
		}

		// Check Output<IndexMyEnum> for output property
		if !strings.Contains(result, "late final Output<IndexMyEnum> currentStatus;") {
			t.Error("Expected Output<IndexMyEnum> output property not found")
		}
	})
}

func TestGenerateResourceArgsClass(t *testing.T) {
	pkg := &schema.Package{
		Name: "test",
	}

	t.Run("args class with mixed properties", func(t *testing.T) {
		resource := &schema.Resource{
			Token:       "test:index:TestResource",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "name", Type: schema.StringType, Comment: "The name."},
				{Name: "count", Type: schema.IntType},
				{Name: "enabled", Type: &schema.OptionalType{ElementType: schema.BoolType}},
				{Name: "tags", Type: &schema.OptionalType{ElementType: &schema.MapType{ElementType: schema.StringType}}},
			},
			Properties: []*schema.Property{
				{Name: "id", Type: schema.StringType},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Check Args class declaration
		if !strings.Contains(result, "class TestResourceArgs {") {
			t.Error("Expected Args class declaration not found")
		}

		// Check required properties (no ?)
		if !strings.Contains(result, "final Input<String> name;") {
			t.Error("Expected required Input<String> property not found")
		}
		if !strings.Contains(result, "final Input<int> count;") {
			t.Error("Expected required Input<int> property not found")
		}

		// Check optional properties (with ?)
		if !strings.Contains(result, "final Input<bool>? enabled;") {
			t.Error("Expected optional Input<bool>? property not found")
		}
		if !strings.Contains(result, "final Input<Map<String, String>>? tags;") {
			t.Error("Expected optional Input<Map<String, String>>? property not found")
		}

		// Check constructor ordering (required first, then optional)
		if !strings.Contains(result, "required this.name,") {
			t.Error("Expected required this.name not found")
		}
		if !strings.Contains(result, "required this.count,") {
			t.Error("Expected required this.count not found")
		}
		if !strings.Contains(result, "this.enabled,") {
			t.Error("Expected optional this.enabled not found")
		}
		if !strings.Contains(result, "this.tags,") {
			t.Error("Expected optional this.tags not found")
		}

		// Check documentation
		if !strings.Contains(result, "/// Arguments for creating a TestResource resource.") {
			t.Error("Expected Args class documentation not found")
		}
		if !strings.Contains(result, "/// The name.") {
			t.Error("Expected property documentation in Args class not found")
		}
	})

	t.Run("args class with no properties", func(t *testing.T) {
		resource := &schema.Resource{
			Token:           "test:index:EmptyResource",
			IsComponent:     false,
			InputProperties: []*schema.Property{},
			Properties: []*schema.Property{
				{Name: "id", Type: schema.StringType},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Check empty constructor
		if !strings.Contains(result, "EmptyResourceArgs();") {
			t.Error("Expected empty Args constructor not found")
		}
	})
}

func TestGenerateOutputPropertyDeserialization(t *testing.T) {
	t.Run("string output", func(t *testing.T) {
		prop := &schema.Property{
			Name: "name",
			Type: schema.StringType,
		}

		result := generateOutputPropertyDeserialization(prop, "name")

		if !strings.Contains(result, "name = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		if !strings.Contains(result, "properties.fields['name']?.stringValue") {
			t.Error("Expected stringValue accessor not found")
		}
	})

	t.Run("int output", func(t *testing.T) {
		prop := &schema.Property{
			Name: "count",
			Type: schema.IntType,
		}

		result := generateOutputPropertyDeserialization(prop, "count")

		if !strings.Contains(result, "count = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		if !strings.Contains(result, "numberValue") {
			t.Error("Expected numberValue accessor not found")
		}
		if !strings.Contains(result, ".toInt()") {
			t.Error("Expected toInt() conversion not found")
		}
	})

	t.Run("bool output", func(t *testing.T) {
		prop := &schema.Property{
			Name: "enabled",
			Type: schema.BoolType,
		}

		result := generateOutputPropertyDeserialization(prop, "enabled")

		if !strings.Contains(result, "enabled = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		if !strings.Contains(result, "boolValue") {
			t.Error("Expected boolValue accessor not found")
		}
	})

	t.Run("double output", func(t *testing.T) {
		prop := &schema.Property{
			Name: "price",
			Type: schema.NumberType,
		}

		result := generateOutputPropertyDeserialization(prop, "price")

		if !strings.Contains(result, "price = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		if !strings.Contains(result, "numberValue") {
			t.Error("Expected numberValue accessor not found")
		}
	})

	t.Run("optional string output", func(t *testing.T) {
		prop := &schema.Property{
			Name: "description",
			Type: &schema.OptionalType{ElementType: schema.StringType},
		}

		result := generateOutputPropertyDeserialization(prop, "description")

		// Optional types now generate a nullable extraction without containsKey check
		if !strings.Contains(result, "description = Output.of(") {
			t.Error("Expected Output.of( not found for optional property")
		}
		if !strings.Contains(result, "stringValue") {
			t.Error("Expected stringValue accessor not found for optional property")
		}
	})

	t.Run("array output", func(t *testing.T) {
		prop := &schema.Property{
			Name: "items",
			Type: &schema.ArrayType{ElementType: schema.StringType},
		}

		result := generateOutputPropertyDeserialization(prop, "items")

		if !strings.Contains(result, "items = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		if !strings.Contains(result, "listValue.values.map") {
			t.Error("Expected listValue.values.map accessor not found")
		}
		if !strings.Contains(result, ".toList()") {
			t.Error("Expected .toList() conversion not found")
		}
	})

	t.Run("map output", func(t *testing.T) {
		prop := &schema.Property{
			Name: "tags",
			Type: &schema.MapType{ElementType: schema.StringType},
		}

		result := generateOutputPropertyDeserialization(prop, "tags")

		if !strings.Contains(result, "tags = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		if !strings.Contains(result, "Map.fromEntries") {
			t.Error("Expected Map.fromEntries not found")
		}
		if !strings.Contains(result, "structValue.fields.entries") {
			t.Error("Expected structValue.fields.entries accessor not found")
		}
	})
}

func TestCollectTypeImports(t *testing.T) {
	pkg := &schema.Package{Name: "test"}

	t.Run("collects object type imports", func(t *testing.T) {
		nestedType := &schema.ObjectType{Token: "test:index:NestedType"}

		props := []*schema.Property{
			{Name: "nested", Type: nestedType},
			{Name: "simple", Type: schema.StringType},
		}

		imports := collectTypeImports(pkg, props)

		found := false
		for _, imp := range imports {
			if strings.Contains(imp, "index_nested_type.dart") {
				found = true
				break
			}
		}

		if !found {
			t.Error("Expected import for nested type not found")
		}
	})

	t.Run("collects enum type imports", func(t *testing.T) {
		enumType := &schema.EnumType{
			Token:       "test:index:MyEnum",
			ElementType: schema.StringType,
		}

		props := []*schema.Property{
			{Name: "status", Type: enumType},
		}

		imports := collectTypeImports(pkg, props)

		found := false
		for _, imp := range imports {
			if strings.Contains(imp, "enums") && strings.Contains(imp, "index_my_enum.dart") {
				found = true
				break
			}
		}

		if !found {
			t.Error("Expected import for enum type not found")
		}
	})

	t.Run("handles array of objects", func(t *testing.T) {
		nestedType := &schema.ObjectType{Token: "test:index:ArrayItem"}

		props := []*schema.Property{
			{Name: "items", Type: &schema.ArrayType{ElementType: nestedType}},
		}

		imports := collectTypeImports(pkg, props)

		found := false
		for _, imp := range imports {
			if strings.Contains(imp, "index_array_item.dart") {
				found = true
				break
			}
		}

		if !found {
			t.Error("Expected import for array element type not found")
		}
	})

	t.Run("deduplicates imports from input and output properties", func(t *testing.T) {
		sharedType := &schema.ObjectType{Token: "test:index:SharedType"}

		inputProps := []*schema.Property{
			{Name: "input1", Type: sharedType},
		}
		outputProps := []*schema.Property{
			{Name: "output1", Type: sharedType},
		}

		imports := collectTypeImports(pkg, inputProps)
		imports = append(imports, collectTypeImports(pkg, outputProps)...)
		imports = dedupeStrings(imports)

		// Count occurrences
		count := 0
		for _, imp := range imports {
			if strings.Contains(imp, "index_shared_type.dart") {
				count++
			}
		}

		if count != 1 {
			t.Errorf("Expected exactly 1 import for shared type, got %d", count)
		}
	})
}
