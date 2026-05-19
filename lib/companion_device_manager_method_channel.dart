import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'companion_device_manager_platform_interface.dart';
import 'companion_device_manager_types.dart';

/// An implementation of [CompanionDeviceManagerPlatform] that uses method channels.
class MethodChannelCompanionDeviceManager extends CompanionDeviceManagerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('companion_device_manager');

  @override
  Future<bool> isAvailable() async {
    return (await methodChannel.invokeMethod<bool>('isAvailable')) ?? false;
  }

  @override
  Future<List<CompanionDeviceAssociation>> getAssociations() async {
    final rawAssociations = await methodChannel.invokeMethod<List<Object?>>('getAssociations');
    return rawAssociations
            ?.whereType<Map<Object?, Object?>>()
            .map(CompanionDeviceAssociation.fromMap)
            .toList() ??
        <CompanionDeviceAssociation>[];
  }

  @override
  Future<CompanionDeviceAssociation> associate(
    CompanionDeviceAssociationRequest request,
  ) async {
    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'associate',
      request.toMap(),
    );
    if (result == null) {
      throw PlatformException(
        code: 'association_failed',
        message: 'The platform returned no association result.',
      );
    }
    return CompanionDeviceAssociation.fromMap(result);
  }

  @override
  Future<void> disassociate(CompanionDeviceAssociation association) async {
    await methodChannel.invokeMethod<void>('disassociate', association.toMap());
  }

  @override
  Future<void> registerBackgroundCallback(
    CompanionDeviceBackgroundCallback callback,
  ) async {
    final handle = PluginUtilities.getCallbackHandle(callback);
    if (handle == null) {
      throw ArgumentError(
        'The callback must be a top-level or static function annotated with @pragma(\'vm:entry-point\').' ,
      );
    }

    await methodChannel.invokeMethod<void>('registerBackgroundCallback', <String, Object?>{
      'callbackHandle': handle.toRawHandle(),
    });
  }

  @override
  Future<void> clearBackgroundCallback() async {
    await methodChannel.invokeMethod<void>('clearBackgroundCallback');
  }

  @override
  Future<CompanionDeviceEvent?> getLastBackgroundEvent() async {
    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>('getLastBackgroundEvent');
    if (result == null) {
      return null;
    }
    return CompanionDeviceEvent.fromMap(result);
  }
}
