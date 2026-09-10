import 'package:flutter/material.dart';

/// One variant everywhere, so the app theme and every per-user theme are
/// generated the same way.
const _schemeVariant = DynamicSchemeVariant.rainbow;

// Never evicted: seeds only come from the curated palette, so these hold at
// most `seedColorPalette.length * 2` entries.
final _schemes = <(int, Brightness), ColorScheme>{};
final _themes = <(int, Brightness), ThemeData>{};

/// The scheme for one seed. Memoized: `fromSeed` runs the whole Material colour
/// algorithm, far too expensive to repeat per avatar per frame.
ColorScheme schemeFor(int seedColorArgb, Brightness brightness) =>
    _schemes.putIfAbsent(
      (seedColorArgb, brightness),
      () => ColorScheme.fromSeed(
        dynamicSchemeVariant: _schemeVariant,
        seedColor: Color(seedColorArgb),
        brightness: brightness,
      ),
    );

/// Light and dark come from the same seed, so the palette stays coherent across
/// the switch. Memoized, so repeat calls return the same instance and
/// `ThemeData ==` short-circuits on identity.
ThemeData appTheme(int seedColorArgb, Brightness brightness) =>
    _themes.putIfAbsent(
      (seedColorArgb, brightness),
      () => ThemeData(
        colorScheme: schemeFor(seedColorArgb, brightness),
        useMaterial3: true,
      ),
    );

// Credit is a fixed green rather than a ColorScheme role. Every role shifts
// with the admin's seed and again inside a member's own theme, so `tertiary`
// would mean teal on one page and pink on the next; money must not change
// meaning with the palette around it. Debit needs no equivalent — Material
// keeps `error` in the red family whatever the seed.
const _creditLight = Color(0xFF2E7D32);
const _creditDark = Color(0xFF81C784);

/// The colour of an amount that is money in the member's favour.
Color creditColor(Brightness brightness) =>
    brightness == Brightness.dark ? _creditDark : _creditLight;
