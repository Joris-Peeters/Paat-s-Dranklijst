import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/empty_state.dart';

/// The member list — the app's primary action surface. The list itself is not
/// built yet; see `widgets/member_row.dart` for the row shape it will use.
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navUsers),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.search_rounded),
        //     tooltip: l10n.search,
        //     onPressed: () => (),
        //   ),
        // ],
      ),
      body: EmptyState(icon: Icons.people_rounded, message: l10n.noMembersYet),
    );
  }
}
