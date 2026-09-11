import 'dart:async';

import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/transaction_history.dart';
import '../widgets/user_edit_dialog.dart';
import '../widgets/user_header.dart';
import '../widgets/user_theme_scope.dart';
import 'consumption_screen.dart';

/// One user's page: where they stand, what they took, and the way to top up.
class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.user});

  final UserRow user;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late final AppDatabase _db = Database.of(context);

  // Watched rather than taken from the widget: the pencil in the app bar can
  // rename or recolour this very user, and a copy would leave the header and
  // the page's whole palette a step behind.
  late final Stream<UserRow?> _user = _db.usersDao.watchUser(widget.user.id);

  @override
  Widget build(BuildContext context) => StreamBuilder<UserRow?>(
    stream: _user,
    builder: (context, snapshot) {
      // The row passed in stands in until the query resolves, so nothing
      // flashes and the theme never starts on the wrong colour.
      final user = snapshot.data ?? widget.user;

      return UserThemeScope(
        seedColorArgb: user.seedColorArgb,
        child: _Page(user: user),
      );
    },
  );
}

class _Page extends StatelessWidget {
  const _Page({required this.user});

  final UserRow user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        // What the page is, not who: the name is already the largest thing on
        // it, and repeating it in the bar says nothing twice.
        title: Text(l10n.userOverview),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_cafe),
            tooltip: l10n.takeSomething,
            // Replaces rather than pushes: this page and that one are two views
            // of the same user, and both were opened from the user list, so
            // hopping between them must not stack up routes to back out of.
            onPressed: () => unawaited(
              Navigator.pushReplacement<void, void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ConsumptionScreen(user: user),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.edit,
            onPressed: () => unawaited(showUserEditDialog(context, user: user)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            UserHeader(user: user),
            RecentTransactionsCard(user: user),
            // Per-user statistics land under here.
          ],
        ),
      ),
    );
  }
}
