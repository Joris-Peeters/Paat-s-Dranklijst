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
dart run build_runner build
dart run build_runner watch   # leave running while working

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
site. `AppSettings` lives in `lib/app_settings.dart` (see rule 5) and mirrors the
`AppLocalizations.of(context)` pattern: it carries the active currency code and reads
the active locale via `Localizations.localeOf(context)` internally, so callers never
pass locale or currency by hand.

```dart
String formatMoney(int minorUnits) {
  final locale = Localizations.localeOf(_context).toString();
  final format = NumberFormat.simpleCurrency(
    locale: locale,
    name: _settings.currencyCode,
  );
  final divisor = pow(10, format.decimalDigits ?? 2);
  return format.format(minorUnits / divisor);
}
```

It must be `simpleCurrency`, **not** `currency`. `NumberFormat.currency` fills the
pattern's `¤` placeholder with the currency *code* unless an explicit `symbol:` is
passed, so it renders `EUR 12,50` instead of `€ 12,50`. `simpleCurrency` resolves the
symbol from the code via intl's own lookup table, which keeps the symbol derived from
data rather than hardcoded.

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

The active language comes from the **database setting**, not the system locale — a
kiosk tablet's system locale is fixed and often wrong. It is never seeded from the
device either: a fresh database starts at `en` and the first-run wizard is where that
gets changed.

**Language only — no regional locales.** The stored `languageCode` is `en` or `nl`,
nothing more. Regional variants (`en-GB`, `nl-BE`) were tried and removed: they bought
number-grouping conventions nobody notices in a fridge, and cost a derivation layer
over intl's internal tables, a region name per locale in every ARB file, and a
conditional dropdown. Do not reintroduce them without a concrete need.

The list of offered languages is **`AppLocalizations.supportedLocales`**, which
`gen-l10n` derives from the ARB files present. There is no hand-maintained language
list to keep in sync — adding `app_de.arb` is all it takes to offer German. Their
display names live in the ARB files like any other UI string, each language named in
its own language (`English`, `Nederlands`), so the label does not change with the
active locale.

**Item names and user names are user data, not UI strings.** They never appear in ARB
files.

Money and dates must be formatted locale-aware (`nl` writes `€ 12,50`, with a
comma decimal separator; `en` writes `€12.50`). Always go through
`AppSettings.of(context).formatMoney(minorUnits)` (see rule 2) — never hand-roll
`'€${x.toStringAsFixed(2)}'`, and never assume symbol placement, spacing, or
decimal-digit count.

**`AppSettings`** (in `lib/app_settings.dart`) carries the settings a widget needs to
read anywhere in the tree — currently `locale` and `currencyCode`. It is a plain
widget wrapping a private `_AppSettingsScope` `InheritedWidget`, the same shape
Flutter's own `Theme` uses. `AppSettings.of(context)` returns a small accessor bound
to the calling context, so `AppSettings.of(context).formatMoney(1250)` reads exactly
like `AppLocalizations.of(context)`.

**It is placed above `MaterialApp`**, in `runApp`. `MaterialApp`'s own arguments are
themselves settings — `locale:` now, `theme:`/`themeMode:` under rule 4 — and a widget
can only read an `InheritedWidget` that is its ancestor, so anything feeding those
arguments must sit above it. The database seam is therefore in exactly one place:
`AppSettings.build`.

That placement does not strand `formatMoney`, which is the natural worry. An
`InheritedWidget` lookup walks up from the **calling** widget's context, not from
wherever the widget was provided. Real callers are screens *below* `MaterialApp`, so
walking up from them passes through the `Localizations` widget inside `MaterialApp`
before reaching `AppSettings` above it — both resolve. Only a call from above
`MaterialApp` would fail, and none exists.

`formatMoney` formats with the stored `languageCode` directly. Because that value is
always one of the languages this build ships, `MaterialApp` resolves it to itself and
the requested and resolved locales can never disagree — the distinction that matters
when regional locales are in play does not arise here.

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

- **`lib/l10n/app_localizations*.dart` are gitignored**, so a fresh clone has broken
  imports and a red `flutter analyze` until codegen has run once. `flutter run`/`build`
  generate them; `flutter gen-l10n` forces it. Run it before analyzing a fresh clone.
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
- `--delete-conflicting-outputs` was removed in build_runner 2.16 — passing it now
  just prints a warning.
- Drift schema changes require re-running `build_runner` **and** bumping
  `schemaVersion` with a matching migration step. As long as we are int the development
  phase and no deployments have been done, migrations are not needed.
