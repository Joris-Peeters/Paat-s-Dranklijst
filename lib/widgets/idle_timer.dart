import 'dart:async';

import 'package:flutter/material.dart';

/// Calls [onIdle] once [timeout] has passed without a single touch anywhere
/// below it.
///
/// The piece `InactivityGuard` and `ScreenDimmer` share: one of them sends the
/// app back to Start after a minute, the other dims the backlight after a much
/// longer stretch, and both hang off the same pointer stream.
///
/// Firing schedules nothing — the timer is dormant until the next touch, since
/// whatever [onIdle] did stands until someone comes back.
class IdleTimer extends StatefulWidget {
  const IdleTimer({
    super.key,
    required this.enabled,
    required this.timeout,
    required this.onIdle,
    this.onActivity,
    this.canFire,
    required this.child,
  });

  final bool enabled;
  final Duration timeout;
  final VoidCallback onIdle;

  /// Every touch, idle or not, for a caller that has something to undo.
  final VoidCallback? onActivity;

  /// Checked when the timeout is up. False re-arms a whole new timeout instead
  /// of firing, so a blocked moment costs the full wait again rather than
  /// firing the instant it clears.
  final ValueGetter<bool>? canFire;

  final Widget child;

  @override
  State<IdleTimer> createState() => _IdleTimerState();
}

class _IdleTimerState extends State<IdleTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _restart();
  }

  @override
  void didUpdateWidget(IdleTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled == oldWidget.enabled &&
        widget.timeout == oldWidget.timeout) {
      return;
    }
    widget.enabled ? _restart() : _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Takes the event it is handed so it can be a pointer callback as well as a
  /// bare restart.
  void _touch(PointerEvent _) {
    widget.onActivity?.call();
    _restart();
  }

  void _restart() {
    if (!widget.enabled) return;
    _timer?.cancel();
    _timer = Timer(widget.timeout, _expire);
  }

  void _expire() {
    if (widget.canFire?.call() == false) {
      _restart();
      return;
    }
    widget.onIdle();
  }

  @override
  // Translucent: sees every event without taking it from the widgets below.
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _touch,
    onPointerMove: _touch,
    onPointerUp: _touch,
    onPointerHover: _touch,
    onPointerSignal: _touch,
    onPointerPanZoomStart: _touch,
    child: widget.child,
  );
}
