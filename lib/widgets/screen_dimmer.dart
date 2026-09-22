import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/screen_dimming.dart';
import 'idle_timer.dart';

/// Drops the backlight after [delay] without a touch, and brings it back on the
/// next one.
///
/// For a tablet configured never to sleep: the device keeps the screen on, and
/// this keeps it from burning at full brightness all night. A device left on its
/// own auto-lock wants this off instead, so it is a setting.
///
/// Unlike the return-to-Start guard it honours no pauses — nobody is watching a settings
/// screen for half an hour either.
class ScreenDimmer extends StatefulWidget {
  const ScreenDimmer({
    super.key,
    required this.enabled,
    required this.delay,
    this.applyBrightness = applyScreenBrightness,
    required this.child,
  });

  /// Works great on iPad, other devices may differ
  static const dimLevel = 0.05;

  final bool enabled;
  final Duration delay;

  /// Seam for tests, which have no backlight to move.
  final ApplyBrightness applyBrightness;

  final Widget child;

  @override
  State<ScreenDimmer> createState() => _ScreenDimmerState();
}

class _ScreenDimmerState extends State<ScreenDimmer>
    with WidgetsBindingObserver {
  bool _dimmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(ScreenDimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching the feature off in settings must not leave the screen dark.
    if (!widget.enabled) _wake();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Not through _wake: setState is gone, and iOS would keep the dimmed
    // system brightness if nothing gave it back.
    if (_dimmed) unawaited(widget.applyBrightness(null));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Anything but resumed means the screen is no longer ours to dim, and on
    // iOS the brightness is the system's own.
    if (state != AppLifecycleState.resumed) _wake();
  }

  void _dim() {
    if (_dimmed) return;
    setState(() => _dimmed = true);
    unawaited(widget.applyBrightness(ScreenDimmer.dimLevel));
  }

  void _wake() {
    if (!_dimmed) return;
    setState(() => _dimmed = false);
    unawaited(widget.applyBrightness(null));
  }

  @override
  Widget build(BuildContext context) => IdleTimer(
    enabled: widget.enabled,
    timeout: widget.delay,
    onIdle: _dim,
    onActivity: _wake,
    // Inside the timer, so the waking touch still counts as activity. The
    // absorber takes the hit test itself, so that one touch wakes the screen
    // and reaches nothing underneath: nobody logs a drink by rousing a dark
    // tablet.
    child: AbsorbPointer(absorbing: _dimmed, child: widget.child),
  );
}
