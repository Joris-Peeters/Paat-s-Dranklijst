import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Covers the gap between the first frame and the first settings row arriving.
///
/// It renders *above* `MaterialApp`, so it brings its own — a bare [Scaffold]
/// up there has no [Directionality] or [Localizations] to work with. Plain
/// defaults on purpose: it does not try to preview the stored theme, since
/// that is exactly what has not loaded yet.
///
/// This only covers the Flutter-side gap; the native launch screen shown
/// before the Dart VM boots is a separate thing.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // No locale: the stored one is not known yet, so the system locale
      // resolves for the moment this is visible.
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(AppLocalizations.of(context).loading),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
