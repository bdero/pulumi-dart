package dart

import (
	"strings"
	"testing"

	"github.com/pulumi/pulumi/pkg/v3/codegen/schema"
)

func TestGenerateUnionType(t *testing.T) {
	pkg := &schema.Package{Name: "test"}

	t.Run("generates sealed class for string and int union", func(t *testing.T) {
		info := &UnionTypeInfo{
			Name:  "StringOrInt",
			Token: "test:index:StringOrInt",
			ElementTypes: []schema.Type{
				schema.StringType,
				schema.IntType,
			},
		}

		content, err := generateUnionType(pkg, info)
		if err != nil {
			t.Fatalf("generateUnionType failed: %v", err)
		}

		result := string(content)

		// Check sealed class declaration
		if !strings.Contains(result, "sealed class StringOrInt {") {
			t.Error("Expected sealed class declaration not found")
		}

		// Check factory constructors
		if !strings.Contains(result, "factory StringOrInt.string(String value) = StringOrIntString;") {
			t.Error("Expected string factory constructor not found")
		}
		if !strings.Contains(result, "factory StringOrInt.int(int value) = StringOrIntInt;") {
			t.Error("Expected int factory constructor not found")
		}

		// Check value getter
		if !strings.Contains(result, "Object get value;") {
			t.Error("Expected value getter not found")
		}

		// Check subclass declarations
		if !strings.Contains(result, "final class StringOrIntString extends StringOrInt {") {
			t.Error("Expected String subclass not found")
		}
		if !strings.Contains(result, "final class StringOrIntInt extends StringOrInt {") {
			t.Error("Expected Int subclass not found")
		}

		// Check value field with override
		if !strings.Contains(result, "@override\n  final String value;") {
			t.Error("Expected String value field not found")
		}
		if !strings.Contains(result, "@override\n  final int value;") {
			t.Error("Expected int value field not found")
		}
	})

	t.Run("generates sealed class with object type variant", func(t *testing.T) {
		objectType := &schema.ObjectType{Token: "test:index:MyObject"}

		info := &UnionTypeInfo{
			Name:  "StringOrMyObject",
			Token: "test:index:StringOrMyObject",
			ElementTypes: []schema.Type{
				schema.StringType,
				objectType,
			},
		}

		content, err := generateUnionType(pkg, info)
		if err != nil {
			t.Fatalf("generateUnionType failed: %v", err)
		}

		result := string(content)

		// Check object type variant
		if !strings.Contains(result, "factory StringOrMyObject.myobject(MyObject value) = StringOrMyObjectMyObject;") {
			t.Error("Expected object type factory constructor not found")
		}

		// Check import for object type
		if !strings.Contains(result, "import '../types/index_my_object.dart';") {
			t.Error("Expected import for object type not found")
		}
	})

	t.Run("generates sealed class with array variant", func(t *testing.T) {
		info := &UnionTypeInfo{
			Name:  "StringOrStringList",
			Token: "test:index:StringOrStringList",
			ElementTypes: []schema.Type{
				schema.StringType,
				&schema.ArrayType{ElementType: schema.StringType},
			},
		}

		content, err := generateUnionType(pkg, info)
		if err != nil {
			t.Fatalf("generateUnionType failed: %v", err)
		}

		result := string(content)

		// Check array variant name
		if !strings.Contains(result, "StringOrStringListStringList") {
			t.Error("Expected StringList variant class not found")
		}

		// Check List<String> type
		if !strings.Contains(result, "final List<String> value;") {
			t.Error("Expected List<String> value field not found")
		}
	})

	t.Run("generates equality operators", func(t *testing.T) {
		info := &UnionTypeInfo{
			Name:  "TestUnion",
			Token: "test:index:TestUnion",
			ElementTypes: []schema.Type{
				schema.StringType,
			},
		}

		content, err := generateUnionType(pkg, info)
		if err != nil {
			t.Fatalf("generateUnionType failed: %v", err)
		}

		result := string(content)

		// Check equality operator
		if !strings.Contains(result, "bool operator ==(Object other)") {
			t.Error("Expected equality operator not found")
		}

		// Check hashCode
		if !strings.Contains(result, "int get hashCode => value.hashCode;") {
			t.Error("Expected hashCode getter not found")
		}
	})

	t.Run("generates toString", func(t *testing.T) {
		info := &UnionTypeInfo{
			Name:  "TestUnion",
			Token: "test:index:TestUnion",
			ElementTypes: []schema.Type{
				schema.IntType,
			},
		}

		content, err := generateUnionType(pkg, info)
		if err != nil {
			t.Fatalf("generateUnionType failed: %v", err)
		}

		result := string(content)

		if !strings.Contains(result, "String toString() => 'TestUnionInt($value)';") {
			t.Error("Expected toString method not found")
		}
	})
}

