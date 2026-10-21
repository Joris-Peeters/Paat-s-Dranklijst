import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// The frame both editors sit in: a dialog with a close button and one Save
/// action, opened with `showDialog` and awaited.
///
/// A Scaffold in a capped box rather than an `AlertDialog`, because these forms
/// are tall: a colour palette, a dropdown and a keyboard need a body that
/// scrolls. The Scaffold fills whatever it is allowed, hence the fixed cap.
class EditorDialog extends StatelessWidget {
  const EditorDialog({
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

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
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
      ),
    );
  }
}
