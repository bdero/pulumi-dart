package dart

import (
	"strings"
	"testing"

	"github.com/pulumi/pulumi/pkg/v3/codegen/schema"
)

func TestGenerateType(t *testing.T) {
	pkg := &schema.Package{
		Name: "test",
	}

	t.Run("simple object type", func(t *testing.T) {
		objectType := &schema.ObjectType{
			Token:   "test:index:MyType",
			Comment: "A simple test type.",
			Properties: []*schema.Property{
				{Name: "name", Type: schema.StringType, Comment: "The name property."},
				{Name: "count", Type: schema.IntType},
			},
		}

		content, err := generateType(pkg, objectType)
		if err != nil {
			t.Fatalf("generateType failed: %v", err)
		}

		result := string(content)

		// Check class declaration
		if !strings.Contains(result, "class IndexMyType {") {
			t.Error("Expected class declaration not found")
		}

		// Check property declarations
		if !strings.Contains(result, "final String name;") {
			t.Error("Expected String property not found")
		}
		if !strings.Contains(result, "final int count;") {
			t.Error("Expected int property not found")
		}

		// Check constructor
		if !strings.Contains(result, "required this.name,") {
			t.Error("Expected required constructor parameter not found")
		}

		// Check fromPropertyMap factory
		if !strings.Contains(result, "factory IndexMyType.fromPropertyMap(Map<String, dynamic> properties)") {
			t.Error("Expected fromPropertyMap factory not found")
		}

		// Check toPropertyMap method
		if !strings.Contains(result, "Map<String, dynamic> toPropertyMap()") {
			t.Error("Expected toPropertyMap method not found")
		}

		// Check documentation comment
		if !strings.Contains(result, "/// A simple test type.") {
			t.Error("Expected type documentation not found")
		}

		// Check property comment
		if !strings.Contains(result, "/// The name property.") {
			t.Error("Expected property documentation not found")
		}
	})

	t.Run("type with optional properties", func(t *testing.T) {
		objectType := &schema.ObjectType{
			Token: "test:index:OptionalType",
			Properties: []*schema.Property{
				{Name: "required_field", Type: schema.StringType},
				{Name: "optional_field", Type: &schema.OptionalType{ElementType: schema.StringType}},
			},
		}

		content, err := generateType(pkg, objectType)
		if err != nil {
			t.Fatalf("generateType failed: %v", err)
		}

		result := string(content)

		// Check required property
		if !strings.Contains(result, "final String requiredField;") {
			t.Error("Expected required String property not found")
		}

		// Check optional property (should have ?)
		if !strings.Contains(result, "final String? optionalField;") {
			t.Error("Expected optional String? property not found")
		}

		// Check constructor parameters
		if !strings.Contains(result, "required this.requiredField,") {
			t.Error("Expected required constructor parameter not found")
		}
		if !strings.Contains(result, "this.optionalField,") {
			t.Error("Expected optional constructor parameter not found")
		}
	})

	t.Run("type with array and map properties", func(t *testing.T) {
		objectType := &schema.ObjectType{
			Token: "test:index:ComplexType",
			Properties: []*schema.Property{
				{Name: "tags", Type: &schema.MapType{ElementType: schema.StringType}},
				{Name: "items", Type: &schema.ArrayType{ElementType: schema.IntType}},
			},
		}

		content, err := generateType(pkg, objectType)
		if err != nil {
			t.Fatalf("generateType failed: %v", err)
		}

		result := string(content)

		// Check Map type
		if !strings.Contains(result, "final Map<String, String> tags;") {
			t.Error("Expected Map<String, String> property not found")
		}

		// Check List type
		if !strings.Contains(result, "final List<int> items;") {
			t.Error("Expected List<int> property not found")
		}
	})

	t.Run("type with deprecated property", func(t *testing.T) {
		objectType := &schema.ObjectType{
			Token: "test:index:DeprecatedType",
			Properties: []*schema.Property{
				{
					Name:               "old_field",
					Type:               schema.StringType,
					DeprecationMessage: "Use new_field instead.",
				},
			},
		}

		content, err := generateType(pkg, objectType)
		if err != nil {
			t.Fatalf("generateType failed: %v", err)
		}

		result := string(content)

		// Check deprecation annotation
		if !strings.Contains(result, "@Deprecated('Use new_field instead.')") {
			t.Error("Expected @Deprecated annotation not found")
		}
	})

	t.Run("type with nested object reference", func(t *testing.T) {
		nestedType := &schema.ObjectType{
			Token: "test:index:NestedType",
		}

		objectType := &schema.ObjectType{
			Token: "test:index:ParentType",
			Properties: []*schema.Property{
				{Name: "nested", Type: nestedType},
			},
		}

		content, err := generateType(pkg, objectType)
		if err != nil {
			t.Fatalf("generateType failed: %v", err)
		}

		result := string(content)

		// Check nested type reference
		if !strings.Contains(result, "final IndexNestedType nested;") {
			t.Error("Expected nested type reference not found")
		}

		// Check import
		if !strings.Contains(result, "import '../types/index_nested_type.dart';") {
			t.Error("Expected import for nested type not found")
		}

		// Check fromPropertyMap uses nested type's fromPropertyMap
		if !strings.Contains(result, "IndexNestedType.fromPropertyMap(properties['nested'] as Map<String, dynamic>)") {
			t.Error("Expected fromPropertyMap to call nested type's fromPropertyMap")
		}

		// Check toPropertyMap calls nested type's toPropertyMap
		if !strings.Contains(result, "'nested': nested.toPropertyMap()") {
			t.Error("Expected toPropertyMap to call nested type's toPropertyMap")
		}
	})

	t.Run("type with optional nested object", func(t *testing.T) {
		nestedType := &schema.ObjectType{
			Token: "test:index:OptionalNested",
		}

		objectType := &schema.ObjectType{
			Token: "test:index:ParentWithOptional",
			Properties: []*schema.Property{
				{Name: "maybe_nested", Type: &schema.OptionalType{ElementType: nestedType}},
			},
		}

		content, err := generateType(pkg, objectType)
		if err != nil {
			t.Fatalf("generateType failed: %v", err)
		}

		result := string(content)

		// Check optional nested type with null check in fromPropertyMap
		if !strings.Contains(result, "properties['maybe_nested'] != null ? IndexOptionalNested.fromPropertyMap(properties['maybe_nested'] as Map<String, dynamic>) : null") {
			t.Error("Expected fromPropertyMap to handle optional nested type with null check")
		}
	})

	t.Run("type with array of nested objects", func(t *testing.T) {
		nestedType := &schema.ObjectType{
			Token: "test:index:ArrayItem",
		}

		objectType := &schema.ObjectType{
			Token: "test:index:ParentWithArray",
			Properties: []*schema.Property{
				{Name: "items", Type: &schema.ArrayType{ElementType: nestedType}},
			},
		}

		content, err := generateType(pkg, objectType)
		if err != nil {
			t.Fatalf("generateType failed: %v", err)
		}

		result := string(content)

		// Check fromPropertyMap handles array of nested types
		if !strings.Contains(result, "IndexArrayItem.fromPropertyMap(e as Map<String, dynamic>)") {
			t.Error("Expected fromPropertyMap to deserialize array elements using fromPropertyMap")
		}

		// Check toPropertyMap handles array of nested types
		if !strings.Contains(result, "items.map((e) => e.toPropertyMap()).toList()") {
			t.Error("Expected toPropertyMap to serialize array elements using toPropertyMap")
		}
	})

	t.Run("type with map of nested objects", func(t *testing.T) {
		nestedType := &schema.ObjectType{
			Token: "test:index:MapValue",
		}

		objectType := &schema.ObjectType{
			Token: "test:index:ParentWithMap",
			Properties: []*schema.Property{
				{Name: "values", Type: &schema.MapType{ElementType: nestedType}},
			},
		}

		content, err := generateType(pkg, objectType)
		if err != nil {
			t.Fatalf("generateType failed: %v", err)
		}

		result := string(content)

		// Check fromPropertyMap handles map of nested types
		if !strings.Contains(result, "IndexMapValue.fromPropertyMap(v as Map<String, dynamic>)") {
			t.Error("Expected fromPropertyMap to deserialize map values using fromPropertyMap")
		}

		// Check toPropertyMap handles map of nested types
		if !strings.Contains(result, "values.map((k, v) => MapEntry(k, v.toPropertyMap()))") {
			t.Error("Expected toPropertyMap to serialize map values using toPropertyMap")
		}
	})

	t.Run("type with enum property", func(t *testing.T) {
		enumType := &schema.EnumType{
			Token:       "test:index:Status",
			ElementType: schema.StringType,
		}

		objectType := &schema.ObjectType{
			Token: "test:index:TypeWithEnum",
			Properties: []*schema.Property{
				{Name: "status", Type: enumType},
			},
		}

		content, err := generateType(pkg, objectType)
		if err != nil {
			t.Fatalf("generateType failed: %v", err)
		}

		result := string(content)

		// Check fromPropertyMap uses enum's fromValue
		if !strings.Contains(result, "IndexStatus.fromValue(properties['status'])") {
			t.Error("Expected fromPropertyMap to use enum's fromValue")
		}

		// Check toPropertyMap uses enum's value
		if !strings.Contains(result, "'status': status.value") {
			t.Error("Expected toPropertyMap to use enum's value")
		}
	})
}

