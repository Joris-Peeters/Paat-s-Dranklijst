# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

**Paat's Dranklijst** is a self-service drink-consumption tracker for a Chiro group's
fridge. A touchscreen tablet is mounted permanently on the fridge; members tap their
name, tap what they took, and it's logged against a personal running tab. An
admin-gated settings area manages users, items, and group finances (including a bank
IBAN rendered as a payment QR code for settling up).

It is a **single-user-at-a-time, offline, kiosk appliance** — not a multi-user
networked app. There is no server, no account system, no sync.

### Deployment context (drives most design decisions)

- Runs on cheap second-hand Android tablets in kiosk mode (Android lock task mode),
  second-hand iPads (Supervised + Autonomous Single App Mode), or Linux
  (Surface with linux-surface kernel, mini PC, old laptop).
- Expected to run **untouched for years**. Auto-restart on crash/reboot.
- Users are Chiro members — teenagers and leaders — tapping with cold, wet fingers on
  a fridge door. Touch targets must be generous. UI must be obvious without
  instruction.
- **No networking.** No audio. No device integrations beyond (eventually) the camera.

## Stack

| Concern | Choice |
| --- | --- |
| Framework | Flutter |
| UI | Material 3 (`useMaterial3: true`), built-in widgets only |
| Database | `drift` + `drift_flutter` |
| Charts | `fl_chart` |
| QR codes | `qr_flutter` |
| i18n | `flutter_localizations` + `intl` + ARB / `gen-l10n` |
| Camera (future, low priority) | `image_picker` (not `camera`) |

**Target platforms:** Android, iOS, Linux. **Development happens exclusively on Arch
Linux.** iOS builds require macOS/Xcode and are done via CI or a borrowed Mac — never
assume an iOS build can be run locally.

## Commands

```bash
# Run (Linux is the default dev target — fastest inner loop)
flutter run -d linux

# Drift codegen — required after ANY change to table definitions
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs   # leave running while working

# Localization codegen runs automatically on run/build; to force it:
flutter gen-l10n

# Builds
flutter build linux --release
flutter build apk --release
flutter build apk --release --split-per-abi

# Housekeeping
flutter analyze
flutter test
flutter clean && flutter pub get
```

## Architectural rules

These are deliberate and load-bearing. Do not work around them without asking.

### 1. The transaction log is an append-only ledger

Every consumption and every top-up is a permanent row. **Never UPDATE or DELETE a
transaction.** Corrections are made by appending a compensating entry.

Each transaction row stores a **frozen snapshot** of the item's name and price at the
time of purchase. Renaming "Cola" or changing its price must never rewrite history.
This means transaction rows carry `itemNameSnapshot` and `priceMinorUnitsSnapshot`
columns rather than relying on a join to the current items table.

### 2. Money is an integer in minor units. Always

`IntColumn get priceMinorUnits => integer()();`

Never `double`, never `REAL`. Floating-point drift in a ledger that runs unattended
for years is exactly the bug we're avoiding.

The app currently only supports **EUR**, and EUR uses 100 minor units (cents) per
euro — but the code must not assume that divisor is universal. Most currencies use
100 minor units, but not all (JPY/KRW use 0, some Gulf-state dinars use 1000).

Money is always formatted through `AppSettings.of(context).formatMoney(minorUnits)`
— never inline `NumberFormat`, never hand-roll `/ 100` or a `'€'` literal at a call
site. `AppSettings` is an `InheritedWidget` (defined in `main.dart`, see rule 5) that
mirrors the `AppLocalizations.of(context)` pattern: it carries the active currency
code and reads the active locale via `Localizations.localeOf(context)` internally, so
callers never pass locale or currency by hand.

```dart
String formatMoney(int minorUnits) {
  final locale = Localizations.localeOf(_context).toString();
  final format = NumberFormat.currency(locale: locale, name: _settings.currencyCode);
  final divisor = pow(10, format.decimalDigits ?? 2);
  return format.format(minorUnits / divisor);
}
```

`currencyCode` is currently always `'EUR'` — there is no UI to change it — but it
flows through `AppSettings` as data, not a hardcoded symbol, so adding real
multi-currency support later means adding a currency-code setting, not touching call
sites.

### 3. The database is the single source of truth for all state

All settings — theme seed color, theme mode, admin PIN, IBAN, language, per-user
preferences — live in the database alongside the data they govern. The goal is that
**a factory-reset app plus a restored database file fully restores state.**

Consequences:

- Do not use `SharedPreferences`. Ever. If a package needs it internally, that's a
  reason to reconsider the package.
- Do not write user-facing state to files outside the DB. Avatar images go in a
  `BlobColumn`, not a directory.
- No separate state-management package (`provider`, `riverpod`, `bloc`) is used for
  app state. Drift's `.watch()` streams + `StreamBuilder` are the mechanism. Local
  ephemeral widget state uses `setState`.

### 4. Theming

