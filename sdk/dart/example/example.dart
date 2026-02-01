/// Example Pulumi program using the Dart SDK.
///
/// This example demonstrates basic usage of the Pulumi Dart SDK including:
/// - Running a Pulumi program
/// - Working with Outputs
/// - Exporting stack outputs
/// - Using configuration
///
/// To run this example:
/// 1. Install the Pulumi CLI: https://www.pulumi.com/docs/install/
/// 2. Create a Pulumi.yaml in your project root
/// 3. Run: pulumi up
library;

import 'package:pulumi/pulumi.dart';

Future<void> main() async {
  await Pulumi.run((ctx) async {
    // Read configuration values
    final config = Config();
    final projectName = config.get('projectName') ?? 'my-project';

    // Create outputs
    final greeting = Output.of('Hello from $projectName!');

    // Transform outputs using apply
    final upperGreeting = greeting.apply((g) => g.toUpperCase());

    // Combine multiple outputs
    final timestamp = Output.of(DateTime.now().toIso8601String());
    final message = Output.all([greeting, timestamp]).apply((values) {
      return '${values[0]} Generated at: ${values[1]}';
    });

    // Export values to the stack
    ctx.export('greeting', greeting);
    ctx.export('upperGreeting', upperGreeting);
    ctx.export('message', message);

    // Example: Creating a custom resource (uncomment when using a provider)
    // final myResource = MyCustomResource(
    //   'example-resource',
    //   MyResourceArgs(property: Input.value('value')),
    // );
    // await myResource.registered;
    // ctx.export('resourceId', myResource.id);
  });
}
