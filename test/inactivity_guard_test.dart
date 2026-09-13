import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/widgets/inactivity_guard.dart';

void main() {
  late int timeouts;

  setUp(() => timeouts = 0);

  Widget guard({bool enabled = true, bool paused = false, Widget? field}) =>
      MaterialApp(
        home: InactivityGuard(
          enabled: enabled,
          onTimeout: () => timeouts++,
          child: Scaffold(
            body: Column(
              children: [
                const SizedBox(width: 200, height: 200, child: Text('surface')),
                if (paused) const InactivityPause(child: Text('paused')),
                ?field,
              ],
            ),
          ),
        ),
      );

  testWidgets('fires after a minute without a touch, not before', (
    tester,
  ) async {
    await tester.pumpWidget(guard());

    await tester.pump(const Duration(seconds: 59));
    expect(timeouts, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(timeouts, 1);

    // Nothing to return from until someone touches it again.
    await tester.pump(const Duration(minutes: 5));
    expect(timeouts, 1);
  });

  testWidgets('a touch starts the minute over', (tester) async {
    await tester.pumpWidget(guard());

    await tester.pump(const Duration(seconds: 50));
    await tester.tap(find.text('surface'));
    await tester.pump(const Duration(seconds: 59));
    expect(timeouts, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(timeouts, 1);
  });

  testWidgets('disabled, it never fires; enabling starts the clock', (
    tester,
  ) async {
    await tester.pumpWidget(guard(enabled: false));
    await tester.pump(const Duration(minutes: 5));
    expect(timeouts, 0);

    await tester.pumpWidget(guard());
    await tester.pump(InactivityGuard.timeout);
    expect(timeouts, 1);
  });

  testWidgets('a pause holds it off until it is gone', (tester) async {
    await tester.pumpWidget(guard(paused: true));
    await tester.pump(const Duration(minutes: 5));
    expect(timeouts, 0);

    await tester.pumpWidget(guard());
    await tester.pump(InactivityGuard.timeout);
    expect(timeouts, 1);
  });

  testWidgets('a focused text field holds it off', (tester) async {
    await tester.pumpWidget(guard(field: const TextField(autofocus: true)));
    await tester.pump();

    await tester.pump(const Duration(minutes: 5));
    expect(timeouts, 0);
  });
}
