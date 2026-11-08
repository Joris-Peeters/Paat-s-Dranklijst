import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/widgets/pin_dialog.dart';

import 'support/harness.dart';

/// Asks for the PIN, then pushes a page, the way settings are opened.
class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Start')),
    body: Center(
      child: TextButton(
        onPressed: () async {
          if (!await requireAdminPin(context)) return;
          if (!context.mounted) return;
          await Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  Scaffold(appBar: AppBar(title: const Text('Behind'))),
            ),
          );
        },
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  Future<void> openPin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      await settingsHarness(
        null,
        screen: const _Gate(),
        preferences: {'adminPin': '1234'},
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String digits) async {
    for (final digit in digits.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
  }

  testWidgets('the right PIN opens the page straight away', (tester) async {
    await openPin(tester);
    await enter(tester, '1234');

    // No clock time passes: the gate does not hold the dialog open. The second
    // frame is the pushed page's first onstage one.
    await tester.pump();
    expect(find.text('Behind'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(PinEnterDialog), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('a wrong PIN keeps the dialog up', (tester) async {
    await openPin(tester);
    await enter(tester, '9999');
    await tester.pumpAndSettle();

    expect(find.byType(PinEnterDialog), findsOneWidget);
    expect(find.text('Behind'), findsNothing);
  });

  testWidgets('taps on a closing dialog leave the screens beneath alone', (
    tester,
  ) async {
    await openPin(tester);
    await enter(tester, '123');

    // No pump between these: the dialog still takes taps until the next frame.
    await tester.tap(find.text('4'));
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();

    expect(find.text('Behind'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Start'), findsOneWidget);
  });
}
