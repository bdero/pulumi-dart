package dart

import (
	"strings"
	"testing"

	"github.com/pulumi/pulumi/pkg/v3/codegen/schema"
)

func TestGenerateFunction(t *testing.T) {
	pkg := &schema.Package{
		Name: "test",
	}

	t.Run("simple function with inputs and outputs", func(t *testing.T) {
		function := &schema.Function{
			Token:   "test:index:getAvailabilityZones",
			Comment: "Gets the list of availability zones.",
			Inputs: &schema.ObjectType{
				Properties: []*schema.Property{
					{Name: "region", Type: schema.StringType, Comment: "The region to query."},
					{Name: "all_availability_zones", Type: &schema.OptionalType{ElementType: schema.BoolType}},
				},
			},
			ReturnType: &schema.ObjectType{
				Token: "test:index:getAvailabilityZonesResult",
				Properties: []*schema.Property{
					{Name: "id", Type: schema.StringType},
					{Name: "names", Type: &schema.ArrayType{ElementType: schema.StringType}},
				},
			},
		}

		content, err := generateFunction(pkg, function)
		if err != nil {
			t.Fatalf("generateFunction failed: %v", err)
		}

		result := string(content)

		// Check imports
		if !strings.Contains(result, "import 'package:pulumi/pulumi.dart';") {
			t.Error("Expected pulumi import not found")
		}

		// Check async function signature
		if !strings.Contains(result, "Future<GetAvailabilityZonesResult> getAvailabilityZones({") {
			t.Error("Expected async function signature not found")
		}

		// Check function parameters
		if !strings.Contains(result, "required String region,") {
			t.Error("Expected required region parameter not found")
		}
		if !strings.Contains(result, "bool? allAvailabilityZones,") {
			t.Error("Expected optional allAvailabilityZones parameter not found")
		}
		if !strings.Contains(result, "InvokeOptions? options,") {
			t.Error("Expected InvokeOptions parameter not found")
		}

		// Check async keyword
		if !strings.Contains(result, "}) async {") {
			t.Error("Expected async keyword not found")
		}

		// Check args map building
		if !strings.Contains(result, "final args = <String, dynamic>{") {
			t.Error("Expected args map declaration not found")
		}
		if !strings.Contains(result, "'region': region,") {
			t.Error("Expected region in args map not found")
		}
		if !strings.Contains(result, "if (allAvailabilityZones != null) 'all_availability_zones': allAvailabilityZones,") {
			t.Error("Expected conditional allAvailabilityZones in args map not found")
		}

		// Check invoke call
		if !strings.Contains(result, "final result = await invoke('test:index:getAvailabilityZones', args, options);") {
			t.Error("Expected invoke call not found")
		}

		// Check return statement - function uses GetAvailabilityZonesResult
		if !strings.Contains(result, "GetAvailabilityZonesResult.fromPropertyMap(result)") {
			t.Error("Expected return statement not found")
		}

		// Check Result class
		if !strings.Contains(result, "class GetAvailabilityZonesResult") {
			t.Error("Expected Result class not found")
		}
		if !strings.Contains(result, "final String id;") {
			t.Error("Expected id property not found")
		}
		if !strings.Contains(result, "final List<String> names;") {
			t.Error("Expected names property not found")
		}

		// Check documentation
		if !strings.Contains(result, "/// Gets the list of availability zones.") {
			t.Error("Expected function documentation not found")
		}
		if !strings.Contains(result, "/// The region to query.") {
			t.Error("Expected parameter documentation not found")
		}
	})

	t.Run("function with no inputs", func(t *testing.T) {
		function := &schema.Function{
			Token:   "test:index:getCurrentUser",
			Comment: "Gets the current user.",
			ReturnType: &schema.ObjectType{
				Token: "test:index:getCurrentUserResult",
				Properties: []*schema.Property{
					{Name: "user_id", Type: schema.StringType},
					{Name: "email", Type: schema.StringType},
				},
			},
		}

		content, err := generateFunction(pkg, function)
		if err != nil {
			t.Fatalf("generateFunction failed: %v", err)
		}

		result := string(content)

		// Check function has options parameter
		if !strings.Contains(result, "Future<GetCurrentUserResult> getCurrentUser({") {
			t.Error("Expected function signature not found")
		}
		if !strings.Contains(result, "InvokeOptions? options,") {
			t.Error("Expected InvokeOptions parameter not found")
		}

		// Check args map (empty with just closing brace)
		if !strings.Contains(result, "final args = <String, dynamic>{") {
			t.Error("Expected empty args map not found")
		}
	})

	t.Run("function with no outputs", func(t *testing.T) {
		function := &schema.Function{
			Token:   "test:index:triggerBuild",
			Comment: "Triggers a build.",
			Inputs: &schema.ObjectType{
				Properties: []*schema.Property{
					{Name: "project_id", Type: schema.StringType},
				},
			},
			ReturnType: nil,
		}

		content, err := generateFunction(pkg, function)
		if err != nil {
			t.Fatalf("generateFunction failed: %v", err)
		}

		result := string(content)

		// Check void return type
		if !strings.Contains(result, "Future<void> triggerBuild(") {
			t.Error("Expected Future<void> return type not found")
		}

		// Check no Result class
		if strings.Contains(result, "class TriggerBuildResult") {
			t.Error("Should not generate Result class for function with no outputs")
		}
	})

	t.Run("deprecated function", func(t *testing.T) {
		function := &schema.Function{
			Token:              "test:index:getOldData",
			Comment:           "Gets old data.",
			DeprecationMessage: "Use getNewData instead.",
			ReturnType: &schema.ObjectType{
				Token: "test:index:getOldDataResult",
				Properties: []*schema.Property{
					{Name: "data", Type: schema.StringType},
				},
			},
		}

		content, err := generateFunction(pkg, function)
		if err != nil {
			t.Fatalf("generateFunction failed: %v", err)
		}

		result := string(content)

		// Check deprecation annotation
		if !strings.Contains(result, "@Deprecated('Use getNewData instead.')") {
			t.Error("Expected @Deprecated annotation not found")
		}
	})

	t.Run("function with complex types", func(t *testing.T) {
		nestedType := &schema.ObjectType{
			Token: "test:index:Config",
		}

		function := &schema.Function{
			Token:   "test:index:getWithConfig",
			Comment: "Gets data with config.",
			Inputs: &schema.ObjectType{
				Properties: []*schema.Property{
					{Name: "config", Type: nestedType},
					{Name: "tags", Type: &schema.MapType{ElementType: schema.StringType}},
					{Name: "ids", Type: &schema.ArrayType{ElementType: schema.IntType}},
				},
			},
			ReturnType: &schema.ObjectType{
				Token: "test:index:getWithConfigResult",
				Properties: []*schema.Property{
					{Name: "results", Type: &schema.ArrayType{ElementType: nestedType}},
				},
			},
		}

		content, err := generateFunction(pkg, function)
		if err != nil {
			t.Fatalf("generateFunction failed: %v", err)
		}

		result := string(content)

		// Check imports for nested type
		if !strings.Contains(result, "import '../types/index_config.dart';") {
			t.Error("Expected import for Config type not found")
		}

		// Check complex parameter types
		if !strings.Contains(result, "required Config config,") {
			t.Error("Expected Config parameter not found")
		}
		if !strings.Contains(result, "required Map<String, String> tags,") {
			t.Error("Expected Map parameter not found")
		}
		if !strings.Contains(result, "required List<int> ids,") {
			t.Error("Expected List parameter not found")
		}
	})

	t.Run("function with enum types", func(t *testing.T) {
		enumType := &schema.EnumType{
			Token:       "test:index:Status",
			ElementType: schema.StringType,
		}

		function := &schema.Function{
			Token:   "test:index:getByStatus",
			Comment: "Gets items by status.",
			Inputs: &schema.ObjectType{
				Properties: []*schema.Property{
					{Name: "status", Type: enumType},
				},
			},
			ReturnType: &schema.ObjectType{
				Token: "test:index:getByStatusResult",
				Properties: []*schema.Property{
					{Name: "current_status", Type: enumType},
				},
			},
		}

		content, err := generateFunction(pkg, function)
		if err != nil {
			t.Fatalf("generateFunction failed: %v", err)
		}

		result := string(content)

		// Check imports for enum type
		if !strings.Contains(result, "import '../enums/index_status.dart';") {
			t.Error("Expected import for Status enum not found")
		}

		// Check enum parameter type
		if !strings.Contains(result, "required Status status,") {
			t.Error("Expected Status parameter not found")
		}

		// Check enum in result
		if !strings.Contains(result, "final Status currentStatus;") {
			t.Error("Expected Status property in result not found")
		}
	})
}

