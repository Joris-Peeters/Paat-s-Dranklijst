import 'package:flutter/material.dart';

import '../data/stat_period.dart';
import '../l10n/app_localizations.dart';

String periodLabel(AppLocalizations l10n, StatPeriod period) =>
    switch (period) {
      StatPeriod.month => l10n.periodMonth,
      StatPeriod.year => l10n.periodYear,
      StatPeriod.all => l10n.periodAllTime,
    };

/// The month / year / all time switch over a statistics page.
class PeriodChips extends StatelessWidget {
  const PeriodChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final StatPeriod selected;
  final ValueChanged<StatPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final period in StatPeriod.values)
          ChoiceChip(
            label: Text(periodLabel(l10n, period)),
            selected: period == selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(period),
          ),
      ],
    );
  }
}
