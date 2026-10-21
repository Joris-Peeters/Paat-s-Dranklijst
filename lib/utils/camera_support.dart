import 'dart:io';

/// Whether this device can take a profile photo.
///
/// The camera plugin ships Android and iOS implementations only, and on
/// anything else the call throws at runtime rather than failing to compile.
bool get cameraSupported => Platform.isAndroid || Platform.isIOS;
