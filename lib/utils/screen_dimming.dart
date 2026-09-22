import 'dart:io';

import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// Whether this device can dim its own backlight.
///
/// The plugin ships Android and iOS implementations only, and on anything else
/// the call throws at runtime rather than failing to compile.
bool get screenDimmingSupported => Platform.isAndroid || Platform.isIOS;

/// Sets the screen to [brightness], or hands it back to the device when null.
///
/// Android applies this to the app's own window and takes it back by itself.
/// iOS has no per-app brightness, so this moves the system one and the app has
/// to put it back — which is why nothing may leave the screen dimmed.
typedef ApplyBrightness = Future<void> Function(double? brightness);

Future<void> applyScreenBrightness(double? brightness) async {
  if (!screenDimmingSupported) return;
  try {
    if (brightness == null) {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } else {
      await ScreenBrightness.instance.setApplicationScreenBrightness(
        brightness,
      );
    }
  } on PlatformException {
    // A backlight the device will not hand over is not worth a crash on a
    // screen nobody is looking at.
  }
}
