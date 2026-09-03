import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/empty_state.dart';
import 'settings_screen.dart';

/// Overview: summary stats and recent history. Not built yet.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navStart),
        actions: [
          // Settings hang off the Start page only.
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: l10n.settings,
            onPressed: () => openSettings(context),
          ),
        ],
      ),
      body: EmptyState(
        icon: Icons.receipt_long_rounded,
        message: l10n.startPlaceholder,
      ),
    );
  }
}
