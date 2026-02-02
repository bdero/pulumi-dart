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
		if !strings.Contains(result, "class IndexMyResource extends CustomResource {") {
			t.Error("Expected CustomResource class declaration not found")
		}

		// Check output properties with late final Output<T>
		// Note: "id" is a reserved name (conflicts with CustomResource.id) so it becomes "idValue"
		if !strings.Contains(result, "late final Output<String> idValue;") {
			t.Error("Expected idValue output property not found")
		}
		if !strings.Contains(result, "late final Output<String> arn;") {
			t.Error("Expected arn output property not found")
		}

		// Check _args field
		if !strings.Contains(result, "final IndexMyResourceArgs _args;") {
			t.Error("Expected _args field not found")
		}

		// Check constructor
		if !strings.Contains(result, "IndexMyResource(") {
			t.Error("Expected constructor not found")
		}
		if !strings.Contains(result, "String name,") {
			t.Error("Expected name parameter in constructor not found")
		}
		if !strings.Contains(result, "IndexMyResourceArgs args,") {
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
		if !strings.Contains(result, "class IndexMyComponent extends ComponentResource {") {
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
		if !strings.Contains(result, "class IndexTestResourceArgs {") {
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
		if !strings.Contains(result, "/// Arguments for creating a IndexTestResource resource.") {
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
		if !strings.Contains(result, "IndexEmptyResourceArgs();") {
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

	t.Run("handles map of objects", func(t *testing.T) {
		nestedType := &schema.ObjectType{Token: "test:index:MapValueType"}

		props := []*schema.Property{
			{Name: "items", Type: &schema.MapType{ElementType: nestedType}},
		}

		imports := collectTypeImports(pkg, props)

		found := false
		for _, imp := range imports {
			if strings.Contains(imp, "index_map_value_type.dart") {
				found = true
				break
			}
		}

		if !found {
			t.Error("Expected import for map element type not found")
		}
	})

	t.Run("handles optional wrapped types", func(t *testing.T) {
		nestedType := &schema.ObjectType{Token: "test:index:OptionalWrappedType"}

		props := []*schema.Property{
			{Name: "config", Type: &schema.OptionalType{ElementType: nestedType}},
		}

		imports := collectTypeImports(pkg, props)

		found := false
		for _, imp := range imports {
			if strings.Contains(imp, "index_optional_wrapped_type.dart") {
				found = true
				break
			}
		}

		if !found {
			t.Error("Expected import for optional wrapped type not found")
		}
	})

	t.Run("handles union types with object elements", func(t *testing.T) {
		objectType1 := &schema.ObjectType{Token: "test:index:UnionTypeA"}
		objectType2 := &schema.ObjectType{Token: "test:index:UnionTypeB"}

		props := []*schema.Property{
			{Name: "unionProp", Type: &schema.UnionType{ElementTypes: []schema.Type{objectType1, objectType2}}},
		}

		imports := collectTypeImports(pkg, props)

		foundA := false
		foundB := false
		for _, imp := range imports {
			if strings.Contains(imp, "index_union_type_a.dart") {
				foundA = true
			}
			if strings.Contains(imp, "index_union_type_b.dart") {
				foundB = true
			}
		}

		if !foundA {
			t.Error("Expected import for union type A not found")
		}
		if !foundB {
			t.Error("Expected import for union type B not found")
		}
	})

	t.Run("handles input wrapped types", func(t *testing.T) {
		nestedType := &schema.ObjectType{Token: "test:index:InputWrappedType"}

		props := []*schema.Property{
			{Name: "inputProp", Type: &schema.InputType{ElementType: nestedType}},
		}

		imports := collectTypeImports(pkg, props)

		found := false
		for _, imp := range imports {
			if strings.Contains(imp, "index_input_wrapped_type.dart") {
				found = true
				break
			}
		}

		if !found {
			t.Error("Expected import for input wrapped type not found")
		}
	})
}

func TestGenerateResourceWithComplexNestedInputs(t *testing.T) {
	pkg := &schema.Package{
		Name: "test",
	}

	t.Run("resource with array of objects", func(t *testing.T) {
		itemType := &schema.ObjectType{Token: "test:index:ItemConfig"}

		resource := &schema.Resource{
			Token:       "test:index:ArrayOfObjectsResource",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "items", Type: &schema.ArrayType{ElementType: itemType}},
			},
			Properties: []*schema.Property{
				{Name: "processedItems", Type: &schema.ArrayType{ElementType: itemType}},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Check import for nested type
		if !strings.Contains(result, "import '../types/index_item_config.dart';") {
			t.Error("Expected import for item type not found")
		}

		// Check Input<List<IndexItemConfig>> for input property
		if !strings.Contains(result, "final Input<List<IndexItemConfig>> items;") {
			t.Error("Expected Input<List<IndexItemConfig>> property not found")
		}

		// Check Output<List<IndexItemConfig>> for output property
		if !strings.Contains(result, "late final Output<List<IndexItemConfig>> processedItems;") {
			t.Error("Expected Output<List<IndexItemConfig>> output property not found")
		}

		// Check deserialization uses fromPropertyMap
		if !strings.Contains(result, "IndexItemConfig.fromPropertyMap") {
			t.Error("Expected fromPropertyMap call in deserialization not found")
		}
	})

	t.Run("resource with map of objects", func(t *testing.T) {
		valueType := &schema.ObjectType{Token: "test:index:ValueConfig"}

		resource := &schema.Resource{
			Token:       "test:index:MapOfObjectsResource",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "configs", Type: &schema.MapType{ElementType: valueType}},
			},
			Properties: []*schema.Property{
				{Name: "resolvedConfigs", Type: &schema.MapType{ElementType: valueType}},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Check import for nested type
		if !strings.Contains(result, "import '../types/index_value_config.dart';") {
			t.Error("Expected import for value type not found")
		}

		// Check Input<Map<String, IndexValueConfig>> for input property
		if !strings.Contains(result, "final Input<Map<String, IndexValueConfig>> configs;") {
			t.Error("Expected Input<Map<String, IndexValueConfig>> property not found")
		}

		// Check Output<Map<String, IndexValueConfig>> for output property
		if !strings.Contains(result, "late final Output<Map<String, IndexValueConfig>> resolvedConfigs;") {
			t.Error("Expected Output<Map<String, IndexValueConfig>> output property not found")
		}

		// Check deserialization uses Map.fromEntries and fromPropertyMap
		if !strings.Contains(result, "Map.fromEntries") {
			t.Error("Expected Map.fromEntries in deserialization not found")
		}
		if !strings.Contains(result, "IndexValueConfig.fromPropertyMap") {
			t.Error("Expected fromPropertyMap call in deserialization not found")
		}
	})

	t.Run("resource with deeply nested types", func(t *testing.T) {
		innerType := &schema.ObjectType{Token: "test:index:InnerType"}

		resource := &schema.Resource{
			Token:       "test:index:DeeplyNestedResource",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "nestedLists", Type: &schema.ArrayType{
					ElementType: &schema.ArrayType{ElementType: innerType},
				}},
				{Name: "mapOfLists", Type: &schema.MapType{
					ElementType: &schema.ArrayType{ElementType: schema.StringType},
				}},
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

		// Check nested list type
		if !strings.Contains(result, "final Input<List<List<IndexInnerType>>> nestedLists;") {
			t.Error("Expected Input<List<List<IndexInnerType>>> property not found")
		}

		// Check map of lists type
		if !strings.Contains(result, "final Input<Map<String, List<String>>> mapOfLists;") {
			t.Error("Expected Input<Map<String, List<String>>> property not found")
		}
	})
}

func TestGenerateResourceWithReservedNames(t *testing.T) {
	pkg := &schema.Package{
		Name: "test",
	}

	t.Run("resource with all reserved property names", func(t *testing.T) {
		resource := &schema.Resource{
			Token:       "test:index:ReservedNamesResource",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "inputs", Type: schema.StringType},
				{Name: "hashCode", Type: schema.StringType}, // reserved in both objectReservedNames and resourceReservedNames
				{Name: "type", Type: schema.StringType},
			},
			Properties: []*schema.Property{
				{Name: "urn", Type: schema.StringType},
				{Name: "id", Type: schema.StringType},
				{Name: "processOutputs", Type: schema.StringType},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Check that reserved names are suffixed with "Value" in output properties
		if !strings.Contains(result, "late final Output<String> urnValue;") {
			t.Error("Expected urnValue output property not found")
		}
		if !strings.Contains(result, "late final Output<String> idValue;") {
			t.Error("Expected idValue output property not found")
		}
		if !strings.Contains(result, "late final Output<String> processOutputsValue;") {
			t.Error("Expected processOutputsValue output property not found")
		}

		// Check inputs getter still maps to original names (property keys use original names,
		// but args property access uses potentially suffixed names)
		if !strings.Contains(result, "'inputs': _args.inputs,") {
			t.Error("Expected 'inputs' key in inputs getter not found")
		}
		// hashCode is in objectReservedNames, so it becomes hashCodeValue in Args class
		if !strings.Contains(result, "'hashCode': _args.hashCodeValue,") {
			t.Error("Expected 'hashCode' key in inputs getter not found")
		}
		// type is in resourceReservedNames but NOT objectReservedNames, so args uses "type"
		if !strings.Contains(result, "'type': _args.type,") {
			t.Error("Expected 'type' key in inputs getter not found")
		}
	})

	t.Run("resource with dart reserved keywords as property names", func(t *testing.T) {
		resource := &schema.Resource{
			Token:       "test:index:KeywordsResource",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "class", Type: schema.StringType},
				{Name: "switch", Type: schema.StringType},
				{Name: "default", Type: schema.BoolType},
			},
			Properties: []*schema.Property{
				{Name: "return", Type: schema.StringType},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Check that Dart reserved keywords are escaped with underscore
		if !strings.Contains(result, "final Input<String> class_;") {
			t.Error("Expected class_ property in Args not found")
		}
		if !strings.Contains(result, "final Input<String> switch_;") {
			t.Error("Expected switch_ property in Args not found")
		}
		if !strings.Contains(result, "final Input<bool> default_;") {
			t.Error("Expected default_ property in Args not found")
		}
		if !strings.Contains(result, "late final Output<String> return_;") {
			t.Error("Expected return_ output property not found")
		}
	})
}

func TestGenerateResourceWithUnionTypes(t *testing.T) {
	pkg := &schema.Package{
		Name: "test",
	}

	t.Run("resource with union type properties", func(t *testing.T) {
		resource := &schema.Resource{
			Token:       "test:index:UnionResource",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "stringOrInt", Type: &schema.UnionType{
					ElementTypes: []schema.Type{schema.StringType, schema.IntType},
				}},
			},
			Properties: []*schema.Property{
				{Name: "result", Type: &schema.UnionType{
					ElementTypes: []schema.Type{schema.StringType, schema.IntType},
				}},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Union types without specific handling become Object
		if !strings.Contains(result, "final Input<Object> stringOrInt;") {
			t.Error("Expected Input<Object> for union type property not found")
		}
		if !strings.Contains(result, "late final Output<Object> result;") {
			t.Error("Expected Output<Object> for union type output property not found")
		}
	})

	t.Run("resource with nullable union type", func(t *testing.T) {
		// A union with an optional type collapses to the non-optional type
		resource := &schema.Resource{
			Token:       "test:index:NullableUnionResource",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "nullableString", Type: &schema.UnionType{
					ElementTypes: []schema.Type{
						schema.StringType,
						&schema.OptionalType{ElementType: schema.StringType},
					},
				}},
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

		// Union with optional collapses to base type
		if !strings.Contains(result, "final Input<String> nullableString;") {
			t.Error("Expected Input<String> for nullable union type property not found")
		}
	})
}

func TestGenerateOutputPropertyDeserializationExtended(t *testing.T) {
	t.Run("object type output", func(t *testing.T) {
		objectType := &schema.ObjectType{Token: "test:index:ConfigType"}
		prop := &schema.Property{
			Name: "config",
			Type: objectType,
		}

		result := generateOutputPropertyDeserialization(prop, "config")

		if !strings.Contains(result, "config = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		if !strings.Contains(result, "IndexConfigType.fromPropertyMap") {
			t.Error("Expected fromPropertyMap call not found")
		}
		if !strings.Contains(result, "PropertyDeserializer.deserializeStruct") {
			t.Error("Expected PropertyDeserializer.deserializeStruct not found")
		}
	})

	t.Run("enum type output", func(t *testing.T) {
		enumType := &schema.EnumType{
			Token:       "test:index:StatusEnum",
			ElementType: schema.StringType,
		}
		prop := &schema.Property{
			Name: "status",
			Type: enumType,
		}

		result := generateOutputPropertyDeserialization(prop, "status")

		if !strings.Contains(result, "status = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		if !strings.Contains(result, "IndexStatusEnum.fromValue") {
			t.Error("Expected fromValue call not found")
		}
		if !strings.Contains(result, "stringValue") {
			t.Error("Expected stringValue accessor not found")
		}
	})

	t.Run("optional object type output", func(t *testing.T) {
		objectType := &schema.ObjectType{Token: "test:index:OptionalConfig"}
		prop := &schema.Property{
			Name: "optConfig",
			Type: &schema.OptionalType{ElementType: objectType},
		}

		result := generateOutputPropertyDeserialization(prop, "optConfig")

		if !strings.Contains(result, "optConfig = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		// Optional should have null check
		if !strings.Contains(result, "!= null ?") {
			t.Error("Expected null check for optional object not found")
		}
		if !strings.Contains(result, ": null") {
			t.Error("Expected null fallback for optional object not found")
		}
	})

	t.Run("optional enum type output", func(t *testing.T) {
		enumType := &schema.EnumType{
			Token:       "test:index:OptionalStatusEnum",
			ElementType: schema.StringType,
		}
		prop := &schema.Property{
			Name: "optStatus",
			Type: &schema.OptionalType{ElementType: enumType},
		}

		result := generateOutputPropertyDeserialization(prop, "optStatus")

		if !strings.Contains(result, "optStatus = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		// Optional enum should have null check
		if !strings.Contains(result, "!= null ?") {
			t.Error("Expected null check for optional enum not found")
		}
	})

	t.Run("array of int output", func(t *testing.T) {
		prop := &schema.Property{
			Name: "numbers",
			Type: &schema.ArrayType{ElementType: schema.IntType},
		}

		result := generateOutputPropertyDeserialization(prop, "numbers")

		if !strings.Contains(result, "numbers = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		if !strings.Contains(result, "v.numberValue.toInt()") {
			t.Error("Expected toInt() conversion in list mapping not found")
		}
	})

	t.Run("array of bool output", func(t *testing.T) {
		prop := &schema.Property{
			Name: "flags",
			Type: &schema.ArrayType{ElementType: schema.BoolType},
		}

		result := generateOutputPropertyDeserialization(prop, "flags")

		if !strings.Contains(result, "flags = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		if !strings.Contains(result, "v.boolValue") {
			t.Error("Expected boolValue in list mapping not found")
		}
	})

	t.Run("map of int output", func(t *testing.T) {
		prop := &schema.Property{
			Name: "counts",
			Type: &schema.MapType{ElementType: schema.IntType},
		}

		result := generateOutputPropertyDeserialization(prop, "counts")

		if !strings.Contains(result, "counts = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		if !strings.Contains(result, "e.value.numberValue.toInt()") {
			t.Error("Expected toInt() conversion in map entry not found")
		}
	})

	t.Run("map of bool output", func(t *testing.T) {
		prop := &schema.Property{
			Name: "switches",
			Type: &schema.MapType{ElementType: schema.BoolType},
		}

		result := generateOutputPropertyDeserialization(prop, "switches")

		if !strings.Contains(result, "switches = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		if !strings.Contains(result, "e.value.boolValue") {
			t.Error("Expected boolValue in map entry not found")
		}
	})

	t.Run("array of objects output", func(t *testing.T) {
		objectType := &schema.ObjectType{Token: "test:index:ListItem"}
		prop := &schema.Property{
			Name: "items",
			Type: &schema.ArrayType{ElementType: objectType},
		}

		result := generateOutputPropertyDeserialization(prop, "items")

		if !strings.Contains(result, "items = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		if !strings.Contains(result, "IndexListItem.fromPropertyMap") {
			t.Error("Expected fromPropertyMap in list mapping not found")
		}
	})

	t.Run("map of objects output", func(t *testing.T) {
		objectType := &schema.ObjectType{Token: "test:index:MapValue"}
		prop := &schema.Property{
			Name: "values",
			Type: &schema.MapType{ElementType: objectType},
		}

		result := generateOutputPropertyDeserialization(prop, "values")

		if !strings.Contains(result, "values = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		if !strings.Contains(result, "IndexMapValue.fromPropertyMap") {
			t.Error("Expected fromPropertyMap in map entry not found")
		}
	})

	t.Run("optional array output", func(t *testing.T) {
		prop := &schema.Property{
			Name: "optionalItems",
			Type: &schema.OptionalType{
				ElementType: &schema.ArrayType{ElementType: schema.StringType},
			},
		}

		result := generateOutputPropertyDeserialization(prop, "optionalItems")

		if !strings.Contains(result, "optionalItems = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		// Optional array should use containsKey check
		if !strings.Contains(result, "containsKey('optionalItems')") {
			t.Error("Expected containsKey check for optional array not found")
		}
		if !strings.Contains(result, ": null") {
			t.Error("Expected null fallback for optional array not found")
		}
	})

	t.Run("optional map output", func(t *testing.T) {
		prop := &schema.Property{
			Name: "optionalTags",
			Type: &schema.OptionalType{
				ElementType: &schema.MapType{ElementType: schema.StringType},
			},
		}

		result := generateOutputPropertyDeserialization(prop, "optionalTags")

		if !strings.Contains(result, "optionalTags = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		// Optional map should use containsKey check
		if !strings.Contains(result, "containsKey('optionalTags')") {
			t.Error("Expected containsKey check for optional map not found")
		}
	})
}

func TestGenerateResourceMultipleEnumTypes(t *testing.T) {
	pkg := &schema.Package{
		Name: "test",
	}

	t.Run("resource with multiple enum types", func(t *testing.T) {
		statusEnum := &schema.EnumType{
			Token:       "test:index:Status",
			ElementType: schema.StringType,
		}
		priorityEnum := &schema.EnumType{
			Token:       "test:index:Priority",
			ElementType: schema.IntType,
		}

		resource := &schema.Resource{
			Token:       "test:index:MultiEnumResource",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "status", Type: statusEnum},
				{Name: "priority", Type: priorityEnum},
			},
			Properties: []*schema.Property{
				{Name: "currentStatus", Type: statusEnum},
				{Name: "currentPriority", Type: priorityEnum},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Check imports for both enum types
		if !strings.Contains(result, "import '../enums/index_status.dart';") {
			t.Error("Expected import for Status enum not found")
		}
		if !strings.Contains(result, "import '../enums/index_priority.dart';") {
			t.Error("Expected import for Priority enum not found")
		}

		// Check input properties
		if !strings.Contains(result, "final Input<IndexStatus> status;") {
			t.Error("Expected Input<IndexStatus> property not found")
		}
		if !strings.Contains(result, "final Input<IndexPriority> priority;") {
			t.Error("Expected Input<IndexPriority> property not found")
		}

		// Check output properties
		if !strings.Contains(result, "late final Output<IndexStatus> currentStatus;") {
			t.Error("Expected Output<IndexStatus> output property not found")
		}
		if !strings.Contains(result, "late final Output<IndexPriority> currentPriority;") {
			t.Error("Expected Output<IndexPriority> output property not found")
		}
	})
}

func TestGenerateResourceWithMultilineComments(t *testing.T) {
	pkg := &schema.Package{
		Name: "test",
	}

	t.Run("resource with multiline documentation", func(t *testing.T) {
		resource := &schema.Resource{
			Token: "test:index:DocumentedResource",
			Comment: `A resource with detailed documentation.

This resource does several things:
- First thing
- Second thing
- Third thing

Use it carefully.`,
			IsComponent: false,
			InputProperties: []*schema.Property{
				{
					Name: "config",
					Type: schema.StringType,
					Comment: `The configuration string.

It must be a valid JSON string.`,
				},
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

		// Check that multiline comments are properly formatted
		if !strings.Contains(result, "/// A resource with detailed documentation.") {
			t.Error("Expected first line of resource documentation not found")
		}
		if !strings.Contains(result, "/// - First thing") {
			t.Error("Expected bullet point in documentation not found")
		}
		if !strings.Contains(result, "/// Use it carefully.") {
			t.Error("Expected last line of resource documentation not found")
		}
		if !strings.Contains(result, "/// The configuration string.") {
			t.Error("Expected property documentation not found")
		}
	})
}

func TestGenerateResourceWithOptionalOutputProperties(t *testing.T) {
	pkg := &schema.Package{
		Name: "test",
	}

	t.Run("resource with optional output properties", func(t *testing.T) {
		resource := &schema.Resource{
			Token:       "test:index:OptionalOutputResource",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "name", Type: schema.StringType},
			},
			Properties: []*schema.Property{
				{Name: "id", Type: schema.StringType},
				{Name: "optionalArn", Type: &schema.OptionalType{ElementType: schema.StringType}},
				{Name: "optionalCount", Type: &schema.OptionalType{ElementType: schema.IntType}},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Required output should not be nullable
		if !strings.Contains(result, "late final Output<String> idValue;") {
			t.Error("Expected Output<String> for required output not found")
		}

		// Optional outputs should have nullable type parameter
		if !strings.Contains(result, "late final Output<String?> optionalArn;") {
			t.Error("Expected Output<String?> for optional output not found")
		}
		if !strings.Contains(result, "late final Output<int?> optionalCount;") {
			t.Error("Expected Output<int?> for optional int output not found")
		}
	})
}

func TestGenerateResourceFromDifferentModules(t *testing.T) {
	pkg := &schema.Package{
		Name: "gcp",
	}

	t.Run("resource with types from different modules", func(t *testing.T) {
		computeType := &schema.ObjectType{Token: "gcp:compute:NetworkConfig"}
		storageType := &schema.ObjectType{Token: "gcp:storage:BucketConfig"}

		resource := &schema.Resource{
			Token:       "gcp:orchestration:Pipeline",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "networkConfig", Type: computeType},
				{Name: "storageConfig", Type: storageType},
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

		// Check imports use module-qualified paths
		if !strings.Contains(result, "import '../types/compute_network_config.dart';") {
			t.Error("Expected import for compute type not found")
		}
		if !strings.Contains(result, "import '../types/storage_bucket_config.dart';") {
			t.Error("Expected import for storage type not found")
		}

		// Check property types use qualified class names
		if !strings.Contains(result, "final Input<ComputeNetworkConfig> networkConfig;") {
			t.Error("Expected ComputeNetworkConfig property not found")
		}
		if !strings.Contains(result, "final Input<StorageBucketConfig> storageConfig;") {
			t.Error("Expected StorageBucketConfig property not found")
		}
	})
}

func TestGenerateResourceWithDeprecatedOutputProperties(t *testing.T) {
	pkg := &schema.Package{
		Name: "test",
	}

	t.Run("output property with deprecation message", func(t *testing.T) {
		resource := &schema.Resource{
			Token:       "test:index:DeprecatedOutputResource",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "name", Type: schema.StringType},
			},
			Properties: []*schema.Property{
				{
					Name:               "oldOutput",
					Type:               schema.StringType,
					DeprecationMessage: "Use newOutput instead.",
				},
				{Name: "newOutput", Type: schema.StringType},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Check output property deprecation annotation
		if !strings.Contains(result, "@Deprecated('Use newOutput instead.')") {
			t.Error("Expected @Deprecated annotation for output property not found")
		}
		// Check the deprecated property declaration
		if !strings.Contains(result, "late final Output<String> oldOutput;") {
			t.Error("Expected oldOutput output property not found")
		}
	})
}

func TestGenerateOutputPropertyDeserializationOptionalPrimitives(t *testing.T) {
	t.Run("optional bool output", func(t *testing.T) {
		prop := &schema.Property{
			Name: "optionalEnabled",
			Type: &schema.OptionalType{ElementType: schema.BoolType},
		}

		result := generateOutputPropertyDeserialization(prop, "optionalEnabled")

		if !strings.Contains(result, "optionalEnabled = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		// Optional bool should use nullable accessor
		if !strings.Contains(result, "?.boolValue") {
			t.Error("Expected nullable boolValue accessor not found")
		}
	})

	t.Run("optional number output", func(t *testing.T) {
		prop := &schema.Property{
			Name: "optionalPrice",
			Type: &schema.OptionalType{ElementType: schema.NumberType},
		}

		result := generateOutputPropertyDeserialization(prop, "optionalPrice")

		if !strings.Contains(result, "optionalPrice = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		// Optional number should use nullable accessor
		if !strings.Contains(result, "?.numberValue") {
			t.Error("Expected nullable numberValue accessor not found")
		}
	})

	t.Run("optional int output", func(t *testing.T) {
		prop := &schema.Property{
			Name: "optionalCount",
			Type: &schema.OptionalType{ElementType: schema.IntType},
		}

		result := generateOutputPropertyDeserialization(prop, "optionalCount")

		if !strings.Contains(result, "optionalCount = Output.of(") {
			t.Error("Expected Output.of( not found")
		}
		// Optional int should use nullable accessor with toInt
		if !strings.Contains(result, "?.numberValue?.toInt()") {
			t.Error("Expected nullable numberValue?.toInt() accessor not found")
		}
	})
}

func TestGenerateListElementExtractionExtended(t *testing.T) {
	t.Run("number list element", func(t *testing.T) {
		result := generateListElementExtraction(schema.NumberType)

		if result != "v.numberValue" {
			t.Errorf("Expected 'v.numberValue', got '%s'", result)
		}
	})

	t.Run("unknown type list element defaults to string", func(t *testing.T) {
		// Use a union type which falls through to default case
		unionType := &schema.UnionType{
			ElementTypes: []schema.Type{schema.StringType, schema.IntType},
		}

		result := generateListElementExtraction(unionType)

		if result != "v.stringValue" {
			t.Errorf("Expected 'v.stringValue' for unknown type, got '%s'", result)
		}
	})
}

func TestGenerateMapValueExtractionExtended(t *testing.T) {
	t.Run("number map value", func(t *testing.T) {
		result := generateMapValueExtraction(schema.NumberType)

		if result != "e.value.numberValue" {
			t.Errorf("Expected 'e.value.numberValue', got '%s'", result)
		}
	})

	t.Run("unknown type map value defaults to string", func(t *testing.T) {
		// Use a union type which falls through to default case
		unionType := &schema.UnionType{
			ElementTypes: []schema.Type{schema.StringType, schema.IntType},
		}

		result := generateMapValueExtraction(unionType)

		if result != "e.value.stringValue" {
			t.Errorf("Expected 'e.value.stringValue' for unknown type, got '%s'", result)
		}
	})
}

func TestGeneratePrimitiveExtractionDefaultCase(t *testing.T) {
	t.Run("unknown type optional defaults to string", func(t *testing.T) {
		// Use a union type which falls through to default case
		unionType := &schema.UnionType{
			ElementTypes: []schema.Type{schema.StringType, schema.IntType},
		}

		result := generatePrimitiveExtraction(unionType, "properties.fields['test']", true)

		if result != "properties.fields['test']?.stringValue" {
			t.Errorf("Expected nullable stringValue for unknown optional type, got '%s'", result)
		}
	})

	t.Run("unknown type required defaults to string with fallback", func(t *testing.T) {
		// Use a union type which falls through to default case
		unionType := &schema.UnionType{
			ElementTypes: []schema.Type{schema.StringType, schema.IntType},
		}

		result := generatePrimitiveExtraction(unionType, "properties.fields['test']", false)

		if result != "properties.fields['test']?.stringValue ?? ''" {
			t.Errorf("Expected stringValue with fallback for unknown required type, got '%s'", result)
		}
	})
}

func TestGenerateResourceWithArrayAndMapOfNumber(t *testing.T) {
	pkg := &schema.Package{
		Name: "test",
	}

	t.Run("resource with array of number outputs", func(t *testing.T) {
		resource := &schema.Resource{
			Token:       "test:index:NumberArrayResource",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "name", Type: schema.StringType},
			},
			Properties: []*schema.Property{
				{Name: "prices", Type: &schema.ArrayType{ElementType: schema.NumberType}},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Check Output type for array of doubles
		if !strings.Contains(result, "late final Output<List<double>> prices;") {
			t.Error("Expected Output<List<double>> output property not found")
		}
		// Check deserialization uses numberValue
		if !strings.Contains(result, "v.numberValue") {
			t.Error("Expected v.numberValue in list mapping not found")
		}
	})

	t.Run("resource with map of number outputs", func(t *testing.T) {
		resource := &schema.Resource{
			Token:       "test:index:NumberMapResource",
			IsComponent: false,
			InputProperties: []*schema.Property{
				{Name: "name", Type: schema.StringType},
			},
			Properties: []*schema.Property{
				{Name: "metrics", Type: &schema.MapType{ElementType: schema.NumberType}},
			},
		}

		content, err := generateResource(pkg, resource)
		if err != nil {
			t.Fatalf("generateResource failed: %v", err)
		}

		result := string(content)

		// Check Output type for map of doubles
		if !strings.Contains(result, "late final Output<Map<String, double>> metrics;") {
			t.Error("Expected Output<Map<String, double>> output property not found")
		}
		// Check deserialization uses numberValue
		if !strings.Contains(result, "e.value.numberValue") {
			t.Error("Expected e.value.numberValue in map entry not found")
		}
	})
}
