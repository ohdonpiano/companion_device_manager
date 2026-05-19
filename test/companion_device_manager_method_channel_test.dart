import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:companion_device_manager/companion_device_manager_method_channel.dart';
import 'package:companion_device_manager/companion_device_manager_types.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelCompanionDeviceManager platform = MethodChannelCompanionDeviceManager();
  const MethodChannel channel = MethodChannel('companion_device_manager');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'isAvailable':
              return true;
            case 'getAssociations':
              return <Map<String, Object?>>[
                <String, Object?>{'macAddress': '00:11:22:33:44:55'}
              ];
            case 'associate':
              return <String, Object?>{'macAddress': '00:11:22:33:44:55'};
            case 'getLastBackgroundEvent':
              return <String, Object?>{
                'type': 'device_appeared',
                'timestampMs': 123,
              };
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('isAvailable', () async {
    expect(await platform.isAvailable(), isTrue);
  });

  test('associate', () async {
    final association = await platform.associate(
      const CompanionDeviceAssociationRequest(
        displayName: 'Example',
        filters: <CompanionDeviceFilter>[
          CompanionDeviceFilter.bluetooth(address: '00:11:22:33:44:55'),
        ],
      ),
    );

    expect(association.macAddress, '00:11:22:33:44:55');
  });

  test('getLastBackgroundEvent', () async {
    final event = await platform.getLastBackgroundEvent();
    expect(event?.type, 'device_appeared');
  });
}
