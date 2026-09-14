import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/database_provider.dart';
import 'l10n/app_localizations.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/setup_wizard.dart';
import 'screens/start_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/users_screen.dart';
import 'settings/app_settings.dart';
import 'settings/settings_store.dart';
import 'theme/app_theme.dart';
import 'widgets/inactivity_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Without this, DateFormat throws for any locale but the default one.
  await initializeDateFormatting();
  final store = await SettingsStore.open();

  runApp(
    Database(
      child: AppSettings(store: store, child: const MainApp()),
    ),
  );
}

/// Must be its own widget class: a closure inside [AppSettings] would build
/// with the enclosing context, and `AppSettings.of` would find nothing.
class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _returnToStart = _ReturnToStart();

  @override
  void dispose() {
    _returnToStart.dispose();
    super.dispose();
  }

  /// Closes every screen, dialog and sheet — they are all routes on the one
  /// navigator — and has the shell select its Start tab.
  void _goToStart() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    _returnToStart.fire();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final seedColor = settings.seedColorArgb;

    return MaterialApp(
      navigatorKey: _navigatorKey,
      // Wraps the Navigator itself, so the guard sees touches on every route
      // and every route can find it.
      builder: (context, child) => InactivityGuard(
        // The wizard has no Start page to go back to.
        enabled:
            settings.setupCompletedAt != null && settings.returnToStartWhenIdle,
        onTimeout: _goToStart,
        child: child!,
      ),
      // Always one of `supportedLocales`, so Flutter resolves it to itself.
      locale: Locale(settings.languageCode),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Localizes the OS task-switcher label too
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: appTheme(seedColor, Brightness.light),
      darkTheme: appTheme(seedColor, Brightness.dark),
      themeMode: AppSettings.themeModeOf(context),
      // The wizard's last step writes setupCompletedAt, which swaps this over
      // to the shell.
      home: settings.setupCompletedAt == null
          ? const SetupWizard()
          : AppShell(returnToStart: _returnToStart),
    );
  }
}

/// Tells the shell to select its Start tab, without the guard knowing tabs
/// exist.
class _ReturnToStart extends ChangeNotifier {
  void fire() => notifyListeners();
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.returnToStart});

  /// Selects the Start tab whenever it notifies.
  final Listenable returnToStart;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    widget.returnToStart.addListener(_selectStart);
  }

  @override
  void dispose() {
    widget.returnToStart.removeListener(_selectStart);
    super.dispose();
  }

  void _selectStart() => setState(() => _index = 0);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      // IndexedStack so each tab keeps its scroll position and state.
      body: IndexedStack(
        index: _index,
        children: [
          // The Users page is a tab rather than a route, so the Start page's
          // big button switches the index instead of pushing.
          StartScreen(onOpenUsers: () => setState(() => _index = 1)),
          const UsersScreen(),
          // IndexedStack keeps these built while hidden, so each is told when
          // it is on screen and loads its figures only then.
          LeaderboardScreen(active: _index == 2),
          StatsScreen(active: _index == 3),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_rounded),
            label: l10n.navStart,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_rounded),
            label: l10n.navUsers,
          ),
          NavigationDestination(
            icon: const Icon(Icons.emoji_events_rounded),
            label: l10n.navLeaderboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_rounded),
            label: l10n.navStats,
          ),
        ],
      ),
    );
  }
}
