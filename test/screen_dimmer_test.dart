import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/widgets/screen_dimmer.dart';

void main() {
  late List<double?> brightness;
  late int taps;

  setUp(() {
    brightness = [];
    taps = 0;
  });

  const delay = Duration(minutes: 30);

  Widget dimmer({bool enabled = true, Duration wait = delay}) => MaterialApp(
    home: ScreenDimmer(
      enabled: enabled,
      delay: wait,
      applyBrightness: (value) async => brightness.add(value),
      child: Scaffold(
        body: GestureDetector(
          onTap: () => taps++,
          child: const SizedBox(width: 200, height: 200, child: Text('screen')),
        ),
      ),
    ),
  );

  testWidgets('dims once the delay has passed, not before', (tester) async {
    await tester.pumpWidget(dimmer());

    await tester.pump(delay - const Duration(seconds: 1));
    expect(brightness, isEmpty);

    await tester.pump(const Duration(seconds: 1));
    expect(brightness, [ScreenDimmer.dimLevel]);
  });

  testWidgets('a touch gives the screen back', (tester) async {
    await tester.pumpWidget(dimmer());
    await tester.pump(delay);

    await tester.tap(find.text('screen'));
    await tester.pump();

    // Null hands the brightness back to the device.
    expect(brightness, [ScreenDimmer.dimLevel, null]);
  });

  testWidgets('the waking touch reaches nothing underneath', (tester) async {
    await tester.pumpWidget(dimmer());
    await tester.pump(delay);

    // warnIfMissed: the absorber takes the hit test, which is the point — the
    // touch is delivered, it just reaches nothing below.
    await tester.tap(find.text('screen'), warnIfMissed: false);
    await tester.pump();
    // Nobody logs a drink by rousing a dark tablet.
    expect(taps, 0);

    // The one after it lands as usual.
    await tester.tap(find.text('screen'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('a touch starts the delay over', (tester) async {
    await tester.pumpWidget(dimmer());

    await tester.pump(delay - const Duration(minutes: 1));
    await tester.tap(find.text('screen'));
    await tester.pump(delay - const Duration(seconds: 1));
    expect(brightness, isEmpty);

    await tester.pump(const Duration(seconds: 1));
    expect(brightness, [ScreenDimmer.dimLevel]);
  });

  testWidgets('disabled, it never dims', (tester) async {
    await tester.pumpWidget(dimmer(enabled: false));

    await tester.pump(const Duration(hours: 2));
    expect(brightness, isEmpty);
  });

  testWidgets('switching it off while dim gives the screen back', (
    tester,
  ) async {
    await tester.pumpWidget(dimmer());
    await tester.pump(delay);
    expect(brightness, [ScreenDimmer.dimLevel]);

    await tester.pumpWidget(dimmer(enabled: false));
    expect(brightness, [ScreenDimmer.dimLevel, null]);
  });

  testWidgets('a new delay is used from then on', (tester) async {
    await tester.pumpWidget(dimmer());

    const shorter = Duration(minutes: 5);
    await tester.pumpWidget(dimmer(wait: shorter));
    await tester.pump(shorter);
    expect(brightness, [ScreenDimmer.dimLevel]);
  });

  testWidgets('leaving the foreground gives the screen back', (tester) async {
    await tester.pumpWidget(dimmer());
    await tester.pump(delay);

    // On iOS the dimmed brightness is the system's own, so an app that is no
    // longer in front must not keep it.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(brightness, [ScreenDimmer.dimLevel, null]);
  });
}
