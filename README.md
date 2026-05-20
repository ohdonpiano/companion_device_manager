# companion_device_manager

An Android-only Flutter plugin that wraps the Android
[Companion Device Manager](https://developer.android.com/reference/android/companion/CompanionDeviceManager)
API and provides a simple Dart-facing association flow plus a background wake callback.

## Features

- Android-only companion device association flow
- typed Dart models for requests, associations, and events
- background callback registration for device-appearance wake-ups
- reactive stream for real-time `device_appeared` / `device_disappeared` events
- stored last background event for post-wake inspection
- example app showing the complete flow

## Supported platforms

- Android: supported
- iOS: not supported
- Desktop: not supported
- Web: not supported

## Documentation

Detailed design and implementation notes live in the `docs/` folder:

- `docs/project-architecture.md`
- `docs/public-api.md`
- `docs/example-app.md`

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  companion_device_manager:
	path: ../companion_device_manager
```

Or, for a published version:

```yaml
dependencies:
  companion_device_manager: ^0.2.0
```

## Basic usage

```dart
import 'package:companion_device_manager/companion_device_manager.dart';

final manager = CompanionDeviceManager();

@pragma('vm:entry-point')
Future<void> companionDeviceWakeCallback() async {
  print('Companion device wake callback invoked');
}

Future<void> setup() async {
  final available = await manager.isAvailable();
  if (!available) {
	return;
  }

  await manager.registerBackgroundCallback(companionDeviceWakeCallback);

  final association = await manager.associate(
	CompanionDeviceAssociationRequest(
	  displayName: 'My Companion Device',
	  filters: <CompanionDeviceFilter>[
    CompanionDeviceFilter.bluetoothLe(address: '00:11:22:33:44:55'),
	  ],
	),
  );

  print('Associated device: ${association.macAddress}');
}

void watchBackgroundEvents() {
  // Note: this stream only emits events while the app is running in foreground.
  // To react to events when the app is backgrounded or killed, use the background callback.
  manager.backgroundEvents.listen((event) {
    print('Companion event: ${event.type} at ${event.timestamp}');
  });
}
```

## Background callback requirements

The callback passed to `registerBackgroundCallback` must be:

- a top-level or static function
- annotated with `@pragma('vm:entry-point')`

Additionally, when the callback is invoked in a headless Flutter engine (after app wake from device presence):

- call `WidgetsFlutterBinding.ensureInitialized()` early in the callback body
- call `ui.DartPluginRegistrant.ensureInitialized()` to ensure all plugins (including this one) are ready for method channel calls

Example:

```dart
@pragma('vm:entry-point')
Future<void> companionDeviceWakeCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  import 'dart:ui' as ui;
  ui.DartPluginRegistrant.ensureInitialized();
  
  // Now you can safely call plugin methods
  final manager = CompanionDeviceManager();
  final lastEvent = await manager.getLastBackgroundEvent();
  // ...
}
```

This is required because Android may need to start a headless Flutter engine when the companion device service wakes the app.

## Example app

The example app shows how to:

- register and clear the background callback
- start an association request
- react to real-time `backgroundEvents` while the app is running
- inspect current associations
- read the last persisted background event

Run it with:

```bash
cd example
flutter run
```

## Android notes

The plugin targets Android devices that support Companion Device Manager.

Depending on the device type you are pairing with, you may also need Bluetooth-related runtime permissions in the host app.

Use `CompanionDeviceFilter.bluetoothLe(...)` for BLE peripherals and `CompanionDeviceFilter.bluetooth(...)` for classic Bluetooth devices.

The first version of the plugin focuses on Bluetooth address-based filters to keep the API simple and predictable.

### Event delivery

- **When app is running in foreground**: subscribe to `manager.backgroundEvents` stream for real-time `device_appeared` and `device_disappeared` events.
- **When app is backgrounded or killed**: the `CompanionDeviceService` broadcasts events to the background callback (if registered).
- **Persisted events**: the last event payload is always stored on device and can be retrieved via `getLastBackgroundEvent()`.
- **Stream and persistence are synchronized**: both paths use the same native event source, so the UI stays in sync.

## Publishing checklist

Before publishing to pub.dev, verify that:

- the example app works on a real Android device
- the background callback is documented in the host app README
- the version is bumped appropriately
- the Android-only support statement stays visible
- the docs folder remains in sync with the public API

