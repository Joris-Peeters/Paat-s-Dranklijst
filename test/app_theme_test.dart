import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/theme/app_theme.dart';

/// The caches are process-global and shared across these tests. Only identity
/// and value are asserted, never cache size, so ordering does not matter.
void main() {
  const teal = 0xFF009688;
  const purple = 0xFF9C27B0;

  group('schemeFor', () {
    test('returns the same instance for the same seed and brightness', () {
      expect(
        schemeFor(teal, Brightness.light),
        same(schemeFor(teal, Brightness.light)),
      );
    });

    test('light and dark are distinct schemes', () {
      final light = schemeFor(teal, Brightness.light);
      final dark = schemeFor(teal, Brightness.dark);

      expect(light, isNot(same(dark)));
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
    });

    test('different seeds give different palettes', () {
      // Catches a cache key that collapses two seeds onto one entry.
      expect(
        schemeFor(teal, Brightness.light).primary,
        isNot(schemeFor(purple, Brightness.light).primary),
      );
    });
  });

  group('appTheme', () {
    test('returns the same instance for the same seed and brightness', () {
      // The property main.dart relies on: it rebuilds both themes on every
      // settings emission, including the once-a-minute schedule re-resolve.
      expect(
        appTheme(teal, Brightness.light),
        same(appTheme(teal, Brightness.light)),
      );
    });

    test('carries the memoized scheme', () {
      expect(
        appTheme(teal, Brightness.dark).colorScheme,
        same(schemeFor(teal, Brightness.dark)),
      );
    });
  });
}
