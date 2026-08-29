import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Ambient app settings, published to the whole tree.
///
/// Sits above `MaterialApp` so it can feed `MaterialApp`'s own arguments —
/// `locale:` now, `theme:`/`themeMode:` later. See CLAUDE.md rule 5.
class AppSettings extends StatelessWidget {
  const AppSettings({super.key, required this.child});

  final Widget child;

  /// The accessor is bound to the calling context, which is what lets
  /// [AppSettingsAccessor.formatMoney] read the active locale.
  static AppSettingsAccessor of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_AppSettingsScope>();
    assert(scope != null, 'No AppSettings found in context');
    return AppSettingsAccessor._(scope!, context);
  }

  @override
  Widget build(BuildContext context) {
    // TODO: read from the settings DAO via StreamBuilder once the DB exists.
    return _AppSettingsScope(
      locale: const Locale('nl'),
      currencyCode: 'EUR',
      child: child,
    );
  }
}

class _AppSettingsScope extends InheritedWidget {
  const _AppSettingsScope({
    required this.locale,
    required this.currencyCode,
    required super.child,
  });

  final Locale locale;
  final String currencyCode;

  @override
  bool updateShouldNotify(_AppSettingsScope oldWidget) =>
      locale != oldWidget.locale || currencyCode != oldWidget.currencyCode;
}

/// Returned by [AppSettings.of]. Public only to appear in that signature.
class AppSettingsAccessor {
  const AppSettingsAccessor._(this._scope, this._context);

  final _AppSettingsScope _scope;
  final BuildContext _context;

  /// The *requested* locale, for `MaterialApp.locale`. For the resolved one,
  /// use [Localizations.localeOf].
  Locale get locale => _scope.locale;

  String get currencyCode => _scope.currencyCode;

  /// Formats an integer amount of minor units. See CLAUDE.md rule 2.
  ///
  /// `simpleCurrency` renders '€' where `currency` would render 'EUR'. The
  /// divisor is per-currency — not everything has 100 minor units.
  String formatMoney(int minorUnits) {
    final locale = Localizations.localeOf(_context).toString();
    final format = NumberFormat.simpleCurrency(
      locale: locale,
      name: _scope.currencyCode,
    );
    final divisor = pow(10, format.decimalDigits ?? 2);
    return format.format(minorUnits / divisor);
  }
}
