import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_settings.dart';
import 'data/database_provider.dart';
import 'l10n/app_localizations.dart';
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

    return MaterialApp(
      locale: settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Localizes the OS task-switcher label too
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: appTheme(settings.settings.seedColorArgb, Brightness.light),
      darkTheme: appTheme(settings.settings.seedColorArgb, Brightness.dark),
      themeMode: settings.themeMode,
      home: const PlaceholderScreen(),
    );
  }
}

/// Throwaway scaffolding: a plain string, an ICU plural, formatMoney, and a
/// read-out of the live settings row while there is no settings UI.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);
    final row = settings.settings;
    final textTheme = Theme.of(context).textTheme;

    String time(int minutes) =>
        '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutes % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.chooseYourName,
                  style: textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Text(l10n.drinksTaken(3), style: textTheme.headlineSmall),
                const SizedBox(height: 16),
                Text(
                  '${l10n.balance}: ${settings.formatMoney(1250)}',
                  style: textTheme.headlineSmall,
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'language ${row.languageCode}\n'
                  'currency ${row.currencyCode}\n'
                  'theme ${row.themeMode.name} -> ${settings.themeMode.name}\n'
                  'dark ${time(row.darkStartMinutes)} - '
                  '${time(row.darkEndMinutes)}\n'
                  'seed #${row.seedColorArgb.toRadixString(16).toUpperCase()}',
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
