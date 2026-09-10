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

  testWidgets('a caller style merges over the resolved colour', (tester) async {
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
}
