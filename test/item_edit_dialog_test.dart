import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/widgets/item_edit_dialog.dart';

import 'support/harness.dart';

const int seededGroup = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase(executor: NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<ItemRow> addItem({int price = 150}) async {
    final id = await db.itemsDao.createItem(
      name: 'Cola',
      groupId: seededGroup,
      priceMinorUnits: price,
      emoji: '🥤',
    );
    return (db.select(db.items)..where((i) => i.id.equals(id))).getSingle();
  }

  Future<void> pump(
    WidgetTester tester, {
    ItemRow? item,
    ItemGroupRow? presetGroup,
  }) async {
    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        screen: ItemEditDialog(
          item: item,
          presetGroup:
              presetGroup ?? await db.itemsDao.readItemGroup(seededGroup),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TextField priceField(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).last);

  testWidgetsWithDatabase('the price prefills without a second symbol', (
    tester,
  ) async {
    await pump(tester, item: await addItem());

    // The field draws the symbol itself, so the text must not carry one.
    expect(priceField(tester).controller!.text, '1.50');
    expect(priceField(tester).decoration!.prefixText, '€ ');
  });

  testWidgetsWithDatabase('the prefilled price saves back unchanged', (
    tester,
  ) async {
    final item = await addItem(price: 175);
    await pump(tester, item: item);

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    final saved = await (db.select(
      db.items,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(saved.priceMinorUnits, 175);
  });

  testWidgetsWithDatabase('creating starts with no emoji and refuses to save', (
    tester,
  ) async {
    await pump(tester);

    // Unlike a user's face, which is arbitrary and assigned at random, an
    // item's emoji is what people tap to pick their drink — so it is chosen,
    // never invented.
    expect(find.byIcon(Icons.add_reaction_outlined), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Cola');
    await tester.enterText(find.byType(TextField).last, '1.50');
    await tester.pumpAndSettle();

    // Name and price are complete; the missing emoji alone holds Save back.
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
          .onPressed,
      isNull,
    );
  });

  testWidgetsWithDatabase('picking an emoji releases the save', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField).first, 'Cola');
    await tester.enterText(find.byType(TextField).last, '1.50');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_reaction_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('😀').first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add_reaction_outlined), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgetsWithDatabase('an unreadable price refuses the save', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField).first, 'Cola');
    await tester.enterText(find.byType(TextField).last, 'gratis');
    await tester.pumpAndSettle();

    expect(find.text('Enter an amount, for example 1.50'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
          .onPressed,
      isNull,
    );
  });

  testWidgetsWithDatabase('a new item starts with an empty, unflagged price', (
    tester,
  ) async {
    await pump(tester);

    // Empty is incomplete, not wrong: no error until something unreadable is
    // actually typed.
    expect(priceField(tester).controller!.text, isEmpty);
    expect(priceField(tester).decoration!.errorText, isNull);
  });
}
