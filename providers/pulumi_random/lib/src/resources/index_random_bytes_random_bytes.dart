/// Generated resource class for random:index/randomBytes:RandomBytes.
///
/// The resource <span pulumi-lang-nodejs="`random.RandomBytes`" pulumi-lang-dotnet="`random.RandomBytes`" pulumi-lang-go="`RandomBytes`" pulumi-lang-python="`RandomBytes`" pulumi-lang-yaml="`random.RandomBytes`" pulumi-lang-java="`random.RandomBytes`">`random.RandomBytes`</span> generates random bytes that are intended to be used as a secret, or key. Use this in preference to <span pulumi-lang-nodejs="`random.RandomId`" pulumi-lang-dotnet="`random.RandomId`" pulumi-lang-go="`RandomId`" pulumi-lang-python="`RandomId`" pulumi-lang-yaml="`random.RandomId`" pulumi-lang-java="`random.RandomId`">`random.RandomId`</span> when the output is considered sensitive, and should not be displayed in the CLI.
/// 
/// This resource *does* use a cryptographic random number generator.
/// 
/// ## Example Usage
/// 
/// <!--Start PulumiCodeChooser -->
/// ```typescript
/// import * as pulumi from "@pulumi/pulumi";
/// import * as azurerm from "@pulumi/azurerm";
/// import * as random from "@pulumi/random";
/// 
/// const jwtSecret = new random.RandomBytes("jwt_secret", {length: 64});
/// const jwtSecretKeyVaultSecret = new azurerm.index.KeyVaultSecret("jwt_secret", {
///     keyVaultId: "some-azure-key-vault-id",
///     name: "JwtSecret",
///     value: jwtSecret.base64,
/// });
/// ```
/// ```python
/// import pulumi
/// import pulumi_azurerm as azurerm
/// import pulumi_random as random
/// 
/// jwt_secret = random.RandomBytes("jwt_secret", length=64)
/// jwt_secret_key_vault_secret = azurerm.index.KeyVaultSecret("jwt_secret",
///     key_vault_id=some-azure-key-vault-id,
///     name=JwtSecret,
///     value=jwt_secret.base64)
/// ```
/// ```csharp
/// using System.Collections.Generic;
/// using System.Linq;
/// using Pulumi;
/// using Azurerm = Pulumi.Azurerm;
/// using Random = Pulumi.Random;
/// 
/// return await Deployment.RunAsync(() => 
/// {
///     var jwtSecret = new Random.RandomBytes("jwt_secret", new()
///     {
///         Length = 64,
///     });
/// 
///     var jwtSecretKeyVaultSecret = new Azurerm.Index.KeyVaultSecret("jwt_secret", new()
///     {
///         KeyVaultId = "some-azure-key-vault-id",
///         Name = "JwtSecret",
///         Value = jwtSecret.Base64,
///     });
/// 
/// });
/// ```
/// ```go
/// package main
/// 
/// import (
/// 	"github.com/pulumi/pulumi-azurerm/sdk/go/azurerm"
/// 	"github.com/pulumi/pulumi-random/sdk/v4/go/random"
/// 	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
/// )
/// 
/// func main() {
/// 	pulumi.Run(func(ctx *pulumi.Context) error {
/// 		jwtSecret, err := random.NewRandomBytes(ctx, "jwt_secret", &random.RandomBytesArgs{
/// 			Length: pulumi.Int(64),
/// 		})
/// 		if err != nil {
/// 			return err
/// 		}
/// 		_, err = azurerm.NewKeyVaultSecret(ctx, "jwt_secret", &azurerm.KeyVaultSecretArgs{
/// 			KeyVaultId: "some-azure-key-vault-id",
/// 			Name:       "JwtSecret",
/// 			Value:      jwtSecret.Base64,
/// 		})
/// 		if err != nil {
/// 			return err
/// 		}
/// 		return nil
/// 	})
/// }
/// ```
/// ```java
/// package generated_program;
/// 
/// import com.pulumi.Context;
/// import com.pulumi.Pulumi;
/// import com.pulumi.core.Output;
/// import com.pulumi.random.RandomBytes;
/// import com.pulumi.random.RandomBytesArgs;
/// import com.pulumi.azurerm.KeyVaultSecret;
/// import com.pulumi.azurerm.KeyVaultSecretArgs;
/// import java.util.List;
/// import java.util.ArrayList;
/// import java.util.Map;
/// import java.io.File;
/// import java.nio.file.Files;
/// import java.nio.file.Paths;
/// 
/// public class App {
///     public static void main(String[] args) {
///         Pulumi.run(App::stack);
///     }
/// 
///     public static void stack(Context ctx) {
///         var jwtSecret = new RandomBytes("jwtSecret", RandomBytesArgs.builder()
///             .length(64)
///             .build());
/// 
///         var jwtSecretKeyVaultSecret = new KeyVaultSecret("jwtSecretKeyVaultSecret", KeyVaultSecretArgs.builder()
///             .keyVaultId("some-azure-key-vault-id")
///             .name("JwtSecret")
///             .value(jwtSecret.base64())
///             .build());
/// 
///     }
/// }
/// ```
/// ```yaml
/// resources:
///   jwtSecret:
///     type: random:RandomBytes
///     name: jwt_secret
///     properties:
///       length: 64
///   jwtSecretKeyVaultSecret:
///     type: azurerm:KeyVaultSecret
///     name: jwt_secret
///     properties:
///       keyVaultId: some-azure-key-vault-id
///       name: JwtSecret
///       value: ${jwtSecret.base64}
/// ```
/// <!--End PulumiCodeChooser -->
/// 
/// ## Import
/// 
/// The `pulumi import` command can be used, for example:
/// 
/// Random bytes can be imported by specifying the value as base64 string.
/// 
/// ```sh
/// $ pulumi import random:index/randomBytes:RandomBytes basic "8/fu3q+2DcgSJ19i0jZ5Cw=="
/// ```
/// 
/// 

