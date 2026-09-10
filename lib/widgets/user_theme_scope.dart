import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Puts a user's own palette on everything below it.
///
/// A whole page can sit inside one — the user detail screen, say — so its
/// buttons, ink splashes and surfaces all read as that user's. Builds a full
/// [ThemeData] rather than copying a scheme onto the app's: `copyWith` swaps
/// the scheme but leaves the derived component themes on the old palette,
/// giving a half-recoloured page.
class UserThemeScope extends StatelessWidget {
  const UserThemeScope({
    super.key,
    required this.seedColorArgb,
    required this.child,
  });

  final int seedColorArgb;
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    // Memoized, so a screen full of avatars is one map lookup each.
    data: appTheme(seedColorArgb, Theme.of(context).brightness),
    child: child,
  );
}