Global admin-chosen **seed color** drives `ColorScheme.fromSeed`. Per-user colors
generate a *second* scheme wrapped around user-specific subtrees via a `Theme` widget
— never paint raw user colors onto widgets directly, as that breaks Material contrast
guarantees.

Both admin and users pick from a **fixed curated palette** of Material-friendly
colors, rendered as a hand-rolled grid of circular swatches. No color-picker package.

Colors are stored as ARGB `int` (the resolved color, **not** an index into the
palette, so retiring a palette color doesn't silently recolor users).

### 5. Localization

UI language is **English first** — `app_en.arb` is the template ARB file. Dutch
(`app_nl.arb`) is a secondary locale, and the primary one actual users will see day
to day (the group is Dutch-speaking) — English exists as the template because that's
the language the code and this document are written in. Code, comments, and
identifiers are in English regardless of which ARB file is the template.

The active locale comes from the **database setting**, not the system locale — a
kiosk tablet's system locale is fixed and often wrong.

**Item names and user names are user data, not UI strings.** They never appear in ARB
files.

Money and dates must be formatted locale-aware (`nl_BE` writes `€ 12,50`, with a
comma decimal separator; `en_US` writes `€12.50`). Always go through
`AppSettings.of(context).formatMoney(minorUnits)` (see rule 2) — never hand-roll
`'€${x.toStringAsFixed(2)}'`, and never assume symbol placement, spacing, or
decimal-digit count.

**`AppSettings`** is a small `InheritedWidget` (currently defined in `main.dart`,
alongside the rest of the localization wiring — no separate file needed at this
size) that carries settings a widget needs to read anywhere in the tree, currently
just `currencyCode`. It's provided via `MaterialApp`'s `builder:` parameter, which is
what makes `Localizations.localeOf(context)` reachable from inside it — providing it
*above* `MaterialApp` instead would put it outside the tree that publishes locale.
`AppSettings.of(context)` returns a small accessor bound to the calling context, so
`AppSettings.of(context).formatMoney(1250)` reads exactly like
`AppLocalizations.of(context)`.

### 6. Avatars

Render order: uploaded image if present → emoji if present → initials fallback.

```dart
TextColumn get avatarEmoji => text().nullable()();   // TEXT — emoji are multi-codepoint
BlobColumn get avatarImage => blob().nullable()();   // reserved; feature not built yet
```

`avatarEmoji` is TEXT because emoji use skin-tone modifiers and ZWJ sequences and
cannot be stored as a single int codepoint. The blob column exists now specifically so
the future camera feature needs no migration.

## Known gotchas

- **Color emoji do not render on Linux desktop by default** — they appear monochrome.
  A color emoji font must be bundled as an app asset and set via `fontFamilyFallback`.
  This also makes avatars render identically across Android, iOS, and Linux.
- **Do not import `package:flutter_gen/gen_l10n/app_localizations.dart`.** The
  synthetic package is removed from modern Flutter. Import generated localizations by
  their real path (`package:paats_dranklijst/l10n/app_localizations.dart`).
- **`intl` must be added as `intl: any`** — `flutter_localizations` pins an exact
  version and any other constraint causes a resolution conflict.
- Use `Color.toARGB32()`, not the deprecated `Color.value`. Use
  `withValues(alpha: ...)`, not the deprecated `withOpacity()`.
- Plugins without Linux implementations (e.g. `image_picker`'s camera path) throw
  `MissingPluginException` at runtime, not compile time. Guard with
  `Platform.isAndroid || Platform.isIOS`.
- Drift schema changes require re-running `build_runner` **and** bumping
  `schemaVersion` with a matching migration step. As long as we are int the development
  phase and no deployments have been done, migrations are not needed.
- Not every currency has 100 minor units — don't assume `/ 100` when formatting
  money, even though EUR (the only currency currently supported) happens to use it.
  Get the divisor from `NumberFormat.currency(...).decimalDigits` via the
  `formatMoney` helper.

## Layout

```txt
lib/
  main.dart
  l10n/                 # ARB files + generated localizations
  data/
    database.dart       # AppDatabase, schemaVersion, migrations
    tables/             # drift table definitions
    daos/               # queries, grouped by concern
  theme/
    palette.dart        # curated color list
    app_theme.dart      # ColorScheme.fromSeed helpers
  screens/
  widgets/
```

## Current state

Fresh project. The scaffold from `flutter create` is still in place. Nothing
in the architecture above is implemented yet — treat it as the target design.

## Working preferences

- The repo owner is new to Flutter. Explain non-obvious Flutter idioms briefly when
  introducing them; don't assume familiarity with Dart conventions.
- Prefer small, verifiable steps. After changes, run `flutter analyze` and
  `flutter run -d linux` to confirm the app still builds.
- Do not add dependencies without flagging the tradeoff first. The dependency list
  above is deliberate and minimal.
- Do not add networking, telemetry, analytics, crash reporting, or cloud sync.
