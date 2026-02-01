package dart

import (
	"testing"

	"github.com/pulumi/pulumi/pkg/v3/codegen/schema"
)

func TestToSnakeCase(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"HelloWorld", "hello_world"},
		{"helloWorld", "hello_world"},
		{"hello", "hello"},
		{"HELLO", "h_e_l_l_o"},
		{"hello-world", "hello_world"},
		{"hello world", "hello_world"},
		{"HelloWorldTest", "hello_world_test"},
		{"", ""},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			result := ToSnakeCase(tt.input)
			if result != tt.expected {
				t.Errorf("ToSnakeCase(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestToCamelCase(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"hello_world", "helloWorld"},
		{"hello-world", "helloWorld"},
		{"hello world", "helloWorld"},
		{"HelloWorld", "helloworld"},
		{"hello", "hello"},
		{"HELLO", "hello"},
		{"", ""},
		{"class", "class_"}, // Reserved word
		{"async", "async_"}, // Reserved word
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			result := toCamelCase(tt.input)
			if result != tt.expected {
				t.Errorf("toCamelCase(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestToPascalCase(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"hello_world", "HelloWorld"},
		{"hello-world", "HelloWorld"},
		{"hello world", "HelloWorld"},
		{"helloWorld", "Helloworld"},
		{"hello", "Hello"},
		{"", ""},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			result := toPascalCase(tt.input)
			if result != tt.expected {
				t.Errorf("toPascalCase(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestTokenToClassName(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"aws:s3/bucket:Bucket", "Bucket"},
		{"aws:ec2:Instance", "Instance"},
		{"pulumi:pulumi:Resource", "Resource"},
		{"pkg:mod:MyResource", "Myresource"},
		{"simple", "Simple"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			result := tokenToClassName(tt.input)
			if result != tt.expected {
				t.Errorf("tokenToClassName(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestTokenToModulePath(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"aws:s3/bucket:Bucket", "s3_bucket_bucket"},
		{"aws:ec2:Instance", "ec2_instance"},
		{"pulumi:pulumi:Resource", "pulumi_resource"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			result := tokenToModulePath(tt.input)
			if result != tt.expected {
				t.Errorf("tokenToModulePath(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestTypeToDart(t *testing.T) {
	tests := []struct {
		name     string
		input    schema.Type
		unwrap   bool
		expected string
	}{
		{"string", schema.StringType, true, "String"},
		{"int", schema.IntType, true, "int"},
		{"number", schema.NumberType, true, "double"},
		{"bool", schema.BoolType, true, "bool"},
		{"any", schema.AnyType, true, "Object"},
		{"json", schema.JSONType, true, "Object"},
		{
			"array of strings",
			&schema.ArrayType{ElementType: schema.StringType},
			true,
			"List<String>",
		},
		{
			"map of strings",
			&schema.MapType{ElementType: schema.StringType},
			true,
			"Map<String, String>",
		},
		{
			"nested array",
			&schema.ArrayType{ElementType: &schema.ArrayType{ElementType: schema.IntType}},
			true,
			"List<List<int>>",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := typeToDart(tt.input, tt.unwrap)
			if result != tt.expected {
				t.Errorf("typeToDart(%v, %v) = %q, want %q", tt.input, tt.unwrap, result, tt.expected)
			}
		})
	}
}

func TestEscapeDartString(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"hello", "hello"},
		{"hello'world", "hello\\'world"},
		{"hello\nworld", "hello\\nworld"},
		{"hello\\world", "hello\\\\world"},
		{"hello$var", "hello\\$var"},
		{"tab\there", "tab\\there"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			result := escapeDartString(tt.input)
			if result != tt.expected {
				t.Errorf("escapeDartString(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestMakeValidIdentifier(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"hello", "hello"},
		{"hello-world", "hello_world"},
		{"123abc", "_123abc"},
		{"class", "class_"},
		{"", "_"},
		{"hello@world", "hello_world"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			result := makeValidIdentifier(tt.input)
			if result != tt.expected {
				t.Errorf("makeValidIdentifier(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestToEnumCaseName(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"private", "private"},
		{"public-read", "publicRead"},
		{"PUBLIC_READ_WRITE", "publicReadWrite"},
		{"default", "defaultValue"},
		{"123", "v123"},
		{"", "unknown"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			result := toEnumCaseName(tt.input)
			if result != tt.expected {
				t.Errorf("toEnumCaseName(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}
