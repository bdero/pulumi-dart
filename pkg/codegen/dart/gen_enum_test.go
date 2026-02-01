package dart

import (
	"strings"
	"testing"

	"github.com/pulumi/pulumi/pkg/v3/codegen/schema"
)

func TestGenerateEnum(t *testing.T) {
	pkg := &schema.Package{Name: "test"}

	t.Run("generates enum with string values", func(t *testing.T) {
		enumType := &schema.EnumType{
			Token:       "test:index:Status",
			Comment:     "The status of a resource.",
			ElementType: schema.StringType,
			Elements: []*schema.Enum{
				{Name: "active", Value: "active", Comment: "Resource is active."},
				{Name: "inactive", Value: "inactive", Comment: "Resource is inactive."},
				{Name: "pending", Value: "pending"},
			},
		}

		content, err := generateEnum(pkg, enumType)
		if err != nil {
			t.Fatalf("generateEnum failed: %v", err)
		}

		result := string(content)

		// Check enum declaration
		if !strings.Contains(result, "enum Status {") {
			t.Error("Expected enum declaration not found")
		}

		// Check enum values
		if !strings.Contains(result, "active._('active'),") {
			t.Error("Expected active enum value not found")
		}
		if !strings.Contains(result, "inactive._('inactive'),") {
			t.Error("Expected inactive enum value not found")
		}
		if !strings.Contains(result, "pending._('pending');") {
			t.Error("Expected pending enum value not found (should end with semicolon)")
		}

		// Check value field
		if !strings.Contains(result, "final String value;") {
			t.Error("Expected String value field not found")
		}

		// Check constructor
		if !strings.Contains(result, "const Status._(this.value);") {
			t.Error("Expected constructor not found")
		}

		// Check fromValue factory
		if !strings.Contains(result, "static Status fromValue(String value) {") {
			t.Error("Expected fromValue factory not found")
		}

		// Check tryFromValue factory
		if !strings.Contains(result, "static Status? tryFromValue(String value) {") {
			t.Error("Expected tryFromValue factory not found")
		}

		// Check documentation comment
		if !strings.Contains(result, "/// The status of a resource.") {
			t.Error("Expected enum documentation not found")
		}

		// Check value comments
		if !strings.Contains(result, "/// Resource is active.") {
			t.Error("Expected value documentation not found")
		}
	})

	t.Run("generates enum with integer values", func(t *testing.T) {
		enumType := &schema.EnumType{
			Token:       "test:index:Priority",
			ElementType: schema.IntType,
			Elements: []*schema.Enum{
				{Name: "low", Value: 1},
				{Name: "medium", Value: 2},
				{Name: "high", Value: 3},
			},
		}

		content, err := generateEnum(pkg, enumType)
		if err != nil {
			t.Fatalf("generateEnum failed: %v", err)
		}

		result := string(content)

		// Check int value field
		if !strings.Contains(result, "final int value;") {
			t.Error("Expected int value field not found")
		}

		// Check enum values with integers
		if !strings.Contains(result, "low._(1),") {
			t.Error("Expected low enum value with integer not found")
		}
		if !strings.Contains(result, "high._(3);") {
			t.Error("Expected high enum value with integer not found")
		}

		// Check fromValue factory with int parameter
		if !strings.Contains(result, "static Priority fromValue(int value) {") {
			t.Error("Expected fromValue factory with int not found")
		}
	})

	t.Run("generates enum with deprecated values", func(t *testing.T) {
		enumType := &schema.EnumType{
			Token:       "test:index:OldStatus",
			ElementType: schema.StringType,
			Elements: []*schema.Enum{
				{Name: "current", Value: "current"},
				{Name: "legacy", Value: "legacy", DeprecationMessage: "Use 'current' instead."},
			},
		}

		content, err := generateEnum(pkg, enumType)
		if err != nil {
			t.Fatalf("generateEnum failed: %v", err)
		}

		result := string(content)

		// Check deprecation annotation
		if !strings.Contains(result, "@Deprecated('Use \\'current\\' instead.')") {
			t.Error("Expected @Deprecated annotation not found")
		}
	})

	t.Run("handles reserved word enum values", func(t *testing.T) {
		enumType := &schema.EnumType{
			Token:       "test:index:ReservedEnum",
			ElementType: schema.StringType,
			Elements: []*schema.Enum{
				{Name: "default", Value: "default"},
				{Name: "class", Value: "class"},
				{Name: "null", Value: "null"},
			},
		}

		content, err := generateEnum(pkg, enumType)
		if err != nil {
			t.Fatalf("generateEnum failed: %v", err)
		}

		result := string(content)

		// Check that reserved words are escaped
		if !strings.Contains(result, "defaultValue._('default')") {
			t.Error("Expected defaultValue case name not found")
		}
		if !strings.Contains(result, "classValue._('class')") {
			t.Error("Expected classValue case name not found")
		}
		if !strings.Contains(result, "nullValue._('null')") {
			t.Error("Expected nullValue case name not found")
		}
	})

	t.Run("handles numeric enum value names", func(t *testing.T) {
		enumType := &schema.EnumType{
			Token:       "test:index:NumberedEnum",
			ElementType: schema.StringType,
			Elements: []*schema.Enum{
				{Name: "123", Value: "123"},
				{Name: "456abc", Value: "456abc"},
			},
		}

		content, err := generateEnum(pkg, enumType)
		if err != nil {
			t.Fatalf("generateEnum failed: %v", err)
		}

		result := string(content)

		// Check that numeric names are prefixed with 'v'
		if !strings.Contains(result, "v123._('123')") {
			t.Error("Expected v123 case name not found")
		}
		if !strings.Contains(result, "v456abc._('456abc')") {
			t.Error("Expected v456abc case name not found")
		}
	})

	t.Run("handles kebab-case enum value names", func(t *testing.T) {
		enumType := &schema.EnumType{
			Token:       "test:index:KebabEnum",
			ElementType: schema.StringType,
			Elements: []*schema.Enum{
				{Name: "public-read", Value: "public-read"},
				{Name: "public-read-write", Value: "public-read-write"},
			},
		}

		content, err := generateEnum(pkg, enumType)
		if err != nil {
			t.Fatalf("generateEnum failed: %v", err)
		}

		result := string(content)

		// Check camelCase conversion
		if !strings.Contains(result, "publicRead._('public-read')") {
			t.Error("Expected publicRead case name not found")
		}
		if !strings.Contains(result, "publicReadWrite._('public-read-write')") {
			t.Error("Expected publicReadWrite case name not found")
		}
	})

	t.Run("generates toString override", func(t *testing.T) {
		enumType := &schema.EnumType{
			Token:       "test:index:SimpleEnum",
			ElementType: schema.StringType,
			Elements: []*schema.Enum{
				{Name: "value", Value: "value"},
			},
		}

		content, err := generateEnum(pkg, enumType)
		if err != nil {
			t.Fatalf("generateEnum failed: %v", err)
		}

		result := string(content)

		// Check toString override
		if !strings.Contains(result, "@override\n  String toString() => value.toString();") {
			t.Error("Expected toString override not found")
		}
	})

	t.Run("generates enum with boolean values", func(t *testing.T) {
		enumType := &schema.EnumType{
			Token:       "test:index:BoolEnum",
			ElementType: schema.BoolType,
			Elements: []*schema.Enum{
				{Name: "enabled", Value: true},
				{Name: "disabled", Value: false},
			},
		}

		content, err := generateEnum(pkg, enumType)
		if err != nil {
			t.Fatalf("generateEnum failed: %v", err)
		}

		result := string(content)

		// Check bool value field
		if !strings.Contains(result, "final bool value;") {
			t.Error("Expected bool value field not found")
		}

		// Check boolean values
		if !strings.Contains(result, "enabled._(true)") {
			t.Error("Expected enabled with true not found")
		}
		if !strings.Contains(result, "disabled._(false)") {
			t.Error("Expected disabled with false not found")
		}
	})

	t.Run("generates enum with double values", func(t *testing.T) {
		enumType := &schema.EnumType{
			Token:       "test:index:DoubleEnum",
			ElementType: schema.NumberType,
			Elements: []*schema.Enum{
				{Name: "half", Value: 0.5},
				{Name: "full", Value: 1.0},
			},
		}

		content, err := generateEnum(pkg, enumType)
		if err != nil {
			t.Fatalf("generateEnum failed: %v", err)
		}

		result := string(content)

		// Check double value field
		if !strings.Contains(result, "final double value;") {
			t.Error("Expected double value field not found")
		}

		// Check double values
		if !strings.Contains(result, "half._(0.5)") {
			t.Error("Expected half with 0.5 not found")
		}
	})
}