func TestGenerateFunctionArgs(t *testing.T) {
	t.Run("generates args class with all property types", func(t *testing.T) {
		function := &schema.Function{
			Token: "test:index:myFunction",
			Inputs: &schema.ObjectType{
				Properties: []*schema.Property{
					{Name: "name", Type: schema.StringType, Comment: "The name."},
					{Name: "count", Type: schema.IntType},
					{Name: "enabled", Type: &schema.OptionalType{ElementType: schema.BoolType}},
					{Name: "tags", Type: &schema.OptionalType{ElementType: &schema.MapType{ElementType: schema.StringType}}},
				},
			},
		}

		content, err := generateFunctionArgs(function, "MyFunctionArgs")
		if err != nil {
			t.Fatalf("generateFunctionArgs failed: %v", err)
		}

		result := string(content)

		// Check class declaration
		if !strings.Contains(result, "class MyFunctionArgs {") {
			t.Error("Expected Args class declaration not found")
		}

		// Check required fields (no ?)
		if !strings.Contains(result, "final String name;") {
			t.Error("Expected required String field not found")
		}
		if !strings.Contains(result, "final int count;") {
			t.Error("Expected required int field not found")
		}

		// Check optional fields (with ?)
		if !strings.Contains(result, "final bool? enabled;") {
			t.Error("Expected optional bool? field not found")
		}
		if !strings.Contains(result, "final Map<String, String>? tags;") {
			t.Error("Expected optional Map? field not found")
		}

		// Check constructor
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

		// Check toPropertyMap
		if !strings.Contains(result, "Map<String, dynamic> toPropertyMap()") {
			t.Error("Expected toPropertyMap method not found")
		}
		if !strings.Contains(result, "'name': name,") {
			t.Error("Expected name in toPropertyMap not found")
		}
		if !strings.Contains(result, "if (enabled != null) 'enabled': enabled,") {
			t.Error("Expected conditional enabled in toPropertyMap not found")
		}

		// Check documentation
		if !strings.Contains(result, "/// The name.") {
			t.Error("Expected property documentation not found")
		}
	})

	t.Run("handles empty inputs", func(t *testing.T) {
		function := &schema.Function{
			Token:  "test:index:noArgsFunction",
			Inputs: nil,
		}

		content, err := generateFunctionArgs(function, "NoArgsFunctionArgs")
		if err != nil {
			t.Fatalf("generateFunctionArgs failed: %v", err)
		}

		result := string(content)

		// Check empty constructor
		if !strings.Contains(result, "NoArgsFunctionArgs();") {
			t.Error("Expected empty constructor not found")
		}
	})
}

