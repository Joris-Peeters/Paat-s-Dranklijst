import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../utils/avatar_photo.dart';
import '../utils/screen_dimming.dart';
import '../widgets/empty_state.dart';
import '../widgets/user_avatar.dart';
import '../widgets/user_theme_scope.dart';

/// Opens the camera and returns the confirmed photo, already shrunk to what a
/// user row stores, or null when backed out of.
///
/// Android and iOS only: check `cameraSupported` before offering it.
Future<Uint8List?> showCameraScreen(
  BuildContext context, {
  required int seedColorArgb,
}) => Navigator.push<Uint8List>(
  context,
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => UserThemeScope(
      seedColorArgb: seedColorArgb,
      child: const CameraScreen(),
    ),
  ),
);

enum _CameraProblem { unavailable, permissionDenied }

/// The self-timer's steps, in the order its button cycles through them.
enum _SelfTimer {
  off(0, Icons.timer_off_outlined),
  three(3, Icons.timer_3_outlined),
  ten(10, Icons.timer_10_outlined);

  const _SelfTimer(this.seconds, this.icon);

  final int seconds;
  final IconData icon;

  _SelfTimer get next => values[(index + 1) % values.length];
}

/// A live preview in the shape of the avatar it will become, then the result
/// to retry or keep.
///
/// Timer and flash start off on every visit, so the next person at the fridge
/// does not inherit someone else's 10 s timer.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.applyBrightness = applyScreenBrightness});

  /// How long the screen flash is lit before the shot, so exposure and white
  /// balance settle on the new light.
  static const screenFlashLead = Duration(seconds: 1);

  /// Drives the screen flash. Injectable so tests need no plugin.
  final ApplyBrightness applyBrightness;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  CameraController? _controller;
  _CameraProblem? _problem;

  /// The processed photo awaiting retry or confirm.
  Uint8List? _photo;
  bool _busy = false;

  /// Bumped whenever a controller is opened or dropped, so an `initialize`
  /// still in flight can tell it lost the race and dispose its own result.
  int _generation = 0;

  /// Set when the app went to the background and took the camera with it.
  bool _released = false;

  _SelfTimer _selfTimer = _SelfTimer.off;
  bool _flashOn = false;

  /// Seconds left on the self-timer, null when it is not running.
  int? _countdown;
  Timer? _ticker;

  /// Whether the screen is lit white as the front camera's flash.
  bool _screenFlash = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _ticker?.cancel();
    // On iOS the brightness is the system's, so leaving lit would leave the
    // iPad at full brightness.
    if (_screenFlash) {
      _screenFlash = false;
      unawaited(widget.applyBrightness(null));
    }
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera is not released for us: keeping it while in the background
    // leaves a black preview on return, or blocks other apps on Android.
    // Skipped while still initializing, because the permission prompt itself
    // makes the app inactive.
    if (state == AppLifecycleState.inactive) {
      _cancelCountdown();
      _endScreenFlash();
    }
    final controller = _controller;
    if (state == AppLifecycleState.inactive &&
        controller != null &&
        controller.value.isInitialized) {
      _generation++;
      _released = true;
      setState(() => _controller = null);
      unawaited(controller.dispose());
    } else if (state == AppLifecycleState.resumed && _released) {
      _released = false;
      unawaited(_open());
    }
  }

  Future<void> _start() async {
    try {
      _cameras = await availableCameras();
    } on CameraException {
      _cameras = const [];
    }
    if (!mounted) return;
    if (_cameras.isEmpty) {
      setState(() => _problem = _CameraProblem.unavailable);
      return;
    }
    // The selfie camera, since the person is usually photographing
    // themselves.
    final front = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    _cameraIndex = max(0, front);
    await _open();
  }

  Future<void> _open() async {
    final generation = ++_generation;
    final previous = _controller;
    if (previous != null) {
      setState(() => _controller = null);
      await previous.dispose();
    }

    final controller = CameraController(
      _cameras[_cameraIndex],
      // 720p: plenty for a 384 px avatar, and quick to decode in pure Dart.
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      // The tablet hangs portrait on the fridge.
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } on CameraException catch (e) {
      await controller.dispose();
      if (!mounted || generation != _generation) return;
      setState(
        () => _problem = e.code.startsWith('CameraAccess')
            ? _CameraProblem.permissionDenied
            : _CameraProblem.unavailable,
      );
      return;
    }
    if (!mounted || generation != _generation) {
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  Future<void> _switchCamera() async {
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _open();
  }

  /// The shutter: straight to [_capture], or through the self-timer.
  void _shoot() {
    final seconds = _selfTimer.seconds;
    if (seconds == 0) {
      unawaited(_capture());
      return;
    }
    setState(() => _countdown = seconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = _countdown! - 1;
      if (left > 0) {
        setState(() => _countdown = left);
        return;
      }
      _cancelCountdown();
      unawaited(_capture());
    });
  }

  void _cancelCountdown() {
    _ticker?.cancel();
    _ticker = null;
    if (_countdown != null) setState(() => _countdown = null);
  }

  void _endScreenFlash() {
    if (!_screenFlash) return;
    setState(() => _screenFlash = false);
    unawaited(widget.applyBrightness(null));
  }

  /// Set on every shot, so a controller rebuilt by a switch or a resume never
  /// keeps a stale mode, and the front camera never fires a flash of its own.
  static Future<void> _setFlashMode(
    CameraController controller, {
    required bool on,
  }) async {
    try {
      await controller.setFlashMode(on ? FlashMode.always : FlashMode.off);
    } on CameraException {
      // iOS refuses any flash mode on a camera without a flash; Android
      // accepts it silently. Either way the shot goes ahead without one.
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || controller.value.isTakingPicture) return;
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).photoProcessingFailed;
    // Front cameras on tablets almost never have a flash, and Android cannot
    // say whether one does, so the front camera always lights the screen.
    final front =
        controller.description.lensDirection == CameraLensDirection.front;
    final screenFlash = _flashOn && front;

    setState(() {
      _busy = true;
      _screenFlash = screenFlash;
    });
    try {
      final XFile file;
      try {
        await _setFlashMode(controller, on: _flashOn && !front);
        if (screenFlash) {
          await widget.applyBrightness(1.0);
          await Future<void>.delayed(CameraScreen.screenFlashLead);
          // Backgrounded while lit: the camera is gone and the shot with it.
          if (!mounted || _controller != controller) return;
        }
        file = await controller.takePicture();
      } finally {
        if (mounted) _endScreenFlash();
      }
      final captured = await file.readAsBytes();
      // The plugin leaves every capture in a temp folder, and a kiosk would
      // collect them for years.
      unawaited(_deleteQuietly(file.path));
      final photo = await processAvatarPhotoInBackground(captured);
      if (mounted) setState(() => _photo = photo);
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // A temp file the OS will clear eventually is not worth an error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final problem = _problem;
    // Settings for the next shot: locked while one is under way.
    final adjustable = _countdown == null && !_busy;
    final showSettings = problem == null && _photo == null;

    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text(l10n.cameraTitle),
        actions: [
          if (showSettings) ...[
            IconButton(
              style: IconButton.styleFrom(minimumSize: const Size.square(56)),
              tooltip: _flashOn ? l10n.flashOn : l10n.flashOff,
              icon: Icon(
                _flashOn ? Icons.flash_on_outlined : Icons.flash_off_outlined,
              ),
              onPressed: adjustable
                  ? () => setState(() => _flashOn = !_flashOn)
                  : null,
            ),
            IconButton(
              style: IconButton.styleFrom(minimumSize: const Size.square(56)),
              tooltip: l10n.selfTimer,
              icon: Icon(_selfTimer.icon),
              onPressed: adjustable
                  ? () => setState(() => _selfTimer = _selfTimer.next)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: SafeArea(
        child: problem != null
            ? EmptyState(
                icon: Icons.no_photography_outlined,
                message: switch (problem) {
                  _CameraProblem.unavailable => l10n.cameraUnavailable,
                  _CameraProblem.permissionDenied =>
                    l10n.cameraPermissionDenied,
                },
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  // Leaves room under the circle for the buttons.
                  final diameter = max(
                    0.0,
                    min(constraints.maxWidth, constraints.maxHeight - 128) - 32,
                  );
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 32,
                    children: [
                      _Circle(
                        diameter: diameter,
                        child: _circleContent(diameter),
                      ),
                      SizedBox(height: 80, child: _controls(l10n)),
                    ],
                  );
                },
              ),
      ),
    );

    return Stack(
      children: [
        scaffold,
        // A light source rather than a surface, so plain white whatever the
        // theme. Opaque to touches, so the shutter cannot be tapped twice.
        if (_screenFlash)
          const Positioned.fill(child: ColoredBox(color: Colors.white)),
      ],
    );
  }

  Widget _circleContent(double diameter) {
    final photo = _photo;
    if (photo != null) return Image.memory(photo, fit: BoxFit.cover);

    final controller = _controller;
    final colors = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller == null)
          ColoredBox(color: colors.surfaceContainerHighest)
        else
          // Fills the circle the way the photo will be cropped: the centre
          // square of the frame. `CameraPreview` sizes itself from the
          // constraints, so it gets a box of its own shape to cover with.
          LayoutBuilder(
            builder: (context, constraints) => FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: constraints.maxWidth,
                // Reported landscape; the screen is portrait.
                height: constraints.maxWidth * controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
            ),
          ),
        if (controller == null || _busy)
          Center(child: CircularProgressIndicator(color: colors.primary)),
        if (_countdown case final seconds?)
          Center(
            // White with a shadow rather than a theme colour: it sits on
            // whatever the camera sees.
            child: Text(
              '$seconds',
              style: TextStyle(
                fontSize: diameter * 0.4,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                height: 1.0,
                shadows: const [Shadow(blurRadius: 12)],
              ),
            ),
          ),
      ],
    );
  }

  Widget _controls(AppLocalizations l10n) {
    if (_photo != null) {
      // Taller than the default 40, for wet fingers.
      const buttonSize = Size(0, 56);
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 16,
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: buttonSize),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retryPhoto),
            onPressed: () => setState(() => _photo = null),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: buttonSize),
            icon: const Icon(Icons.check),
            label: Text(l10n.usePhoto),
            onPressed: () => Navigator.pop(context, _photo),
          ),
        ],
      );
    }

    final counting = _countdown != null;
    final ready = _controller != null && !_busy;
    final switchButton = IconButton.filledTonal(
      iconSize: 28,
      style: IconButton.styleFrom(minimumSize: const Size.square(56)),
      tooltip: l10n.switchCamera,
      icon: const Icon(Icons.cameraswitch_outlined),
      onPressed: ready && !counting ? () => unawaited(_switchCamera()) : null,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 24,
      children: [
        // Keeps the shutter centred opposite the switch button.
        const SizedBox.square(dimension: 56),
        IconButton.filled(
          iconSize: 40,
          style: IconButton.styleFrom(minimumSize: const Size.square(80)),
          tooltip: counting ? l10n.cancelTimer : l10n.takePhotoButton,
          icon: Icon(counting ? Icons.close : Icons.photo_camera),
          onPressed: counting
              ? _cancelCountdown
              : ready
              ? _shoot
              : null,
        ),
        if (_cameras.length > 1)
          switchButton
        else
          const SizedBox.square(dimension: 56),
      ],
    );
  }
}

/// The avatar's shape at full size: a circle ringed in the user's colour.
class _Circle extends StatelessWidget {
  const _Circle({required this.diameter, required this.child});

  final double diameter;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: diameter,
    height: diameter,
    // In front of the child, so the preview cannot paint over the ring.
    foregroundDecoration: ShapeDecoration(
      shape: CircleBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: avatarRingWidth(diameter),
        ),
      ),
    ),
    child: ClipOval(child: child),
  );
}