- **Drift's `.watch()` streams only see writes made through the same `AppDatabase`
  instance.** Editing the database file with the `sqlite3` CLI while the app runs
  changes nothing on screen until a restart — drift tracks table updates in Dart, it
  does not poll the file. In-app writes (the settings UI, once it exists) do stream
  live. This is a property of drift, not a bug to fix.
- The database file is `paats_dranklijst.sqlite` in the **application support**
  directory (`~/.local/share/xyz.jpsystems.paats_dranklijst/` on Linux), set explicitly
  via `DriftNativeOptions.databaseDirectory`. drift_flutter's own default is the
  *documents* directory, which on Linux is the user's real `~/Documents`.
- `path_provider` is a direct dependency only because that directory override needs it;
  it already came in transitively with `drift_flutter`.
- Not every currency has 100 minor units — don't assume `/ 100` when formatting
  money, even though EUR (the only currency currently supported) happens to use it.
  Get the divisor from `NumberFormat.simpleCurrency(...).decimalDigits` via the
  `formatMoney` helper.
- `NumberFormat.currency(name: 'EUR')` renders the string `EUR`, not `€` — it only
  looks up the symbol when given an explicit `symbol:`. Use `NumberFormat.simpleCurrency`
  (see rule 2).

## Layout

```txt
lib/
  main.dart
  app_settings.dart          # ambient settings InheritedWidget; sits above MaterialApp
  l10n/                      # ARB files (committed) + generated localizations (gitignored)
  data/
    database.dart            # AppDatabase, schemaVersion, migrations
    database_provider.dart   # Database InheritedWidget; owns the AppDatabase instance
    tables/                  # drift table definitions
    daos/                    # queries, grouped by concern
  theme/
    palette.dart             # curated color list
    app_theme.dart           # ColorScheme.fromSeed helpers
    dark_mode_schedule.dart  # pure wall-clock schedule function
  screens/
  widgets/
test/                        # unit tests; no widget tests yet
```

## Current state

Implemented: rule 5 (localization), rule 2 (money formatting), rule 3's foundation
(the database as the source of truth), and rule 4's global half (seed color, light/dark
themes, scheduled dark mode).

The tree is `Database` -> `AppSettings` -> `MaterialApp`. `Database`
(`lib/data/database_provider.dart`) owns the `AppDatabase` and is stateful so the
connection opens and closes exactly once. `AppSettings` watches the settings row and
feeds `MaterialApp`'s `locale:`, `theme:`, `darkTheme:` and `themeMode:`.

The database has **one table**: a single-row `settings` table with typed columns
(`lib/data/tables/settings_table.dart`), a `CHECK (id = 1)` constraint, and the row
inserted in `onCreate` so no code anywhere handles "settings is null". `schemaVersion`
is 1; the `onUpgrade` scaffolding is in place but empty.

Nothing is seeded from the device. A fresh database takes every value from the schema
defaults — `en`, `EUR`, teal, scheduled dark mode. There is no settings UI yet, so
changing a setting means editing the row with `sqlite3` and restarting.

`main.dart` still holds a throwaway `PlaceholderScreen`, now also dumping the live
settings row — scaffolding, to be deleted once real screens exist.

Still target design, not code: users, items and the transaction ledger; per-user
theming; avatars; the first-run setup wizard; every real screen.

## Working preferences

- The repo owner is new to Flutter. Explain non-obvious Flutter idioms briefly when
  introducing them; don't assume familiarity with Dart conventions.
- **Keep comments short.** One line for a simple point. Don't spend three lines on
  something a clause covers, don't restate what the code already says, and don't
  justify every routine choice. A short paragraph is for reasoning that is genuinely
  non-obvious *and* not already written down here — architectural rationale lives in
  this file, so link to it (`see rule 2`) instead of duplicating it at each site.
  "Explain briefly" above means one or two lines, not a doc-comment essay.
- Prefer small, verifiable steps. After changes, run `flutter analyze` and
  `flutter run -d linux` to confirm the app still builds.
- `analysis_options.yaml` goes beyond `flutter_lints` — strict type checking
  (`strict-casts`/`strict-inference`/`strict-raw-types`) plus extra rules. `analyze`
  is expected to be **zero issues**, so treat lint findings as build failures. Two
  that bite most often: imports within `lib/` must be **relative**
  (`prefer_relative_imports` — `package:` is for external packages only), and every
  `Future` must be awaited or explicitly wrapped in `unawaited(...)`.
- Do not add dependencies without flagging the tradeoff first. The dependency list
  above is deliberate and minimal.
- Do not add networking, telemetry, analytics, crash reporting, or cloud sync.
