import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/screens/users_screen.dart';
import 'package:paats_dranklijst/widgets/user_avatar.dart';

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
    bool active = true,
  }) async {
    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        screen: UsersScreen(active: active),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addItem(String name) => db.itemsDao.createItem(
    name: name,
    groupId: seededGroup,
    priceMinorUnits: 200,
    emoji: '🍺',
  );

  FilledButton nextButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'));

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

  testWidgetsWithDatabase('opening the drink screen closes the search', (
    tester,
  ) async {
    await addUser(name: 'Bea');
    await pump(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'be');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bea'));
    // Mid-transition the list underneath is left alone, so it does not snap
    // back to the chips just as the page slides over it.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(TextField), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Add to your tab'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ChoiceChip), findsOneWidget);
  });

  testWidgetsWithDatabase('opening a user page closes the search', (
    tester,
  ) async {
    await addUser(name: 'Bea');
    await pump(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'be');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(UserAvatar));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ChoiceChip), findsOneWidget);
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

  group('selecting several people', () {
    testWidgetsWithDatabase('is off until asked for: a tap opens the drink '
        'screen', (tester) async {
      await addUser(name: 'Bea');
      await pump(tester);

      expect(find.textContaining('selected'), findsNothing);
      await tester.tap(find.text('Bea'));
      await tester.pumpAndSettle();

      expect(find.text('Add to your tab'), findsOneWidget);
    });

    testWidgetsWithDatabase('the button starts it, and Next needs two people', (
      tester,
    ) async {
      await addUser(name: 'Bea');
      await addUser(name: 'Wout');
      await pump(tester);

      await tester.tap(find.byTooltip('Select several people'));
      await tester.pumpAndSettle();
      expect(find.text('Nobody selected'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.text('Bea'));
      await tester.pumpAndSettle();
      expect(find.text('1 person selected'), findsOneWidget);
      expect(nextButton(tester).onPressed, isNull);

      await tester.tap(find.text('Wout'));
      await tester.pumpAndSettle();
      expect(find.text('2 people selected'), findsOneWidget);
      expect(nextButton(tester).onPressed, isNotNull);

      await tester.tap(find.text('Wout'));
      await tester.pumpAndSettle();
      expect(find.text('1 person selected'), findsOneWidget);
    });

    testWidgetsWithDatabase('a long press starts it with that person ticked', (
      tester,
    ) async {
      await addUser(name: 'Bea');
      await pump(tester);

      await tester.longPress(find.text('Bea'));
      await tester.pumpAndSettle();

      expect(find.text('1 person selected'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgetsWithDatabase('ticks survive switching groups', (tester) async {
      final leiding = await db.usersDao.createUserGroup(name: 'Leiding');
      await addUser(name: 'Bea');
      await addUser(name: 'Wout', groupId: leiding);
      await pump(tester);

      await tester.longPress(find.text('Bea'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Leiding'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wout'));
      await tester.pumpAndSettle();

      expect(find.text('2 people selected'), findsOneWidget);
    });

    testWidgetsWithDatabase('Cancel and Back both end it', (tester) async {
      await addUser(name: 'Bea');
      await pump(tester);

      await tester.longPress(find.text('Bea'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(find.textContaining('selected'), findsNothing);

      await tester.longPress(find.text('Bea'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.textContaining('selected'), findsNothing);
    });

    testWidgetsWithDatabase('leaving the tab ends it', (tester) async {
      await addUser(name: 'Bea');
      await pump(tester);
      await tester.longPress(find.text('Bea'));
      await tester.pumpAndSettle();

      // Pumping the same tree again keeps the State, as switching tabs does.
      await pump(tester, active: false);
      await pump(tester);

      expect(find.textContaining('selected'), findsNothing);
    });

    testWidgetsWithDatabase(
      'Next, then a drink, logs for everyone and ends selecting',
      (tester) async {
        await addItem('Beer');
        final bea = await addUser(name: 'Bea');
        final wout = await addUser(name: 'Wout');
        await pump(tester);

        await tester.longPress(find.text('Bea'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Wout'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        expect(find.text('Add to 2 tabs'), findsOneWidget);
        await tester.tap(find.text('Beer'));
        await tester.pumpAndSettle();

        expect(await db.usersDao.readBalance(bea), -200);
        expect(await db.usersDao.readBalance(wout), -200);
        expect(find.textContaining('selected'), findsNothing);
        expect(find.text('Beer registered for 2 people'), findsOneWidget);
      },
    );

    testWidgetsWithDatabase('backing out of the drink screen keeps the ticks', (
      tester,
    ) async {
      await addItem('Beer');
      await addUser(name: 'Bea');
      await addUser(name: 'Wout');
      await pump(tester);

      await tester.longPress(find.text('Bea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('2 people selected'), findsOneWidget);
    });
  });
}
