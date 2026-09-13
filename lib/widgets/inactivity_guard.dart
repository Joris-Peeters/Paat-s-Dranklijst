import 'dart:async';

import 'package:flutter/material.dart';

/// Calls [onTimeout] after a stretch without a single touch.
///
/// A safety net for someone walking away mid-flow, never something a flow
/// relies on: there is no countdown and no warning. It stays quiet while an
/// [InactivityPause] is mounted or a text field has focus, because typing on
/// the system keyboard produces no pointer events inside the app.
class InactivityGuard extends StatefulWidget {
  const InactivityGuard({
    super.key,
    required this.enabled,
    required this.onTimeout,
    required this.child,
  });

  static const timeout = Duration(seconds: 60);

  final bool enabled;
  final VoidCallback onTimeout;
  final Widget child;

  @override
  State<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends State<InactivityGuard> {
  Timer? _timer;

  /// A count rather than a bool, so overlapping pauses cannot release each
  /// other.
  int _pauses = 0;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _restart();
  }

  @override
  void didUpdateWidget(InactivityGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled == oldWidget.enabled) return;
    widget.enabled ? _restart() : _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart([Object? _]) {
    if (!widget.enabled) return;
    _timer?.cancel();
    _timer = Timer(InactivityGuard.timeout, _expire);
  }

  void _expire() {
    if (_pauses > 0 || _isTyping) {
      _restart();
      return;
    }
    // No new timer: nothing is left to return from until the next touch.
    widget.onTimeout();
  }

  /// Every `TextField` builds an `EditableText` around its focus node.
  static bool get _isTyping =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>() !=
      null;

  @override
  Widget build(BuildContext context) => _InactivityScope(
    state: this,
    // Translucent: sees every event without taking it from the widgets below.
    child: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _restart,
      onPointerMove: _restart,
      onPointerUp: _restart,
      onPointerHover: _restart,
      onPointerSignal: _restart,
      onPointerPanZoomStart: _restart,
      child: widget.child,
    ),
  );
}

class _InactivityScope extends InheritedWidget {
  const _InactivityScope({required this.state, required super.child});

  final _InactivityGuardState state;

  @override
  bool updateShouldNotify(_InactivityScope oldWidget) => false;
}

/// Holds the nearest [InactivityGuard] off for as long as this is mounted.
///
/// Does nothing without a guard above it.
class InactivityPause extends StatefulWidget {
  const InactivityPause({super.key, required this.child});

  final Widget child;

  @override
  State<InactivityPause> createState() => _InactivityPauseState();
}

class _InactivityPauseState extends State<InactivityPause> {
  _InactivityGuardState? _guard;

  @override
  void initState() {
    super.initState();
    // A plain lookup rather than a dependency, which is what makes it legal
    // in initState: the guard never changes identity, so nothing to rebuild on.
    _guard = context.getInheritedWidgetOfExactType<_InactivityScope>()?.state;
    _guard?._pauses++;
  }

  @override
  void dispose() {
    _guard?._pauses--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
