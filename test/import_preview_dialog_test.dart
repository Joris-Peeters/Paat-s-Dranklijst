import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/balance_csv.dart';
import 'package:paats_dranklijst/data/balance_import.dart';
import 'package:paats_dranklijst/data/daos/users_dao.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/screens/import_balances_screen.dart';

import 'support/harness.dart';

void main() {
  final general = UserGroupRow(
    id: 1,
    name: 'General',
    sortOrder: 0,
    createdAt: DateTime(2026),
  );
  final jonas = UserWithBalance(
    user: UserRow(
      id: 1,
      name: 'Jonas',
      avatarEmoji: '🦊',
      seedColorArgb: 0xFF009688,
      groupId: 1,
      sortOrder: 0,
      createdAt: DateTime(2026),
    ),
    group: general,
    balanceMinorUnits: -500,
  );

  BalanceImportPlan plan(String csv) {
    final parsed = parseBalancesCsv(csv, decimalDigits: 2);
    return planBalanceImport(
      rows: parsed.rows,
      csvErrors: parsed.errors,
      users: [jonas],
      groups: [general],
    );
  }

  Future<void> show(WidgetTester tester, BalanceImportPlan plan) async {
    // A portrait tablet, where the dialog has to fit a long list.
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      await settingsHarness(
        ImportPreviewDialog(fileName: 'balances.csv', plan: plan),
      ),
    );
  }

  FilledButton importButton(WidgetTester tester) =>
      tester.widget(find.widgetWithText(FilledButton, 'Import'));

  testWidgets('lists what would change and allows the import', (tester) async {
    final rows = [
      'name,group,balance',
      'jonas,General,2.50',
      for (var i = 0; i < 60; i++) 'User $i,Oud-leiding,-1',
    ];
    await show(tester, plan(rows.join('\n')));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('60 new users'), findsOneWidget);
    expect(find.text('Jonas'), findsOneWidget);
    expect(find.text('-€5.00 → €2.50'), findsOneWidget);
    expect(importButton(tester).onPressed, isNotNull);
  });

  testWidgets('shows every problem and blocks the import', (tester) async {
    await show(
      tester,
      plan('name,group,balance\nWout,A,x\nMira,A,1\nmira,B,2\n'),
    );

    expect(find.text('• Line 2: "x" is not an amount.'), findsOneWidget);
    expect(
      find.text('• "Mira" appears more than once, on lines 3, 4.'),
      findsOneWidget,
    );
    expect(importButton(tester).onPressed, isNull);
  });

  testWidgets('a file that changes nothing cannot be imported', (tester) async {
    await show(tester, plan('name,group,balance\nJonas,General,-5\n'));
    expect(find.textContaining('nothing to import'), findsOneWidget);
    expect(importButton(tester).onPressed, isNull);
  });
}