import 'package:pulumi/pulumi.dart';
import 'package:meta/meta.dart';
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';

class RandomBytes extends CustomResource {
  /// The generated bytes presented in base64 string format.
  /// 
  late final Output<String> base64;

  /// The generated bytes presented in lowercase hexadecimal string format. The length of the encoded string is exactly twice the <span pulumi-lang-nodejs="`length`" pulumi-lang-dotnet="`Length`" pulumi-lang-go="`length`" pulumi-lang-python="`length`" pulumi-lang-yaml="`length`" pulumi-lang-java="`length`">`length`</span> parameter.
  /// 
  late final Output<String> hex;

  /// Arbitrary map of values that, when changed, will trigger recreation of resource. See the main provider documentation for more information.
  /// 
  late final Output<Map<String, String>?> keepers;

  /// The number of bytes requested. The minimum value for length is 1.
  /// 
  late final Output<int> length;

  final RandomBytesArgs _args;

  /// Creates a new RandomBytes resource.
  RandomBytes(
    String name,
    RandomBytesArgs args, {
    CustomResourceOptions? options,
  }) : _args = args,
       super('random:index/randomBytes:RandomBytes', name, options);

  @override
  Map<String, Input<Object?>?> get inputs => {
    'keepers': _args.keepers,
    'length': _args.length,
  };

  @override
  @protected
  void processOutputs(Struct properties) {
    super.processOutputs(properties);
    base64 = Output.of(properties.fields['base64']?.stringValue ?? '');
    hex = Output.of(properties.fields['hex']?.stringValue ?? '');
    keepers = Output.of(properties.fields.containsKey('keepers') ? Map.fromEntries(properties.fields['keepers']!.structValue.fields.entries.map((e) => MapEntry(e.key, e.value.stringValue))) : null);
    length = Output.of((properties.fields['length']?.numberValue ?? 0).toInt());
  }
}

/// Arguments for creating a RandomBytes resource.
class RandomBytesArgs {
  /// Arbitrary map of values that, when changed, will trigger recreation of resource. See the main provider documentation for more information.
  /// 
  final Input<Map<String, String>>? keepers;

  /// The number of bytes requested. The minimum value for length is 1.
  /// 
  final Input<int> length;

  RandomBytesArgs({
    required this.length,
    this.keepers,
  });
}