func TestGenerateTypeArgs(t *testing.T) {
	pkg := &schema.Package{
		Name: "test",
	}

	t.Run("generates args class directly", func(t *testing.T) {
		objectType := &schema.ObjectType{
			Token: "test:index:MyInputType",
			Properties: []*schema.Property{
				{Name: "value", Type: schema.StringType},
			},
		}

		content, err := generateTypeArgs(pkg, objectType)
		if err != nil {
			t.Fatalf("generateTypeArgs failed: %v", err)
		}

		result := string(content)

		// Check that Args class is generated
		if !strings.Contains(result, "class IndexMyInputTypeArgs {") {
			t.Error("Expected Args class not found")
		}

		// Check Input<T> wrapping
		if !strings.Contains(result, "final Input<String> value;") {
			t.Error("Expected Input<String> property not found in Args class")
		}
	})
}

func TestTypeToDartUnion(t *testing.T) {
	tests := []struct {
		name        string
		unionType   *schema.UnionType
		unwrap      bool
		expected    string
		description string
	}{
		{
			name: "two element union with optional",
			unionType: &schema.UnionType{
				ElementTypes: []schema.Type{
					schema.StringType,
					&schema.OptionalType{ElementType: schema.StringType},
				},
			},
			unwrap:      true,
			expected:    "String",
			description: "Union with optional variant should return non-optional type",
		},
		{
			name: "simple two type union",
			unionType: &schema.UnionType{
				ElementTypes: []schema.Type{
					schema.StringType,
					schema.IntType,
				},
			},
			unwrap:      true,
			expected:    "Object",
			description: "Union of two different types should return Object",
		},
		{
			name: "multi type union",
			unionType: &schema.UnionType{
				ElementTypes: []schema.Type{
					schema.StringType,
					schema.IntType,
					schema.BoolType,
				},
			},
			unwrap:      true,
			expected:    "Object",
			description: "Union of multiple types should return Object",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := typeToDart(tt.unionType, tt.unwrap)
			if result != tt.expected {
				t.Errorf("typeToDart(%v) = %q, want %q (%s)",
					tt.unionType, result, tt.expected, tt.description)
			}
		})
	}
}

