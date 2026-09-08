import 'package:flutter/material.dart';

/// One variant everywhere, so the app theme and every per-user theme are
/// generated the same way. See rule 4.
const schemeVariant = DynamicSchemeVariant.rainbow;

// Seeds only ever come from the curated palette (rule 4), so these hold at most
// `seedColorPalette.length * 2` entries. Free colour picking would need eviction.
final _schemes = <(int, Brightness), ColorScheme>{};
final _themes = <(int, Brightness), ThemeData>{};

/// The scheme for one seed. Memoized: `fromSeed` runs the whole Material colour
/// algorithm, far too expensive to repeat per avatar per frame.
ColorScheme schemeFor(int seedColorArgb, Brightness brightness) =>
    _schemes.putIfAbsent(
      (seedColorArgb, brightness),
      () => ColorScheme.fromSeed(
        dynamicSchemeVariant: schemeVariant,
        seedColor: Color(seedColorArgb),
        brightness: brightness,
      ),
    );

/// Light and dark themes come from the same stored seed and differ only in
/// brightness, so the palette stays coherent across the switch.
///
/// Memoized too, so repeat calls return the *same instance*: `ThemeData ==`
/// short-circuits on identity, and a per-user `Theme` costs a map lookup.
ThemeData appTheme(int seedColorArgb, Brightness brightness) =>
    _themes.putIfAbsent(
      (seedColorArgb, brightness),
      () => ThemeData(
        colorScheme: schemeFor(seedColorArgb, brightness),
        useMaterial3: true,
      ),
    );
