import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/widgets/emoji_picker_dialog.dart';
import 'package:paats_dranklijst/widgets/user_avatar.dart';
import 'package:paats_dranklijst/widgets/user_edit_dialog.dart';

import 'support/harness.dart';
import 'support/ledger.dart';

const int seededGroup = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase(executor: NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester, {
    UserRow? user,
    bool canChangeGroup = true,
  }) async {
    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        screen: UserEditDialog(
          user: user,
          presetGroupId: seededGroup,
          canChangeGroup: canChangeGroup,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<UserRow> addUser(String name) async {
    final id = await db.usersDao.createUser(
      name: name,
      groupId: seededGroup,
      avatarEmoji: '🦊',
      seedColorArgb: 0xFFE91E63,
    );
    return (await db.readUser(id))!;
  }

  bool saveEnabled(WidgetTester tester) =>
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
          .onPressed !=
      null;

  DropdownButtonFormField<int> groupField(WidgetTester tester) =>
      tester.widget<DropdownButtonFormField<int>>(
        find.byType(DropdownButtonFormField<int>),
      );

  UserAvatar avatar(WidgetTester tester) =>
      tester.widget<UserAvatar>(find.byType(UserAvatar));

  testWidgetsWithDatabase('creating starts with a face and a colour', (
    tester,
  ) async {
    await pump(tester);

    // Both columns are non-null with no schema default, so a new user is
    // handed values rather than being allowed to save without them.
    expect(avatar(tester).emoji, isNotEmpty);
    expect(avatar(tester).seedColorArgb, isNot(0));
  });

  testWidgetsWithDatabase('the emoji is changed by a button, not the avatar', (
    tester,
  ) async {
    await pump(tester);
    expect(avatar(tester).onTap, isNull);

    await tester.tap(find.text('Change emoji'));
    await tester.pumpAndSettle();

    expect(find.byType(EmojiPickerDialog), findsOneWidget);
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

  testWidgetsWithDatabase('editing pre-fills from the user', (tester) async {
    final id = await db.usersDao.createUser(
      name: 'Jonas',
      groupId: seededGroup,
      avatarEmoji: '🦊',
      seedColorArgb: 0xFFE91E63,
    );
    final user = await db.readUser(id);
    await pump(tester, user: user);

    expect(find.text('Jonas'), findsOneWidget);
    expect(avatar(tester).emoji, '🦊');
    expect(avatar(tester).seedColorArgb, 0xFFE91E63);
    expect(find.text('Edit user'), findsOneWidget);
  });

  testWidgetsWithDatabase('a name someone else already has is refused', (
    tester,
  ) async {
    await addUser('Jonas');
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'Jonas');
    await tester.pumpAndSettle();

    expect(find.text('Someone is already called this'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
  });

  testWidgetsWithDatabase('changing to a free name lifts the refusal', (
    tester,
  ) async {
    await addUser('Jonas');
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'Jonas');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Jonas P');
    await tester.pumpAndSettle();

    expect(find.text('Someone is already called this'), findsNothing);
    expect(saveEnabled(tester), isTrue);
  });

  testWidgetsWithDatabase('the check ignores case and spacing', (tester) async {
    await addUser('Jonas');
    await pump(tester);

    await tester.enterText(find.byType(TextField), ' jonas ');
    await tester.pumpAndSettle();

    expect(find.text('Someone is already called this'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
  });

  testWidgetsWithDatabase('nobody is a duplicate of themselves', (
    tester,
  ) async {
    final jonas = await addUser('Jonas');
    await pump(tester, user: jonas);

    // Opening the editor and saving an untouched name must say nothing.
    expect(find.text('Someone is already called this'), findsNothing);
    expect(saveEnabled(tester), isTrue);
  });

  testWidgetsWithDatabase('an archived user no longer holds their name', (
    tester,
  ) async {
    final jonas = await addUser('Jonas');
    await db.usersDao.archiveUser(jonas.id);
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'Jonas');
    await tester.pumpAndSettle();

    expect(find.text('Someone is already called this'), findsNothing);
    expect(saveEnabled(tester), isTrue);
  });

  testWidgetsWithDatabase('a locked group is shown but inert while editing', (
    tester,
  ) async {
    final jonas = await addUser('Jonas');
    await pump(tester, user: jonas, canChangeGroup: false);

    // Shown, not hidden: which group someone is in is worth reading either way.
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    expect(groupField(tester).onChanged, isNull);
  });

  testWidgetsWithDatabase('creating keeps the group live even when locked', (
    tester,
  ) async {
    await pump(tester, canChangeGroup: false);

    // Picking a first group is not switching groups — and the kiosk's add
    // button passes no preset, so a locked field there would strand Save.
    expect(groupField(tester).onChanged, isNotNull);

    await tester.enterText(find.byType(TextField), 'Wout');
    await tester.pumpAndSettle();
    expect(saveEnabled(tester), isTrue);
  });

  testWidgetsWithDatabase('a photo is shown, and picking an emoji drops it', (
    tester,
  ) async {
    final jonas = await addUser('Jonas');
    final photo = img.encodeJpg(img.Image(width: 8, height: 8));
    await db.usersDao.updateUserAppearance(
      id: jonas.id,
      avatarImage: Value(photo),
    );
    await pump(tester, user: (await db.readUser(jonas.id))!);

    expect(avatar(tester).image, photo);
    expect(find.text('Use emoji'), findsOneWidget);
    expect(find.text('Change emoji'), findsNothing);

    await tester.tap(find.text('Use emoji'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(EmojiCell).first);
    await tester.pumpAndSettle();

    expect(avatar(tester).image, isNull);
    expect(find.text('Change emoji'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect((await db.readUser(jonas.id))!.avatarImage, isNull);
  });

  testWidgetsWithDatabase('no camera button where there is no camera', (
    tester,
  ) async {
    await pump(tester);

    // Tests run on the desktop host, which the camera plugin does not support.
    expect(find.text('Take photo'), findsNothing);
  });
}
