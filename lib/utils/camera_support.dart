import 'dart:io';

import 'package:flutter/foundation.dart';

import '../settings/settings_data.dart';

/// Forces [cameraSupported], so a test on the desktop host can see the camera
/// controls.
@visibleForTesting
bool? debugCameraSupportedOverride;

/// Whether this device can take a profile photo.
///
/// The camera plugin ships Android and iOS implementations only, and on
/// anything else the call throws at runtime rather than failing to compile.
bool get cameraSupported =>
    debugCameraSupportedOverride ?? (Platform.isAndroid || Platform.isIOS);

/// Whether a new photo may be taken here: a camera, and the admin allows it.
bool canTakePhotos(AppSettingsData settings) =>
    cameraSupported && settings.allowProfilePhotos;
