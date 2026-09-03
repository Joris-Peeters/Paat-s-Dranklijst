import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_settings.dart';
import 'data/database_provider.dart';
import 'l10n/app_localizations.dart';
import 'screens/setup_wizard.dart';
import 'screens/start_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/users_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Without this, DateFormat throws for any locale but the default one.
  await initializeDateFormatting();

  runApp(const Database(child: AppSettings(child: MainApp())));
}

/// Builds the [MaterialApp].
///
/// Must be its own widget class: a closure inside [AppSettings] would build
/// with the enclosing context, and `AppSettings.of` would find nothing.
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final seedColor = settings.seedColorArgb;

    return MaterialApp(
      // Always one of `supportedLocales`, so Flutter resolves it to itself.
      locale: Locale(settings.languageCode),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Localizes the OS task-switcher label too
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: appTheme(seedColor, Brightness.light),
      darkTheme: appTheme(seedColor, Brightness.dark),
      themeMode: AppSettings.themeModeOf(context),
      // The wizard writes setupCompletedAt in its closing transaction, which
      // re-emits the settings row and swaps this over to the shell.
      home: settings.setupCompletedAt == null
          ? const SetupWizard()
          : const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      // IndexedStack so each tab keeps its scroll position and state.
      body: IndexedStack(
        index: _index,
        children: const [StartScreen(), UsersScreen(), StatsScreen()],
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
            icon: const Icon(Icons.bar_chart_rounded),
            label: l10n.navStats,
          ),
        ],
      ),
    );
  }
}
