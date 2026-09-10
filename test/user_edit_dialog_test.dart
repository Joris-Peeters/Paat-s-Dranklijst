import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/widgets/user_avatar.dart';
import 'package:paats_dranklijst/widgets/user_edit_dialog.dart';

import 'support/harness.dart';

const int seededGroup = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase(executor: NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {UserRow? user}) async {
    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        screen: UserEditDialog(user: user, presetGroupId: seededGroup),
      ),
    );
    await tester.pumpAndSettle();
  }

  UserAvatar avatar(WidgetTester tester) =>
      tester.widget<UserAvatar>(find.byType(UserAvatar));

  testWidgetsWithDatabase('creating starts with a face and a colour', (
    tester,
  ) async {
    await pump(tester);

    // Both columns are non-null with no schema default, so a new member is
    // handed values rather than being allowed to save without them.
    expect(avatar(tester).emoji, isNotEmpty);
    expect(avatar(tester).seedColorArgb, isNot(0));
  });

  testWidgetsWithDatabase('a blank name refuses the save', (tester) async {
    await pump(tester);

    final save = find.widgetWithText(TextButton, 'Save');
    expect(tester.widget<TextButton>(save).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Jonas');
    await tester.pumpAndSettle();

    expect(tester.widget<TextButton>(save).onPressed, isNotNull);
  });

  testWidgetsWithDatabase('whitespace alone is not a name', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
          .onPressed,
      isNull,
    );
  });

  testWidgetsWithDatabase('the preview follows the colour picker', (
    tester,
  ) async {
    await pump(tester);
    final before = avatar(tester).seedColorArgb;

    // The inline palette shows four swatches; tap one that is not current.
    final swatches = find.byType(InkWell);
    for (var i = 0; i < swatches.evaluate().length; i++) {
      await tester.tap(swatches.at(i), warnIfMissed: false);
      await tester.pumpAndSettle();
      if (avatar(tester).seedColorArgb != before) return;
    }
    fail('no swatch changed the preview');
  });

  testWidgetsWithDatabase('editing pre-fills from the member', (tester) async {
    final id = await db.usersDao.createUser(
      name: 'Jonas',
      groupId: seededGroup,
      avatarEmoji: '🦊',
      seedColorArgb: 0xFFE91E63,
    );
    final user = await db.usersDao.readUser(id);
    await pump(tester, user: user);

    expect(find.text('Jonas'), findsOneWidget);
    expect(avatar(tester).emoji, '🦊');
    expect(avatar(tester).seedColorArgb, 0xFFE91E63);
    expect(find.text('Edit member'), findsOneWidget);
  });
}
