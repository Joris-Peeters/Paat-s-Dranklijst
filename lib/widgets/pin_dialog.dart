import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';

/// The admin PIN is always exactly this many digits, everywhere.
const pinLength = 4;

/// Asks for a new PIN twice. Resolves to the confirmed PIN, or null if dismissed.
Future<String?> showPinSetDialog(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _PinSetDialog());

/// Asks for the admin PIN. Pops `true` on a match, `null` if dismissed.
///
/// The comparison is a plain string equality against the stored plaintext PIN.
/// No hashing, no attempt limit, no lockout: this gate stops idle curiosity,
/// and anyone with physical access can read the database anyway.
class PinEnterDialog extends StatefulWidget {
  const PinEnterDialog({super.key, required this.expectedPin});

  final String expectedPin;

  @override
  State<PinEnterDialog> createState() => _PinEnterDialogState();
}

class _PinEnterDialogState extends State<PinEnterDialog> {
  String? _error;

  bool _check(String pin) {
    if (pin != widget.expectedPin) {
      setState(() => _error = AppLocalizations.of(context).pinIncorrect);
      return false;
    }
    unawaited(_close());
    return true;
  }

  /// Long enough for the fourth dot to paint before the dialog leaves.
  Future<void> _close() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.enterPin),
      content: _PinPad(onCompleted: _check, error: _error),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

/// Asks for a new PIN, then for it again. Pops the PIN, or `null` if dismissed.
class _PinSetDialog extends StatefulWidget {
  const _PinSetDialog();

  @override
  State<_PinSetDialog> createState() => _PinSetDialogState();
}

class _PinSetDialogState extends State<_PinSetDialog> {
  String? _first;
  String? _error;

  /// Bumped only when moving on to the confirmation, so the pad below gets a
  /// new key and therefore fresh, empty state. On a mismatch the key stays put
  /// on purpose: the same pad instance has to shake before it clears.
  int _round = 0;

  bool _accept(String pin) {
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
        _round++;
      });
      return true;
    }

    if (pin != _first) {
      setState(() {
        _first = null;
        _error = AppLocalizations.of(context).pinMismatch;
      });
      return false;
    }

    Navigator.pop(context, pin);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(_first == null ? l10n.pinChooseTitle : l10n.pinConfirmTitle),
      content: _PinPad(
        key: ValueKey(_round),
        onCompleted: _accept,
        error: _error,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

const _keySize = 88.0;
const _keySpacing = 16.0;

/// The dots-over-keypad PIN entry, shaped after a phone's lock screen: no text
/// field, no soft keyboard, targets big enough for wet fingers.
class _PinPad extends StatefulWidget {
  const _PinPad({super.key, required this.onCompleted, this.error});

  /// Called once [pinLength] digits are in. Return **false** to reject them:
  /// the dots shake and clear. Return **true** to accept — the pad keeps its
  /// filled dots and the caller takes over (popping, or swapping in a fresh pad
  /// through `key`).
  final bool Function(String pin) onCompleted;

  final String? error;

  @override
  State<_PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<_PinPad> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    duration: const Duration(milliseconds: 400),
    vsync: this,
  );

  String _digits = '';

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _append(String digit) {
    // Ignore taps between the last digit and whatever the caller decides.
    if (_digits.length >= pinLength) return;

    setState(() => _digits += digit);
    if (_digits.length == pinLength && !widget.onCompleted(_digits)) {
      _reject();
    }
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  void _reject() {
    setState(() => _digits = '');
    unawaited(_shake.forward(from: 0));
    if (Platform.isAndroid || Platform.isIOS) {
      unawaited(HapticFeedback.heavyImpact());
    }
  }

  /// Lets a physical keyboard drive the pad — mostly for desktop development.
  /// Anything else falls through, so Esc still dismisses the dialog.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }

    final digit = event.character;
    if (digit != null && digit.length == 1 && '0123456789'.contains(digit)) {
      _append(digit);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _shake,
            // A decaying sine: three swings out and back, fading to nothing.
            builder: (context, child) => Transform.translate(
              offset: Offset(
                sin(_shake.value * pi * 6) * 12 * (1 - _shake.value),
                0,
              ),
              child: child,
            ),
            child: _PinDots(filled: _digits.length),
          ),
          // Always laid out, so the dialog does not resize when an error
          // appears. `bodyMedium` has a line height; an empty string keeps it.
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 20),
            child: Text(
              widget.error ?? '',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          for (final row in const ['123', '456', '789'])
            Padding(
              padding: const EdgeInsets.only(bottom: _keySpacing),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: _keySpacing,
                children: [
                  for (final digit in row.split(''))
                    _Key(onTap: () => _append(digit), child: Text(digit)),
                ],
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: _keySpacing,
            children: [
              // Keeps the zero centred under the 2, 5 and 8.
              const SizedBox(width: _keySize, height: _keySize),
              _Key(onTap: () => _append('0'), child: const Text('0')),
              _Key(
                onTap: _digits.isEmpty ? null : _backspace,
                child: const Icon(Icons.backspace_outlined, size: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.filled});

  final int filled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 20,
      children: [
        for (var i = 0; i < pinLength; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? colors.primary : Colors.transparent,
              border: Border.all(
                color: i < filled ? colors.primary : colors.outline,
                width: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}

/// One round key of the pad. A null [onTap] greys it out rather than removing
/// it, so the grid never shifts under a finger.
class _Key extends StatelessWidget {
  const _Key({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
    onPressed: onTap,
    style: FilledButton.styleFrom(
      shape: const CircleBorder(),
      minimumSize: const Size(_keySize, _keySize),
      textStyle: Theme.of(context).textTheme.headlineMedium,
    ),
    child: child,
  );
}
