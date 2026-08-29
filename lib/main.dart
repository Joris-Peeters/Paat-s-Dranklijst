import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const AppSettings(child: MainApp()));
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00696D)),
        useMaterial3: true,
      ),
      home: const PlaceholderScreen(),
    );
  }
}

/// Throwaway scaffolding: a plain string, an ICU plural, and formatMoney.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

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
                  '${l10n.balance}: ${AppSettings.of(context).formatMoney(1250)}',
                  style: textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
