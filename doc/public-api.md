# Public API Reference

## Overview

The package root exports the full user-facing API:

```dart
import 'package:companion_device_manager/companion_device_manager.dart';
```

## `CompanionDeviceManager`

The facade class used by application code.

### `Future<bool> isAvailable()`

Checks whether the Android Companion Device Manager API is available on the current device.

### `Future<List<CompanionDeviceAssociation>> getAssociations()`

Returns the associations currently known to the Android system.

### `Future<CompanionDeviceAssociation> associate(CompanionDeviceAssociationRequest request)`

Starts the Android association chooser flow.

The request currently focuses on Bluetooth address-based filters and a display name.

### `Future<void> disassociate(CompanionDeviceAssociation association)`

Removes an association.

### `Future<void> registerBackgroundCallback(CompanionDeviceBackgroundCallback callback)`

Registers a Dart callback that will be executed when the companion service wakes the app.

The callback must be:

- top-level or static
- marked with `@pragma('vm:entry-point')`

### `Future<void> clearBackgroundCallback()`

Removes the persisted background callback registration.

### `Future<CompanionDeviceEvent?> getLastBackgroundEvent()`

Returns the latest persisted background event.

### `Stream<CompanionDeviceEvent> backgroundEvents`

Emits real-time companion device service events while the Flutter app is running.

Official event `type` values emitted by this stream are:

- `device_appeared`
- `device_disappeared`

## `CompanionDeviceAssociationRequest`

Represents the request used to start association.

Fields:

- `displayName`
- `filters`
- `selfManaged`
- `singleDevice`
- `deviceProfile`

## `CompanionDeviceFilter`

Filter object used in association requests.

Currently supported constructors:

- `CompanionDeviceFilter.bluetooth(...)`
- `CompanionDeviceFilter.bluetoothLe(...)`

The first release focuses on address-based filters.

## `CompanionDeviceAssociation`

Represents a known association.

Fields:

- `associationId`
- `macAddress`
- `displayName`
- `deviceProfile`
- `selfManaged`
- `lastTimeConnectedMs`

## `CompanionDeviceEvent`

Represents the last background event.

Fields:

- `type`
- `timestampMs`
- `association`
- `rawPayload`

## Example callback

```dart
@pragma('vm:entry-point')
Future<void> companionDeviceWakeCallback() async {
  debugPrint('Companion device service woke the app');
}
```

