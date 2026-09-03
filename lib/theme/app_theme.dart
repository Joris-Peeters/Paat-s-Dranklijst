import 'package:flutter/material.dart';

/// Light and dark themes come from the same stored seed and differ only in
/// brightness, so the palette stays coherent across the switch.
ThemeData appTheme(int seedColorArgb, Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    dynamicSchemeVariant: DynamicSchemeVariant.rainbow,
    seedColor: Color(seedColorArgb),
    brightness: brightness,
  ),
  useMaterial3: true,
);
