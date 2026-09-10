import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// The frame both editors sit in: a full-screen dialog with a close button and
/// one Save action.
///
/// Full screen rather than an `AlertDialog` because these forms are tall — a
/// colour palette, a dropdown and a keyboard do not share a phone-sized dialog
/// well. It is still opened with `showDialog` and awaited like one.
class FullScreenEditor extends StatelessWidget {
  const FullScreenEditor({
    super.key,
    required this.title,
    required this.onSave,
    required this.child,
  });

  final String title;

  /// Null disables the Save action, which is how an incomplete form is
  /// refused: nothing to dismiss, nothing to explain.
  final VoidCallback? onSave;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.cancel,
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(title),
          actions: [
            TextButton(onPressed: onSave, child: Text(l10n.save)),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: child,
          ),
        ),
      ),
    );
  }
}
