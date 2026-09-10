import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/theme/app_theme.dart';
import 'package:paats_dranklijst/widgets/money_text.dart';

import 'support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Color colorOf(WidgetTester tester) =>
      tester.widget<Text>(find.byType(Text)).style!.color!;

  testWidgets('zero renders in full rather than blank', (tester) async {
    await tester.pumpWidget(
      await settingsHarness(const MoneyText(amountMinorUnits: 0)),
    );

    expect(find.text('€0.00'), findsOneWidget);
  });

  testWidgets('a debt takes the error colour, credit a green', (tester) async {
    await tester.pumpWidget(
      await settingsHarness(const MoneyText(amountMinorUnits: -300)),
    );
    final scheme = Theme.of(tester.element(find.byType(MoneyText))).colorScheme;
    expect(colorOf(tester), scheme.error);

    await tester.pumpWidget(
      await settingsHarness(const MoneyText(amountMinorUnits: 300)),
    );
    expect(colorOf(tester), creditColor(Brightness.light));
  });

  testWidgets('zero inherits the surrounding text colour', (tester) async {
    await tester.pumpWidget(
      await settingsHarness(const MoneyText(amountMinorUnits: 0)),
    );

    expect(tester.widget<Text>(find.byType(Text)).style?.color, isNull);
  });

  testWidgets('signed marks a positive amount and leaves a debt alone', (
    tester,
  ) async {
    await tester.pumpWidget(
      await settingsHarness(
        const MoneyText(amountMinorUnits: 250, signed: true),
      ),
    );
    expect(find.text('+€2.50'), findsOneWidget);

    await tester.pumpWidget(
      await settingsHarness(
        const MoneyText(amountMinorUnits: -250, signed: true),
      ),
    );
    expect(find.text('-€2.50'), findsOneWidget);
  });

  testWidgets('a caller style keeps its own decoration', (tester) async {
    await tester.pumpWidget(
      await settingsHarness(
        const MoneyText(
          amountMinorUnits: -300,
          style: TextStyle(decoration: TextDecoration.lineThrough),
        ),
      ),
    );

    final style = tester.widget<Text>(find.byType(Text)).style!;
    expect(style.decoration, TextDecoration.lineThrough);
    expect(style.color, isNotNull);
  });

  testWidgets('a themed style does not win on colour', (tester) async {
    // The regression this guards: nearly every text theme style carries a
    // colour of its own, and merging the caller's style last let that colour
    // silently replace the one thing this widget exists to decide.
    await tester.pumpWidget(
      await settingsHarness(
        const MoneyText(
          amountMinorUnits: -300,
          style: TextStyle(color: Colors.purple, fontSize: 30),
        ),
      ),
    );

    final style = tester.widget<Text>(find.byType(Text)).style!;
    expect(style.color, isNot(Colors.purple));
    expect(
      style.color,
      Theme.of(tester.element(find.byType(MoneyText))).colorScheme.error,
    );
    // Everything else the caller asked for survives.
    expect(style.fontSize, 30);
  });

  testWidgets('colored: false leaves the caller in charge', (tester) async {
    // A price is not a balance, so it must not read as credit.
    await tester.pumpWidget(
      await settingsHarness(
        const MoneyText(
          amountMinorUnits: 150,
          colored: false,
          style: TextStyle(color: Colors.purple),
        ),
      ),
    );

    expect(tester.widget<Text>(find.byType(Text)).style?.color, Colors.purple);
  });
}