func TestGenerateFunctionResult(t *testing.T) {
	t.Run("generates result class with all property types", func(t *testing.T) {
		function := &schema.Function{
			Token: "test:index:myFunction",
			ReturnType: &schema.ObjectType{
				Token: "test:index:myFunctionResult",
				Properties: []*schema.Property{
					{Name: "id", Type: schema.StringType, Comment: "The unique ID."},
					{Name: "count", Type: schema.IntType},
					{Name: "description", Type: &schema.OptionalType{ElementType: schema.StringType}},
					{Name: "items", Type: &schema.ArrayType{ElementType: schema.StringType}},
				},
			},
		}

		content, err := generateFunctionResult(function, "MyFunctionResult")
		if err != nil {
			t.Fatalf("generateFunctionResult failed: %v", err)
		}

		result := string(content)

		// Check class declaration
		if !strings.Contains(result, "class MyFunctionResult {") {
			t.Error("Expected Result class declaration not found")
		}

		// Check required fields
		if !strings.Contains(result, "final String id;") {
			t.Error("Expected required String field not found")
		}
		if !strings.Contains(result, "final int count;") {
			t.Error("Expected required int field not found")
		}
		if !strings.Contains(result, "final List<String> items;") {
			t.Error("Expected List<String> field not found")
		}

		// Check optional field
		if !strings.Contains(result, "final String? description;") {
			t.Error("Expected optional String? field not found")
		}

		// Check constructor with required/optional ordering
		if !strings.Contains(result, "required this.id,") {
			t.Error("Expected required this.id not found")
		}
		if !strings.Contains(result, "required this.count,") {
			t.Error("Expected required this.count not found")
		}
		if !strings.Contains(result, "required this.items,") {
			t.Error("Expected required this.items not found")
		}
		if !strings.Contains(result, "this.description,") {
			t.Error("Expected optional this.description not found")
		}

		// Check fromPropertyMap
		if !strings.Contains(result, "factory MyFunctionResult.fromPropertyMap(Map<String, dynamic> properties)") {
			t.Error("Expected fromPropertyMap factory not found")
		}
		if !strings.Contains(result, "id: properties['id'] as String,") {
			t.Error("Expected id deserialization not found")
		}
		if !strings.Contains(result, "description: properties['description'] as String?,") {
			t.Error("Expected description deserialization not found")
		}

		// Check documentation
		if !strings.Contains(result, "/// The unique ID.") {
			t.Error("Expected property documentation not found")
		}
	})

	t.Run("handles empty outputs", func(t *testing.T) {
		function := &schema.Function{
			Token:      "test:index:noResultFunction",
			ReturnType: nil,
		}

		content, err := generateFunctionResult(function, "NoResultFunctionResult")
		if err != nil {
			t.Fatalf("generateFunctionResult failed: %v", err)
		}

		result := string(content)

		// Check empty constructor
		if !strings.Contains(result, "NoResultFunctionResult();") {
			t.Error("Expected empty constructor not found")
		}
	})

	t.Run("handles object type return without properties", func(t *testing.T) {
		function := &schema.Function{
			Token: "test:index:emptyResult",
			ReturnType: &schema.ObjectType{
				Token:      "test:index:emptyResultResult",
				Properties: []*schema.Property{},
			},
		}

		content, err := generateFunctionResult(function, "EmptyResultResult")
		if err != nil {
			t.Fatalf("generateFunctionResult failed: %v", err)
		}

		result := string(content)

		// Check empty constructor
		if !strings.Contains(result, "EmptyResultResult();") {
			t.Error("Expected empty constructor not found")
		}
	})
}

func TestFunctionTokenConversion(t *testing.T) {
	t.Run("converts function token to name", func(t *testing.T) {
		tests := []struct {
			token    string
			expected string
		}{
			{"aws:ec2:getAvailabilityZones", "getAvailabilityZones"},
			{"azure:compute:getVirtualMachine", "getVirtualMachine"},
			{"test:index:simpleFunction", "simpleFunction"},
			{"pkg:module/sub:getData", "getData"},
		}

		for _, tt := range tests {
			result := tokenToFunctionName(tt.token)
			if result != tt.expected {
				t.Errorf("tokenToFunctionName(%q) = %q, want %q", tt.token, result, tt.expected)
			}
		}
	})
}
