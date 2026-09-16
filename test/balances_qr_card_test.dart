import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/widgets/balances_qr_card.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'support/harness.dart';

const int seededGroup = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase(executor: NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> addUsers(int count, String Function(int i) name) =>
      db.transaction(() async {
        for (var i = 0; i < count; i++) {
          await db.usersDao.createUser(
            name: name(i),
            groupId: seededGroup,
            avatarEmoji: '🦊',
            seedColorArgb: 0xFF009688,
          );
        }
      });

  Future<void> pump(WidgetTester tester) async {
    // A portrait tablet.
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        screen: const Scaffold(
          body: SingleChildScrollView(child: BalancesQrCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgetsWithDatabase('shows a code with the user count', (tester) async {
    await addUsers(3, (i) => 'User $i');
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('3 users · '), findsOneWidget);
    expect(find.textContaining('bzip2'), findsOneWidget);
  });

  testWidgetsWithDatabase('shows a placeholder when the data does not fit', (
    tester,
  ) async {
    // Random names barely compress, so this is far past 2953 bytes.
    final random = Random(1);
    await addUsers(
      600,
      (i) => String.fromCharCodes([
        for (var c = 0; c < 24; c++) 97 + random.nextInt(26),
      ]),
    );
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('too many users'), findsOneWidget);
    expect(find.textContaining('600 users · '), findsOneWidget);
  });
}