func TestTypeToDartInput(t *testing.T) {
	tests := []struct {
		name     string
		input    schema.Type
		unwrap   bool
		expected string
	}{
		{
			name:     "input with unwrap",
			input:    &schema.InputType{ElementType: schema.StringType},
			unwrap:   true,
			expected: "String",
		},
		{
			name:     "input without unwrap",
			input:    &schema.InputType{ElementType: schema.StringType},
			unwrap:   false,
			expected: "Input<String>",
		},
		{
			name:     "nested input with unwrap",
			input:    &schema.InputType{ElementType: &schema.ArrayType{ElementType: schema.StringType}},
			unwrap:   true,
			expected: "List<String>",
		},
		{
			name:     "nested input without unwrap",
			input:    &schema.InputType{ElementType: &schema.ArrayType{ElementType: schema.StringType}},
			unwrap:   false,
			expected: "Input<List<String>>",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := typeToDart(tt.input, tt.unwrap)
			if result != tt.expected {
				t.Errorf("typeToDart(%v, %v) = %q, want %q",
					tt.input, tt.unwrap, result, tt.expected)
			}
		})
	}
}

func TestTypeToDartOptional(t *testing.T) {
	tests := []struct {
		name     string
		input    schema.Type
		expected string
	}{
		{
			name:     "optional string",
			input:    &schema.OptionalType{ElementType: schema.StringType},
			expected: "String",
		},
		{
			name:     "optional array",
			input:    &schema.OptionalType{ElementType: &schema.ArrayType{ElementType: schema.IntType}},
			expected: "List<int>",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := typeToDart(tt.input, true)
			if result != tt.expected {
				t.Errorf("typeToDart(%v) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestTypeToDartResource(t *testing.T) {
	resourceType := &schema.ResourceType{
		Token: "aws:s3/bucket:Bucket",
	}

	result := typeToDart(resourceType, true)
	if result != "Bucket" {
		t.Errorf("typeToDart(%v) = %q, want %q", resourceType, result, "Bucket")
	}
}

func TestTypeToDartToken(t *testing.T) {
	tests := []struct {
		name     string
		token    *schema.TokenType
		expected string
	}{
		{
			name: "token with underlying type",
			token: &schema.TokenType{
				Token:          "pulumi:custom:MyId",
				UnderlyingType: schema.StringType,
			},
			expected: "String",
		},
		{
			name: "token without underlying type",
			token: &schema.TokenType{
				Token: "pulumi:custom:MyType",
			},
			expected: "MyType",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := typeToDart(tt.token, true)
			if result != tt.expected {
				t.Errorf("typeToDart(%v) = %q, want %q", tt.token, result, tt.expected)
			}
		})
	}
}

func TestTypeToDartSpecialTypes(t *testing.T) {
	tests := []struct {
		name     string
		input    schema.Type
		expected string
	}{
		{"archive", schema.ArchiveType, "Archive"},
		{"asset", schema.AssetType, "Asset"},
		{"json", schema.JSONType, "Object"},
		{"any", schema.AnyType, "Object"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := typeToDart(tt.input, true)
			if result != tt.expected {
				t.Errorf("typeToDart(%v) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestCollectObjectTypeImports(t *testing.T) {
	pkg := &schema.Package{Name: "test"}

	t.Run("collects object type imports", func(t *testing.T) {
		nestedType := &schema.ObjectType{Token: "test:index:NestedType"}

		props := []*schema.Property{
			{Name: "nested", Type: nestedType},
			{Name: "simple", Type: schema.StringType},
		}

		imports := collectObjectTypeImports(pkg, props)

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
			{Name: "enum_field", Type: enumType},
		}

		imports := collectObjectTypeImports(pkg, props)

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

		imports := collectObjectTypeImports(pkg, props)

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

	t.Run("handles map of objects", func(t *testing.T) {
		nestedType := &schema.ObjectType{Token: "test:index:MapValue"}

		props := []*schema.Property{
			{Name: "values", Type: &schema.MapType{ElementType: nestedType}},
		}

		imports := collectObjectTypeImports(pkg, props)

		found := false
		for _, imp := range imports {
			if strings.Contains(imp, "index_map_value.dart") {
				found = true
				break
			}
		}

		if !found {
			t.Error("Expected import for map value type not found")
		}
	})

	t.Run("deduplicates imports", func(t *testing.T) {
		nestedType := &schema.ObjectType{Token: "test:index:SharedType"}

		props := []*schema.Property{
			{Name: "field1", Type: nestedType},
			{Name: "field2", Type: nestedType},
			{Name: "field3", Type: &schema.ArrayType{ElementType: nestedType}},
		}

		imports := collectObjectTypeImports(pkg, props)

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

func TestGeneratePropertyMapExtractionNestedTypes(t *testing.T) {
	pkg := &schema.Package{Name: "test"}

	t.Run("nested array - List<List<String>>", func(t *testing.T) {
		objectType := &schema.ObjectType{
			Token: "test:index:NestedArrayType",
			Properties: []*schema.Property{
				{Name: "matrix", Type: &schema.ArrayType{ElementType: &schema.ArrayType{ElementType: schema.StringType}}},
			},
		}

		content, err := generateType(pkg, objectType)
		if err != nil {
			t.Fatalf("generateType failed: %v", err)
		}

		result := string(content)
		t.Logf("Generated code:\n%s", result)

		// Check that nested array deserialization recursively applies mapping
		// Should use proper nested List mapping, not just a simple cast
		if strings.Contains(result, "matrix: (properties['matrix'] as List?)?.map((e) => e as List<String>)") {
			t.Error("Nested arrays should not use simple casts - need recursive mapping")
		}
		// Should handle nested arrays properly with recursive mapping
		if !strings.Contains(result, "(e as List).map") {
			t.Error("Expected nested array deserialization with recursive List mapping")
		}
	})

	t.Run("map of arrays - Map<String, List<String>>", func(t *testing.T) {
		objectType := &schema.ObjectType{
			Token: "test:index:MapOfArraysType",
			Properties: []*schema.Property{
				{Name: "groups", Type: &schema.MapType{ElementType: &schema.ArrayType{ElementType: schema.StringType}}},
			},
		}

		content, err := generateType(pkg, objectType)
		if err != nil {
			t.Fatalf("generateType failed: %v", err)
		}

		result := string(content)
		t.Logf("Generated code:\n%s", result)

		// Should handle map of arrays properly with proper type conversion
		if strings.Contains(result, "groups: (properties['groups'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as List<String>))") {
			t.Error("Map of arrays should not use simple casts for list values")
		}
		// Should cast the inner list properly
		if !strings.Contains(result, "(v as List).map") {
			t.Error("Expected map of arrays deserialization with List mapping for values")
		}
	})

	t.Run("array of maps - List<Map<String, String>>", func(t *testing.T) {
		objectType := &schema.ObjectType{
			Token: "test:index:ArrayOfMapsType",
			Properties: []*schema.Property{
				{Name: "records", Type: &schema.ArrayType{ElementType: &schema.MapType{ElementType: schema.StringType}}},
			},
		}

		content, err := generateType(pkg, objectType)
		if err != nil {
			t.Fatalf("generateType failed: %v", err)
		}

		result := string(content)
		t.Logf("Generated code:\n%s", result)

		// Should handle array of maps properly
		if strings.Contains(result, ".map((e) => e as Map<String, String>)") {
			t.Error("Array of maps should not use simple casts for map elements")
		}
		// Should cast the inner map properly
		if !strings.Contains(result, "(e as Map<String, dynamic>).map") {
			t.Error("Expected array of maps deserialization with Map mapping for elements")
		}
	})

	t.Run("array of array of objects - List<List<ObjectType>>", func(t *testing.T) {
		nestedType := &schema.ObjectType{Token: "test:index:DeepItem"}

		objectType := &schema.ObjectType{
			Token: "test:index:DeepNestedType",
			Properties: []*schema.Property{
				{Name: "deep", Type: &schema.ArrayType{ElementType: &schema.ArrayType{ElementType: nestedType}}},
			},
		}

		content, err := generateType(pkg, objectType)
		if err != nil {
			t.Fatalf("generateType failed: %v", err)
		}

		result := string(content)
		t.Logf("Generated code:\n%s", result)

		// Should handle deeply nested types properly
		if !strings.Contains(result, "IndexDeepItem.fromPropertyMap") {
			t.Error("Expected deeply nested objects to use fromPropertyMap")
		}
	})

	t.Run("array of enums - List<Enum>", func(t *testing.T) {
		enumType := &schema.EnumType{
			Token:       "test:index:Priority",
			ElementType: schema.StringType,
		}

		objectType := &schema.ObjectType{
			Token: "test:index:TypeWithEnumArray",
			Properties: []*schema.Property{
				{Name: "priorities", Type: &schema.ArrayType{ElementType: enumType}},
			},
		}

		content, err := generateType(pkg, objectType)
		if err != nil {
			t.Fatalf("generateType failed: %v", err)
		}

		result := string(content)
		t.Logf("Generated code:\n%s", result)

		// Should handle array of enums using fromValue
		if !strings.Contains(result, "IndexPriority.fromValue(e)") {
			t.Error("Expected array of enums deserialization with fromValue")
		}
	})

	t.Run("map of enums - Map<String, Enum>", func(t *testing.T) {
		enumType := &schema.EnumType{
			Token:       "test:index:Status",
			ElementType: schema.StringType,
		}

		objectType := &schema.ObjectType{
			Token: "test:index:TypeWithEnumMap",
			Properties: []*schema.Property{
				{Name: "statusMap", Type: &schema.MapType{ElementType: enumType}},
			},
		}

		content, err := generateType(pkg, objectType)
		if err != nil {
			t.Fatalf("generateType failed: %v", err)
		}

		result := string(content)
		t.Logf("Generated code:\n%s", result)

		// Should handle map of enums using fromValue
		if !strings.Contains(result, "IndexStatus.fromValue(v)") {
			t.Error("Expected map of enums deserialization with fromValue")
		}
	})

	t.Run("map of objects - Map<String, ObjectType>", func(t *testing.T) {
		nestedType := &schema.ObjectType{Token: "test:index:ConfigItem"}

		objectType := &schema.ObjectType{
			Token: "test:index:TypeWithObjectMap",
			Properties: []*schema.Property{
				{Name: "configs", Type: &schema.MapType{ElementType: nestedType}},
			},
		}

		content, err := generateType(pkg, objectType)
		if err != nil {
			t.Fatalf("generateType failed: %v", err)
		}

		result := string(content)
		t.Logf("Generated code:\n%s", result)

		// Should handle map of objects using fromPropertyMap
		if !strings.Contains(result, "IndexConfigItem.fromPropertyMap(v as Map<String, dynamic>)") {
			t.Error("Expected map of objects deserialization with fromPropertyMap")
		}
	})

	t.Run("nested map - Map<String, Map<String, String>>", func(t *testing.T) {
		objectType := &schema.ObjectType{
			Token: "test:index:NestedMapType",
			Properties: []*schema.Property{
				{Name: "metadata", Type: &schema.MapType{ElementType: &schema.MapType{ElementType: schema.StringType}}},
			},
		}

		content, err := generateType(pkg, objectType)
		if err != nil {
			t.Fatalf("generateType failed: %v", err)
		}

		result := string(content)
		t.Logf("Generated code:\n%s", result)

		// Should handle nested maps with proper casting
		if !strings.Contains(result, "(v as Map<String, dynamic>).map") {
			t.Error("Expected nested maps deserialization with recursive mapping")
		}
	})
}
