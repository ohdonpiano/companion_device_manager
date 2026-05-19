// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:companion_device_manager/companion_device_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Companion Device Manager is available', (WidgetTester tester) async {
    final CompanionDeviceManager plugin = CompanionDeviceManager();
    final bool available = await plugin.isAvailable();
    expect(available, isNotNull);
  });
}
