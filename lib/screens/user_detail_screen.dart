import 'package:flutter/material.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../widgets/empty_state.dart';
import '../widgets/user_theme_scope.dart';

/// One user's page — balance, history and settling up. Not built yet.
class UserDetailScreen extends StatelessWidget {
  const UserDetailScreen({super.key, required this.user});

  final UserRow user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return UserThemeScope(
      seedColorArgb: user.seedColorArgb,
      child: Scaffold(
        appBar: AppBar(title: Text(user.name)),
        body: EmptyState(icon: Icons.person_rounded, message: l10n.balance),
      ),
    );
  }
}
