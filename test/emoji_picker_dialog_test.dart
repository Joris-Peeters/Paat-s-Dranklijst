import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/l10n/app_localizations.dart';
import 'package:paats_dranklijst/widgets/emoji_picker_dialog.dart';
import 'package:paats_dranklijst/widgets/user_avatar.dart';

/// The one widget test in the repo, and it earns its keep: `EmojiPicker`
/// measures itself off `constraints.maxWidth` and puts a `Flexible` in a
/// `Column`, so a missing width or height bound is an exception at layout time
/// that nothing else here would catch.
void main() {
  Widget harness(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('the dialog lays out and pops the tapped emoji', (tester) async {
    String? picked;

    await tester.pumpWidget(
      harness(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await showEmojiPickerDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(EmojiPickerDialog), findsOneWidget);

    // The two configured-off affordances.
    expect(find.byIcon(Icons.backspace_outlined), findsNothing);
    expect(find.byIcon(Icons.search), findsNothing);

    // One tab per category, with no Recent tab in front of them.
    final tabs = tester.widget<TabBar>(find.byType(TabBar)).tabs;
    expect(tabs, hasLength(defaultEmojiSet.length));

    final cells = find.byType(EmojiCell);
    expect(cells, findsWidgets);

    await tester.tap(cells.first);
    await tester.pumpAndSettle();

    expect(find.byType(EmojiPickerDialog), findsNothing);
    expect(picked, isNotNull);
  });

  testWidgets('a narrow window does not overflow the dialog', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      harness(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showEmojiPickerDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(EmojiPickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UserAvatar renders its emoji and stays tappable', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      harness(
        UserAvatar(
          emoji: '🦊',
          seedColorArgb: Colors.green.toARGB32(),
          size: 128,
          onTap: () => taps++,
        ),
      ),
    );

    expect(find.text('🦊'), findsOneWidget);

    await tester.tap(find.byType(UserAvatar));
    expect(taps, 1);

    // The circle is painted from the member's own scheme, not the app's.
    final avatarTheme = Theme.of(
      tester.element(find.text('🦊')),
    ).colorScheme;
    final appTheme = Theme.of(
      tester.element(find.byType(Scaffold)),
    ).colorScheme;
    expect(avatarTheme.primaryContainer, isNot(appTheme.primaryContainer));
  });
}
