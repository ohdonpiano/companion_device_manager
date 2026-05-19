# companion_device_manager_example

This app demonstrates the Android-only `companion_device_manager` plugin.

## What it shows

- association setup through Android Companion Device Manager
- callback registration for background wake-up events
- association listing and removal
- the latest persisted background event

## Running the example

Use a real Android device and run:

```bash
cd example
flutter run
```

Then follow the in-app instructions:

1. register the background callback
2. enter a Bluetooth MAC address
3. start the association flow
4. complete the Android chooser

## Notes

The example is intentionally minimal so it matches the plugin API and the documentation in the root `README.md` and the `docs/` folder.
