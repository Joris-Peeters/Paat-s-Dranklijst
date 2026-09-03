import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

/// Stand-in for a management area whose CRUD screen does not exist yet.
class ManagementStubScreen extends StatelessWidget {
  const ManagementStubScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.emptyMessage,
  });

  final String title;
  final IconData icon;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: EmptyState(icon: icon, message: emptyMessage),
  );
}
