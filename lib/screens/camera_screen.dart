import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../utils/avatar_photo.dart';
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

/// A live preview in the shape of the avatar it will become, then the result
/// to retry or keep.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

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
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera is not released for us: keeping it while in the background
    // leaves a black preview on return, or blocks other apps on Android.
    // Skipped while still initializing, because the permission prompt itself
    // makes the app inactive.
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

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || controller.value.isTakingPicture) return;
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).photoProcessingFailed;

    setState(() => _busy = true);
    try {
      final file = await controller.takePicture();
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cameraTitle)),
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
                      _Circle(diameter: diameter, child: _circleContent()),
                      SizedBox(height: 80, child: _controls(l10n)),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _circleContent() {
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

    final ready = _controller != null && !_busy;
    final switchButton = IconButton.filledTonal(
      iconSize: 28,
      style: IconButton.styleFrom(minimumSize: const Size.square(56)),
      tooltip: l10n.switchCamera,
      icon: const Icon(Icons.cameraswitch_outlined),
      onPressed: ready ? () => unawaited(_switchCamera()) : null,
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
          tooltip: l10n.takePhotoButton,
          icon: const Icon(Icons.photo_camera),
          onPressed: ready ? () => unawaited(_capture()) : null,
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
