package dart

import (
	"strings"
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
		{"HelloWorld", "helloworld"},          // PascalCase gets lowercased first char
		{"hello", "hello"},                     // Single lowercase word preserved
		{"helloWorld", "helloWorld"},           // Already camelCase - preserved
		{"getAvailabilityZones", "getAvailabilityZones"}, // Already camelCase - preserved
		{"HELLO", "hello"},                     // All caps gets lowercased
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
		{"helloWorld", "HelloWorld"},           // camelCase gets first char uppercased, rest preserved
		{"getAvailabilityZones", "GetAvailabilityZones"}, // camelCase preserved
		{"MyResource", "MyResource"},           // Already PascalCase - preserved
		{"hello", "Hello"},                     // Single word gets uppercased
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
		{"pkg:mod:MyResource", "MyResource"},  // PascalCase preserved
		{"pkg:mod:my_resource", "MyResource"}, // snake_case converted
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

func TestTokenToQualifiedClassName(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		// Basic cases
		{"aws:s3/bucket:Bucket", "S3Bucket"},
		{"aws:ec2:Instance", "Ec2Instance"},
		{"pulumi:pulumi:Resource", "PulumiResource"},
		{"pkg:mod:MyResource", "ModMyResource"},
		{"pkg:mod:my_resource", "ModMyResource"},
		{"simple", "Simple"},
		// GCP-like collision cases
		{"gcp:bigquery:AppProfile", "BigqueryAppProfile"},
		{"gcp:bigtable:AppProfile", "BigtableAppProfile"},
		// Submodule cases - should use only first part of module
		{"gcp:compute/instance:Settings", "ComputeSettings"},
		{"aws:s3/bucket:BucketWebsite", "S3BucketWebsite"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			result := tokenToQualifiedClassName(tt.input)
			if result != tt.expected {
				t.Errorf("tokenToQualifiedClassName(%q) = %q, want %q", tt.input, result, tt.expected)
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

	// Test long token truncation (like GCP's very long type names)
	t.Run("long token truncation", func(t *testing.T) {
		longToken := "gcp:dataloss/preventionDeidentifyTemplateDeidentifyConfigInfoTypeTransformationsTransformationPrimitiveTransformationCryptoDeterministicConfig:PreventionDeidentifyTemplateDeidentifyConfigInfoTypeTransformationsTransformationPrimitiveTransformationCryptoDeterministicConfig"
		result := tokenToModulePath(longToken)
		if len(result) > maxFilenameLength {
			t.Errorf("tokenToModulePath for long token should be truncated, got len=%d, want <= %d", len(result), maxFilenameLength)
		}
		// Verify it still has a meaningful prefix
		if !strings.HasPrefix(result, "dataloss_prevention") {
			t.Errorf("truncated path should preserve meaningful prefix, got %q", result)
		}
	})
}

func TestTruncateFilename(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		maxLen   int
		checkLen bool
	}{
		{
			name:     "short name unchanged",
			input:    "short_name",
			checkLen: false,
		},
		{
			name:     "long name truncated",
			input:    "this_is_a_very_long_filename_that_exceeds_the_maximum_allowed_length_and_should_be_truncated_with_a_hash_suffix_to_ensure_uniqueness",
			checkLen: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := truncateFilename(tt.input)
			if tt.checkLen {
				if len(result) > maxFilenameLength {
					t.Errorf("truncateFilename(%q) = %q (len=%d), want len <= %d", tt.input, result, len(result), maxFilenameLength)
				}
				// Verify hash suffix is present
				if !containsHash(result) {
					t.Errorf("truncateFilename(%q) = %q, expected hash suffix", tt.input, result)
				}
			} else {
				if result != tt.input {
					t.Errorf("truncateFilename(%q) = %q, want unchanged", tt.input, result)
				}
			}
		})
	}

	// Test that different long inputs produce different outputs
	t.Run("uniqueness", func(t *testing.T) {
		input1 := "this_is_a_very_long_filename_that_exceeds_the_maximum_allowed_length_abc"
		input2 := "this_is_a_very_long_filename_that_exceeds_the_maximum_allowed_length_xyz"
		// Make inputs long enough to trigger truncation
		input1 = input1 + "_extra_padding_to_make_this_exceed_the_limit"
		input2 = input2 + "_extra_padding_to_make_this_exceed_the_limit"
		result1 := truncateFilename(input1)
		result2 := truncateFilename(input2)
		if result1 == result2 {
			t.Errorf("truncateFilename should produce different outputs for different inputs: %q vs %q", result1, result2)
		}
	})
}

func containsHash(s string) bool {
	// Check if the string ends with an underscore followed by 8 hex characters
	if len(s) < 9 {
		return false
	}
	suffix := s[len(s)-9:]
	if suffix[0] != '_' {
		return false
	}
	for _, c := range suffix[1:] {
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) {
			return false
		}
	}
	return true
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
