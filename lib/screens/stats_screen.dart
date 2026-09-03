import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/empty_state.dart';

/// Statistics. Not built yet.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navStats)),
      body: EmptyState(
        icon: Icons.bar_chart_rounded,
        message: l10n.statsPlaceholder,
      ),
    );
  }
}
