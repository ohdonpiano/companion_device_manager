import 'package:flutter_test/flutter_test.dart';
import 'package:companion_device_manager/companion_device_manager.dart';
import 'package:companion_device_manager/companion_device_manager_platform_interface.dart';
import 'package:companion_device_manager/companion_device_manager_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCompanionDeviceManagerPlatform
    with MockPlatformInterfaceMixin
    implements CompanionDeviceManagerPlatform {
  @override
  Future<bool> isAvailable() => Future.value(true);

  @override
  Future<List<CompanionDeviceAssociation>> getAssociations() =>
      Future.value(<CompanionDeviceAssociation>[]);

  @override
  Future<CompanionDeviceAssociation> associate(
    CompanionDeviceAssociationRequest request,
  ) =>
      Future.value(CompanionDeviceAssociation(macAddress: request.filters.first.address));

  @override
  Future<void> disassociate(CompanionDeviceAssociation association) => Future.value();

  @override
  Future<void> registerBackgroundCallback(CompanionDeviceBackgroundCallback callback) =>
      Future.value();

  @override
  Future<void> clearBackgroundCallback() => Future.value();

  @override
  Future<CompanionDeviceEvent?> getLastBackgroundEvent() => Future.value(null);
}

void main() {
  final CompanionDeviceManagerPlatform initialPlatform = CompanionDeviceManagerPlatform.instance;

  test('$MethodChannelCompanionDeviceManager is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelCompanionDeviceManager>());
  });

  test('isAvailable delegates to the platform interface', () async {
    final CompanionDeviceManager companionDeviceManagerPlugin = CompanionDeviceManager();
    MockCompanionDeviceManagerPlatform fakePlatform = MockCompanionDeviceManagerPlatform();
    CompanionDeviceManagerPlatform.instance = fakePlatform;

    expect(await companionDeviceManagerPlugin.isAvailable(), isTrue);
  });

  test('associate delegates to the platform interface', () async {
    final CompanionDeviceManager companionDeviceManagerPlugin = CompanionDeviceManager();
    MockCompanionDeviceManagerPlatform fakePlatform = MockCompanionDeviceManagerPlatform();
    CompanionDeviceManagerPlatform.instance = fakePlatform;

    final association = await companionDeviceManagerPlugin.associate(
      CompanionDeviceAssociationRequest(
        displayName: 'Example',
        filters: <CompanionDeviceFilter>[
          CompanionDeviceFilter.bluetooth(address: '00:11:22:33:44:55'),
        ],
      ),
    );

    expect(association.macAddress, '00:11:22:33:44:55');
  });
}
