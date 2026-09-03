import 'package:flutter/material.dart';

/// A centred icon and message for a screen with nothing in it yet.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
