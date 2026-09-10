import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/data/database_provider.dart';
import 'package:paats_dranklijst/l10n/app_localizations.dart';
import 'package:paats_dranklijst/settings/app_settings.dart';
import 'package:paats_dranklijst/settings/settings_store.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A [MaterialApp] with the ambient providers a widget expects.
///
/// `SharedPreferencesWithCache` needs a platform double rather than
/// `setMockInitialValues`, which targets the legacy synchronous API.
///
/// [database] is for a widget that reads one; leave it off and no database is
/// opened at all. [child] goes inside a Scaffold, so pass [screen] instead when
/// the widget builds its own.
Future<Widget> settingsHarness(
  Widget? child, {
  Widget? screen,
  AppDatabase? database,
  Map<String, Object> preferences = const {},
}) async {
  assert(
    (child == null) != (screen == null),
    'Pass exactly one of child or screen.',
  );

  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(preferences);
  final store = await SettingsStore.open();

  final app = AppSettings(
    store: store,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: screen ?? Scaffold(body: child),
    ),
  );

  return database == null ? app : Database(database: database, child: app);
}

/// [testWidgets] for a test whose tree reads a drift stream.
///
/// Drift schedules a zero-duration timer when the last listener on a query
/// stream goes away, and a `StreamBuilder` only unsubscribes when it is
/// disposed. Left to the framework that happens during teardown, after the
/// binding has already checked for pending timers, and every such test fails on
/// drift's own internals. Unmounting the tree at the end of the body instead
/// creates that timer while the clock can still be advanced to drain it —
/// `addTearDown` is too late for the same reason.
void testWidgetsWithDatabase(
  String description,
  Future<void> Function(WidgetTester tester) body,
) => testWidgets(description, (tester) async {
  await body(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  // A plain pump would not move the fake clock, and the timer is zero-duration
  // rather than immediate. Long enough to also see off a lingering SnackBar.
  await tester.pump(const Duration(seconds: 5));
});
