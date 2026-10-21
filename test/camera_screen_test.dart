import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:paats_dranklijst/l10n/app_localizations.dart';
import 'package:paats_dranklijst/screens/camera_screen.dart';

const _front = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 270,
);
const _back = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

/// Just enough of a camera for `CameraController`: it opens, previews
/// nothing, and records the flash modes and shots it is asked for.
class _FakeCamera extends CameraPlatform {
  _FakeCamera({this.hasFlash = true});

  /// Without one, a flash mode is refused, as iOS does.
  final bool hasFlash;

  final flashModes = <FlashMode>[];
  int pictures = 0;

  /// Called as a picture is taken, to look at the screen at that moment.
  VoidCallback? onTakePicture;

  final _initialized = StreamController<CameraInitializedEvent>.broadcast();
  final _never = StreamController<Never>.broadcast();
  int _nextId = 0;

  @override
  Future<List<CameraDescription>> availableCameras() async => const [
    _front,
    _back,
  ];

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async => _nextId++;

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _initialized.stream.where((e) => e.cameraId == cameraId);

  // Never emitting rather than empty: the controller takes `.first` of both.
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _never.stream.cast();

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      _never.stream.cast();

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    _initialized.add(
      CameraInitializedEvent(
        cameraId,
        1280,
        720,
        ExposureMode.auto,
        false,
        FocusMode.auto,
        false,
      ),
    );
  }

  @override
  Future<void> lockCaptureOrientation(
    int cameraId,
    DeviceOrientation orientation,
  ) async {}

  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {
    if (!hasFlash) {
      throw CameraException('setFlashModeFailed', 'No flash');
    }
    flashModes.add(mode);
  }

  @override
  Future<XFile> takePicture(int cameraId) async {
    pictures++;
    onTakePicture?.call();
    return XFile.fromData(img.encodeJpg(img.Image(width: 64, height: 48)));
  }

  @override
  Widget buildPreview(int cameraId) => const SizedBox.expand();

  @override
  Future<void> dispose(int cameraId) async {}
}

void main() {
  late _FakeCamera camera;
  late List<double?> brightness;

  setUp(() {
    camera = _FakeCamera();
    CameraPlatform.instance = camera;
    brightness = [];
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CameraScreen(
          applyBrightness: (value) async => brightness.add(value),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Opaque white over the whole screen, app bar included.
  final overlay = find.byWidgetPredicate(
    (w) => w is ColoredBox && w.color == Colors.white,
  );

  Future<void> tapShutter(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Take photo'));
    await tester.pump();
  }

  Future<void> switchCamera(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Switch camera'));
    await tester.pumpAndSettle();
  }

  testWidgets('both start off: no countdown, no flash', (tester) async {
    await pump(tester);

    expect(find.byIcon(Icons.timer_off_outlined), findsOneWidget);
    expect(find.byTooltip('Flash off'), findsOneWidget);

    await tapShutter(tester);
    expect(camera.pictures, 1);
    expect(overlay, findsNothing);
    expect(brightness, isEmpty);
    expect(camera.flashModes, [FlashMode.off]);
  });

  testWidgets('the timer button steps through off, 3 s and 10 s', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Self-timer'));
    await tester.pump();
    expect(find.byIcon(Icons.timer_3_outlined), findsOneWidget);

    await tester.tap(find.byTooltip('Self-timer'));
    await tester.pump();
    expect(find.byIcon(Icons.timer_10_outlined), findsOneWidget);

    await tester.tap(find.byTooltip('Self-timer'));
    await tester.pump();
    expect(find.byIcon(Icons.timer_off_outlined), findsOneWidget);
  });

  testWidgets('a 3 s timer counts down, then takes the picture', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Self-timer'));
    await tapShutter(tester);

    expect(find.text('3'), findsOneWidget);
    expect(find.byTooltip('Cancel timer'), findsOneWidget);
    // Nothing about the shot can change once it is counting.
    final flash = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.flash_off_outlined),
    );
    expect(flash.onPressed, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1'), findsOneWidget);
    expect(camera.pictures, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(camera.pictures, 1);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('cancelling the countdown takes no picture', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Self-timer'));
    await tapShutter(tester);
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byTooltip('Cancel timer'));
    await tester.pump(const Duration(seconds: 5));

    expect(camera.pictures, 0);
    expect(find.text('2'), findsNothing);
    expect(find.byTooltip('Take photo'), findsOneWidget);
  });

  testWidgets('the front camera flashes the screen, then gives it back', (
    tester,
  ) async {
    var litAtShot = false;
    camera.onTakePicture = () =>
        litAtShot = overlay.evaluate().isNotEmpty && brightness.last == 1.0;
    await pump(tester);
    await tester.tap(find.byTooltip('Flash off'));
    await tester.pump();
    expect(find.byTooltip('Flash on'), findsOneWidget);

    await tapShutter(tester);
    expect(overlay, findsOneWidget);
    expect(brightness, [1.0]);
    // The light has to be up before the shot, for exposure to settle.
    expect(camera.pictures, 0);

    await tester.pump(CameraScreen.screenFlashLead);
    expect(camera.pictures, 1);
    expect(litAtShot, isTrue);
    expect(overlay, findsNothing);
    expect(brightness, [1.0, null]);
    // The front camera's own flash, if any, stays off.
    expect(camera.flashModes, [FlashMode.off]);
  });

  testWidgets('the back camera fires its own flash instead', (tester) async {
    await pump(tester);
    await switchCamera(tester);
    await tester.tap(find.byTooltip('Flash off'));
    await tester.pump();

    await tapShutter(tester);

    expect(camera.pictures, 1);
    expect(camera.flashModes, [FlashMode.always]);
    expect(overlay, findsNothing);
    expect(brightness, isEmpty);
  });

  testWidgets('a back camera without a flash still takes the picture', (
    tester,
  ) async {
    CameraPlatform.instance = camera = _FakeCamera(hasFlash: false);
    await pump(tester);
    await switchCamera(tester);
    await tester.tap(find.byTooltip('Flash off'));
    await tester.pump();

    await tapShutter(tester);

    expect(camera.pictures, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('leaving mid-flash hands the brightness back', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Flash off'));
    await tapShutter(tester);
    expect(brightness, [1.0]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(CameraScreen.screenFlashLead);

    expect(brightness, [1.0, null]);
    expect(camera.pictures, 0);
  });

  testWidgets('a second visit starts with both off again', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Flash off'));
    await tester.tap(find.byTooltip('Self-timer'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await pump(tester);

    expect(find.byTooltip('Flash off'), findsOneWidget);
    expect(find.byIcon(Icons.timer_off_outlined), findsOneWidget);
  });
}
