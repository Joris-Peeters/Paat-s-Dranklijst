import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/screens/users_screen.dart';

import 'support/harness.dart';

/// The seeded group, inserted by `onCreate`, so always id 1.
const int seededGroup = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase(executor: NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addUser({String name = 'Jonas', int groupId = seededGroup}) =>
      db.usersDao.createUser(
        name: name,
        groupId: groupId,
        avatarEmoji: '🦊',
        seedColorArgb: 0xFF009688,
      );

  Future<void> pump(
    WidgetTester tester, {
    Map<String, Object> preferences = const {},
  }) async {
    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        screen: const UsersScreen(),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgetsWithDatabase('the first group is selected by default', (
    tester,
  ) async {
    final leiding = await db.usersDao.createUserGroup(name: 'Leiding');
    await addUser(name: 'Bea');
    await addUser(name: 'Wout', groupId: leiding);
    await pump(tester);

    expect(find.text('Bea'), findsOneWidget);
    expect(find.text('Wout'), findsNothing);
  });

  testWidgetsWithDatabase('a chip switches which group is listed', (
    tester,
  ) async {
    final leiding = await db.usersDao.createUserGroup(name: 'Leiding');
    await addUser(name: 'Bea');
    await addUser(name: 'Wout', groupId: leiding);
    await pump(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Leiding'));
    await tester.pumpAndSettle();

    expect(find.text('Wout'), findsOneWidget);
    expect(find.text('Bea'), findsNothing);
  });

  testWidgetsWithDatabase('search hides the chips and crosses groups', (
    tester,
  ) async {
    final leiding = await db.usersDao.createUserGroup(name: 'Leiding');
    await addUser(name: 'Bea');
    await addUser(name: 'Wout', groupId: leiding);
    await pump(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNothing);

    await tester.enterText(find.byType(TextField), 'wou');
    await tester.pumpAndSettle();

    // Found even though its group is not the selected one.
    expect(find.text('Wout'), findsOneWidget);
    expect(find.text('Bea'), findsNothing);
  });

  testWidgetsWithDatabase('a search matching nobody says so', (tester) async {
    await addUser(name: 'Bea');
    await pump(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('Nobody found'), findsOneWidget);
  });

  testWidgetsWithDatabase('closing search brings the chips back', (
    tester,
  ) async {
    await addUser(name: 'Bea');
    await pump(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsOneWidget);
    expect(find.text('Bea'), findsOneWidget);
  });

  testWidgetsWithDatabase('an archived user is not listed', (tester) async {
    await db.usersDao.archiveUser(await addUser(name: 'Jonas'));
    await addUser(name: 'Bea');
    await pump(tester);

    expect(find.text('Jonas'), findsNothing);
    expect(find.text('Bea'), findsOneWidget);
  });

  testWidgetsWithDatabase('the balance shows on the tile', (tester) async {
    final id = await addUser(name: 'Bea');
    await db.transactionsDao.logTopUp(userId: id, amountMinorUnits: 450);
    await pump(tester);

    expect(find.text('€4.50'), findsOneWidget);
  });

  // Two tests rather than one with two pumps: AppSettings reads the store in
  // initState, and pumping a second one of the same type reuses that State, so
  // the setting would never appear to change.
  testWidgetsWithDatabase('no add button when self-registration is off', (
    tester,
  ) async {
    await addUser(name: 'Bea');
    await pump(tester, preferences: {'allowSelfRegistration': false});

    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgetsWithDatabase('an add button when self-registration is on', (
    tester,
  ) async {
    await addUser(name: 'Bea');
    await pump(tester, preferences: {'allowSelfRegistration': true});

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
