import 'package:flutter/material.dart';

import 'card_heading.dart';

/// One statistic in a card: a heading and whatever draws it.
class StatsCard extends StatelessWidget {
  const StatsCard({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    child: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeading(icon: icon, label: label),
          child,
        ],
      ),
    ),
  );
}