func TestGetUnionVariantName(t *testing.T) {
	tests := []struct {
		name     string
		input    schema.Type
		expected string
	}{
		{"bool", schema.BoolType, "Bool"},
		{"int", schema.IntType, "Int"},
		{"number/double", schema.NumberType, "Double"},
		{"string", schema.StringType, "String"},
		{"archive", schema.ArchiveType, "Archive"},
		{"asset", schema.AssetType, "Asset"},
		{"json", schema.JSONType, "Json"},
		{"any", schema.AnyType, "Any"},
		{
			"object type",
			&schema.ObjectType{Token: "test:index:MyType"},
			"MyType",
		},
		{
			"enum type",
			&schema.EnumType{Token: "test:index:MyEnum", ElementType: schema.StringType},
			"MyEnum",
		},
		{
			"array of strings",
			&schema.ArrayType{ElementType: schema.StringType},
			"StringList",
		},
		{
			"map of strings",
			&schema.MapType{ElementType: schema.StringType},
			"StringMap",
		},
		{
			"resource type",
			&schema.ResourceType{Token: "aws:s3/bucket:Bucket"},
			"Bucket",
		},
		{
			"token type with underlying",
			&schema.TokenType{Token: "test:custom:Id", UnderlyingType: schema.StringType},
			"String",
		},
		{
			"token type without underlying",
			&schema.TokenType{Token: "test:custom:MyToken"},
			"MyToken",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := getUnionVariantName(tt.input, 0)
			if result != tt.expected {
				t.Errorf("getUnionVariantName(%v) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestIsComplexUnion(t *testing.T) {
	tests := []struct {
		name     string
		union    *schema.UnionType
		expected bool
	}{
		{
			name: "single type union",
			union: &schema.UnionType{
				ElementTypes: []schema.Type{schema.StringType},
			},
			expected: false,
		},
		{
			name: "two different types",
			union: &schema.UnionType{
				ElementTypes: []schema.Type{schema.StringType, schema.IntType},
			},
			expected: true,
		},
		{
			name: "type with optional variant",
			union: &schema.UnionType{
				ElementTypes: []schema.Type{
					schema.StringType,
					&schema.OptionalType{ElementType: schema.StringType},
				},
			},
			expected: false,
		},
		{
			name: "three types",
			union: &schema.UnionType{
				ElementTypes: []schema.Type{schema.StringType, schema.IntType, schema.BoolType},
			},
			expected: true,
		},
		{
			name: "empty union",
			union: &schema.UnionType{
				ElementTypes: []schema.Type{},
			},
			expected: false,
		},
		{
			name: "two types one optional",
			union: &schema.UnionType{
				ElementTypes: []schema.Type{
					schema.StringType,
					&schema.OptionalType{ElementType: schema.IntType},
				},
			},
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isComplexUnion(tt.union)
			if result != tt.expected {
				t.Errorf("isComplexUnion(%v) = %v, want %v", tt.union, result, tt.expected)
			}
		})
	}
}

func TestGenerateUnionTypeName(t *testing.T) {
	tests := []struct {
		name     string
		union    *schema.UnionType
		expected string
	}{
		{
			name: "string and int",
			union: &schema.UnionType{
				ElementTypes: []schema.Type{schema.StringType, schema.IntType},
			},
			expected: "StringOrInt",
		},
		{
			name: "three primitives",
			union: &schema.UnionType{
				ElementTypes: []schema.Type{schema.StringType, schema.IntType, schema.BoolType},
			},
			expected: "StringOrIntOrBool",
		},
		{
			name: "with optional type excluded",
			union: &schema.UnionType{
				ElementTypes: []schema.Type{
					schema.StringType,
					&schema.OptionalType{ElementType: schema.IntType},
				},
			},
			expected: "String",
		},
		{
			name: "with object type",
			union: &schema.UnionType{
				ElementTypes: []schema.Type{
					schema.StringType,
					&schema.ObjectType{Token: "test:index:MyType"},
				},
			},
			expected: "StringOrMyType",
		},
		{
			name: "empty union",
			union: &schema.UnionType{
				ElementTypes: []schema.Type{},
			},
			expected: "UnionType",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := generateUnionTypeName(tt.union)
			if result != tt.expected {
				t.Errorf("generateUnionTypeName(%v) = %q, want %q", tt.union, result, tt.expected)
			}
		})
	}
}

func TestCollectUnionTypeImports(t *testing.T) {
	pkg := &schema.Package{Name: "test"}

	t.Run("collects imports for object types", func(t *testing.T) {
		types := []schema.Type{
			schema.StringType,
			&schema.ObjectType{Token: "test:index:MyType"},
		}

		imports := collectUnionTypeImports(pkg, types)

		found := false
		for _, imp := range imports {
			if strings.Contains(imp, "index_my_type.dart") {
				found = true
				break
			}
		}

		if !found {
			t.Error("Expected import for MyType not found")
		}
	})

	t.Run("does not include imports for primitive types", func(t *testing.T) {
		types := []schema.Type{
			schema.StringType,
			schema.IntType,
			schema.BoolType,
		}

		imports := collectUnionTypeImports(pkg, types)

		if len(imports) != 0 {
			t.Errorf("Expected no imports for primitive types, got %v", imports)
		}
	})

	t.Run("collects imports for enum types", func(t *testing.T) {
		types := []schema.Type{
			&schema.EnumType{Token: "test:index:MyEnum", ElementType: schema.StringType},
		}

		imports := collectUnionTypeImports(pkg, types)

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
}
