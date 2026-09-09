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
| App state | Drift `.watch()` streams + `StreamBuilder`; `setState` for ephemeral widget state. |
| Database | `drift` + `drift_flutter` |
| Settings | `shared_preferences` |
| QR codes | `qr_flutter` |
| Emoji picker | `emoji_picker_flutter` |
| i18n | `flutter_localizations` + `intl` + ARB / `gen-l10n` |
| Charts (planned, not yet a dependency) | `fl_chart` |
| Camera (planned, low priority) | `image_picker` (not `camera`) |

**Target platforms:** Android, iOS, Linux. **Development happens exclusively on Arch
Linux.** iOS builds require macOS/Xcode and are done via CI or a borrowed Mac — never
assume an iOS build can be run locally.

## Commands

```bash
flutter run -d linux          # Linux is the dev target — fastest inner loop
flutter analyze               # expected to be zero issues
flutter test

dart run build_runner build   # after ANY change to a drift table
dart run build_runner watch   # leave running while working
flutter gen-l10n              # forced; run/build does it automatically

flutter build linux --release
flutter build apk --release --split-per-abi
```

## Architectural rules

These are deliberate and load-bearing. Do not work around them without asking.

### 1. The transaction log is an append-only ledger

Every consumption, top-up and adjustment is a permanent row. **Never DELETE a
transaction, and never rewrite one.** The only permitted update is the one-way void
described below.

#### Money and direction

`amountMinorUnits` is **signed**, and it is the **line total**, never a unit price.
Positive means the member holds credit, negative means they owe — the app is a prepaid
tab, so a top-up is positive and a consumption is negative.

Keeping the direction in the amount rather than deriving it from `type` makes the
balance one type-agnostic `SUM(amount_minor_units) WHERE voided_at IS NULL`, so a fourth
transaction type would need no change to any balance logic.

Two €1.50 colas is one row: `quantity = 2`, `itemUnitPriceSnapshot = 150`,
`amountMinorUnits = -300`. `quantity` is display only — the multiplication is already
done, in `TransactionsDao.logConsumption`, the only code that computes it.

#### Snapshots: items yes, users no

Each transaction freezes the item's name and unit price in `itemNameSnapshot` and
`itemUnitPriceSnapshot` rather than joining to the current items table: renaming "Cola"
or repricing it must never rewrite history. Users are deliberately **not** snapshotted —
the row holds a plain `userId`. Items are *catalogue entries*, so history keeps what was
actually paid; users are *identities*, so fixing a typo fixes it everywhere.

#### The logical day

A third column is frozen at write: `logicalDate`, a `YYYY-MM-DD` string.

**A day runs 07:00 → 07:00.** The fridge is used past midnight, so a drink at 01:00
belongs to the evening before, not to the new calendar date. Every "per day" question
uses this, never the raw calendar date of `createdAt`.

The rule lives in `lib/data/logical_day.dart` as pure functions, with `logicalDayStart`
a constant rather than a setting: it is a business rule, not user state.
`TransactionsDao` stamps `createdAt` and `logicalDate` from **one** `DateTime.now()`
read — the column's `currentDateAndTime` default is bypassed on purpose, so a row
inserted microseconds either side of 07:00 cannot take its timestamp and its day from
different days. It is **stored rather than derived** because the equivalent SQL
expression can never be indexed — see the gotcha below.

#### Voiding

A mis-tap should vanish, not appear twice, so a row can be voided: `voidedAt` goes from
null to a timestamp and `voidedNote` records why. The transition is **one-way** — never
cleared, never DELETEd, and the DAO guards on `voidedAt IS NULL` so a second call is a
no-op. The row itself is never rewritten, and voided rows still render in history,
struck through: hidden from balances, not from the record.

Gate it by time and PIN, because there is no login and anyone can tap anything: an
inline **Undo** with no PIN within ~60 seconds, and the admin PIN plus a note after.

Use an `adjustment`, not a void, for a genuine correction that is not a mistake ("Jonas
paid €10 cash"). **Voiding erases; adjusting records.**

### 2. Money is an integer in minor units. Always

`IntColumn get priceMinorUnits => integer()();`

Never `double`, never `REAL`. Floating-point drift in a ledger that runs unattended
for years is exactly the bug we're avoiding.

Only **EUR** is supported today, and EUR uses 100 minor units — but never assume that
divisor. Most currencies use 100; JPY/KRW use 0, some Gulf-state dinars 1000.

Money is always formatted through `AppSettings.of(context).formatMoney(minorUnits)` —
never inline `NumberFormat`, never a hand-rolled `/ 100` or `'€'` literal. It is an
extension on `AppSettingsData`, so it carries the stored language and currency and
callers pass neither by hand. Two things inside it are load-bearing: `name:` is always
explicit, or the currency comes from the locale and ignores the setting; and it must be
`simpleCurrency`, not `currency`, which renders `EUR 12,50` rather than `€ 12,50` unless
given an explicit `symbol:`.

### 3. Settings live in SharedPreferences, not the database

The database holds the **ledger and its catalogue** — users, groups, items,
transactions. Device and app configuration lives in preferences. A backup is a backup
of the data; it is not expected to carry the tablet's colour scheme.

Three files in `lib/settings/`, each with one job:

- **`settings_data.dart`** — `AppThemeMode`, the immutable `AppSettingsData` holding
  every setting, and `formatMoney`. Pure Dart plus `TimeOfDay`: no plugins, no widgets.
  The constructor defaults *are* the fresh-install configuration.
- **`settings_store.dart`** — the only file that knows a preference key exists. Opens a
  `SharedPreferencesWithCache` over a declared allow-list, so `read()` is synchronous.
- **`app_settings.dart`** — the `AppSettings` widget that publishes the value to the
  tree, resolves the dark-mode schedule, and owns writes.

Consequences that matter:

- **`AppSettingsData` must keep its `==`/`hashCode` covering every field.** The theme
  schedule re-resolves once a minute and short-circuits on equality; without it the
  whole tree rebuilds every minute.
- **`copyWith` uses a sentinel for the four nullable fields.** Passing `null` clears
  them; omitting the argument leaves them alone. `SettingsTextField.onCommit` passes
  `null` for an emptied field, so a naive `copyWith` would silently ignore a clear.
- Writes go through `AppSettings.writeOf(context)`, which takes a whole new value:
  `write(settings.copyWith(seedColorArgb: x))`. It applies via `setState` and persists
  behind that — **no screen awaits a settings write, and no screen reaches for the
  database to read a setting.**
- Adding a setting is a field, a key in the allow-list, and a control. No codegen, no
  `schemaVersion` bump, no migration.

**`AppSettings` sits above `MaterialApp`**, in `runApp`, because `MaterialApp`'s own
arguments are settings and a widget can only read an ancestor `InheritedWidget`. That
does not strand `formatMoney`: the lookup walks up from the *calling* widget, and real
callers are screens below `MaterialApp`, so both it and `Localizations` resolve.

### 4. Theming

Global admin-chosen **seed color** drives `ColorScheme.fromSeed`. Per-user colors
generate a *second* scheme wrapped around user-specific subtrees via a `Theme` widget
— never paint raw user colors onto widgets directly, as that breaks Material contrast
guarantees.

Both admin and users pick from a **fixed curated palette** of Material-friendly
colors, rendered as a hand-rolled grid of circular swatches. No color-picker package.

Colors are stored as ARGB `int` (the resolved color, **not** an index into the
palette, so retiring a palette color doesn't silently recolor users).

`users.seedColorArgb` is **non-null**: every member has their own accent, assigned at
random on creation, so there is no "falls back to the global seed" path.

Build a per-user subtree with `appTheme(user.seedColorArgb, Theme.of(context).brightness)`,
**not** `Theme.of(context).copyWith(colorScheme: ...)`. `copyWith` swaps the scheme but
leaves the derived component themes and the legacy colors on the *app's* palette, giving
a half-recolored page. `widgets/user_avatar.dart` is the reference implementation.

Both `schemeFor` and `appTheme` are **memoized** on `(seedArgb, brightness)`, because a
list of members is otherwise one `ColorScheme.fromSeed` per avatar per frame. Repeat
calls return the *same instance*, so `ThemeData ==` short-circuits on identity. The
caches never evict — seeds only come from the curated palette, so free color picking
would break that. They survive hot reload but not hot restart, so editing the scheme
variant and hot-reloading shows stale colors.

Light/dark is a stored `AppThemeMode` — `light`, `dark`, or `scheduled` between two
wall-clock times. There is deliberately no "follow system": a kiosk tablet's system
theme is fixed and irrelevant, and `ThemeMode.system` is never produced. `AppSettings`
re-resolves the schedule on every write, once a minute, and on app resume — the clock
crossing a boundary is not something a write can signal.

The window bounds are `TimeOfDay` in memory and minutes-since-midnight in storage, via
`lib/utils/time_of_day.dart`. The window logic is the top-level `isDarkAt`: pure, and
unit-tested without a widget harness.

### 5. Localization

UI language is **English first** — `app_en.arb` is the template ARB file. Dutch
(`app_nl.arb`) is a secondary locale, and the primary one actual users will see day
to day (the group is Dutch-speaking) — English exists as the template because that's
the language the code and this document are written in. Code, comments, and
identifiers are in English regardless.

The active language comes from the **stored setting**, not the system locale — a kiosk
tablet's system locale is fixed and often wrong. It is never seeded from the device
either: a fresh install starts at `en` and the first-run wizard is where that changes.

**Language only — no regional locales.** The stored `languageCode` is `en` or `nl`.
Regional variants were tried and removed: they bought number-grouping conventions nobody
notices in a fridge and cost a derivation layer over intl's internal tables.

The offered languages are **`AppLocalizations.supportedLocales`**, derived by `gen-l10n`
from the ARB files present — adding `app_de.arb` is all it takes to offer German. Their
display names live in the ARB files, each language named in its own language, so the
label does not change with the active locale.

**Item names and user names are user data, not UI strings.** They never appear in ARB
files.

Money and dates must be formatted locale-aware (`nl` writes `€ 12,50`, `en` writes
`€12.50`). Always go through `formatMoney` — never hand-roll `'€${x.toStringAsFixed(2)}'`,
and never assume symbol placement, spacing, or decimal-digit count.

### 6. Avatars

Render order: uploaded image if present → emoji. **There is no initials fallback** —
`avatarEmoji` is non-null, so every member always has something to draw.

```dart
TextColumn get avatarEmoji => text()();              // TEXT — emoji are multi-codepoint
BlobColumn get avatarImage => blob().nullable()();   // reserved; feature not built yet
```

`avatarEmoji` is TEXT because emoji use skin-tone modifiers and ZWJ sequences and
cannot be stored as a single int codepoint. The blob column exists now specifically so
the future camera feature needs no migration — **avatar images go in the database, not
into a directory beside it.**

**The create screen picks a random emoji and a random palette colour** for a new member,
which is why both columns are non-null and neither has a schema default: a default would
let an insert quietly give everyone the same face. `UsersDao.createUser` therefore takes
`avatarEmoji` and `seedColorArgb` as required arguments — the data layer has no business
knowing the curated palette, so the caller does the picking. `ItemsDao.createItem`
requires `emoji` for the same reason.

Group emoji (`user_groups`, `item_groups`) stay **nullable**: a group is named, and an
admin creating one is choosing deliberately rather than being handed a random face.

### 7. Deletion is soft for anything the ledger references

Two tiers, decided by what points at the row.

**`users` and `items` are soft-deleted.** Every consumption row holds a permanent
foreign key to both, so after a member's first tap they can never be removed without
destroying history. `archivedAt` is a nullable timestamp and list queries filter
`archived_at IS NULL`. Preferred over a boolean `active` because it carries *when* for
free, and it matches `voidedAt`.

A member whose balance is not zero **cannot be archived** — settle up or post an
`adjustment` first. Archiving is not a way to make a debt disappear quietly.

**`user_groups` and `item_groups` are hard-deleted, and only while unreferenced.** They
carry no `archivedAt` at all.

"Unreferenced" means **no rows at all, including archived ones**. This is the subtle
part: a departed member is archived rather than deleted, and their row still holds a
`groupId`. A group can therefore look empty in the UI while archived rows still pin it.
Counting only active members and hard-deleting would leave dangling references that
crash whenever an archived member's history is rendered. Because archiving and deleting
a group would then have identical preconditions, a soft delete on groups could never be
meaningfully set — hence no column.

Being empty is the *only* precondition. The last group of a kind may be deleted, the
seeded one included — the management screen has a `+` button. A default group of each
kind is seeded in `onCreate` so a fresh install can add a member without visiting the
group screen first, named plainly (`General`) so an admin renames it rather than reading
it as sample data. The practical consequence is that a group used for a season is
effectively permanent; the deletion that actually happens is "I typed the name wrong ten
seconds ago", and that group genuinely is empty.

The count and the delete run in **one transaction** so the check cannot go stale, and it
throws `GroupInUseException` rather than letting a constraint blow up. In the UI, disable
the delete action with an explanation ("3 members, including 1 archived") rather than
letting it fail after the tap.

## Known gotchas

- **`lib/l10n/app_localizations*.dart` are gitignored**, so a fresh clone has broken
  imports and a red `flutter analyze` until codegen has run once. Run `flutter gen-l10n`
  before analyzing a fresh clone.
- **Emoji come from the platform's own font — none is bundled.** Android and iOS ship
  one; a Linux box needs an emoji font installed system-wide (on Arch,
  `noto-fonts-emoji`) or emoji render as monochrome outlines or tofu. That is a
  deployment-image requirement, not something the app can fix.
- **Set `height: 1.0` on any `TextStyle` that renders a bare emoji.** Emoji fonts carry
  generous leading, so without it a `Center` visibly puts the glyph off-centre. Also set
  an explicit `color`: where no colour emoji font exists the glyph is drawn monochrome
  in the text colour, and inheriting `DefaultTextStyle` inside a tinted surface can make
  it invisible. `widgets/user_avatar.dart` does both.
- **Do not pass a `fontSize` in `EmojiPickerDialog`'s `emojiTextStyle`.** The package
  merges the style it is given over one that already carries its responsive per-cell
  size, so a `fontSize` there freezes the grid's glyphs and stops them scaling.
- **`emoji_picker_flutter`'s widgets ignore the ambient `Theme`** — every colour is an
  explicit argument defaulting to blue and grey, so `EmojiPickerDialog` threads the whole
  `ColorScheme` in by hand and a new config knob needs the same or it renders blue. Two
  of its defaults are overridden: `columns` is 10 (too small for wet fingers) and
  `initCategory` is `Category.RECENT`, the tab `RecentTabBehavior.NONE` removes.
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
- **A new preference key must be added to the store's allow-list.**
  `SharedPreferencesWithCache` preloads exactly the declared keys; one that is missing
  reads as absent forever, which silently looks like "the default".
- **`SharedPreferencesWithCache` needs a test double, not `setMockInitialValues`.** That
  helper targets the legacy synchronous API. Set
  `SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty()`
  (from `shared_preferences_platform_interface`, a dev dependency for exactly this).
- **An index on a `localtime` expression is accepted and then fails on the first
  INSERT.** This is why `logicalDate` is a stored column rather than a view over
  `createdAt`:

  ```sql
  CREATE INDEX idx ON t (date(created_at - 25200, 'unixepoch', 'localtime'));
  -- accepted, no error
  INSERT INTO t(created_at) VALUES (1757300000);
  -- Error: non-deterministic use of date() in an index
  ```

  Dropping `localtime` makes it indexable but wrong: the boundary shifts an hour every
  winter, silently misfiling anything logged between 06:00 and 07:00. So a derived
  logical day could only ever be full-scanned, with no composite `(user_id,
  logical_date)` index possible.
- **Index names must be unique across the whole database**, not per table, and each
  becomes a camelCase getter on the database class — so an index named `users` would
  collide with the `users` table getter. Prefix every index with its table name.
- **A Dart-defined `View`'s `as()` body must not be parenthesised.** drift_dev walks the
  AST and accepts only method invocations and cascades, so
  `Query as() => (select(...)..where(...));` fails codegen with "invalid expression type
  ParenthesizedExpression". The class must also be `abstract`, its table getters
  bodyless. And its computed columns always generate as nullable whatever the expression
  — `SUM(...)` arrives as `int?` and a `coalesce` in the view will not change that, so
  collapse the `?? 0` in one place in the DAO.
- **SQLite leaves foreign key enforcement OFF by default.** It is turned on in
  `beforeOpen` with `PRAGMA foreign_keys = ON`. Never wrap that in a transaction — the
  pragma is silently ignored there. It runs *after* `onCreate`, so the seed inserts are
  not themselves checked.
- **A constraint violation is a `SqliteException` in tests but a `DriftRemoteException`
  in the app.** `driftDatabase` uses `NativeDatabase.createBackgroundConnection`, so the
  error crosses an isolate boundary and the real cause lands in `.remoteCause`. Prefer
  the DAOs' own typed errors, and match on the message when the raw violation is the
  subject.
- **Generated `.g.dart` files are excluded from analysis.** drift's own
  `ignore_for_file: type=lint` header silences the linter but not analyzer warnings, and
  a view's generated `Query?` getter trips `strict-raw-types`.
- Drift schema changes require re-running `build_runner` **and** bumping `schemaVersion`
  with a migration step. While nothing is deployed, migrations are skipped — but
  `onCreate` will not re-run against an existing database file, so **delete the dev
  database** after a schema change or every query fails with `no such table`.
- **Both state files live in the application support directory**
  (`~/.local/share/xyz.jpsystems.paats_dranklijst/` on Linux):
  `paats_dranklijst.sqlite` and `shared_preferences.json`. Deleting the database alone
  no longer replays the first-run wizard — `setupCompletedAt` is a preference, so the
  JSON file has to go too. The database path is set explicitly via
  `DriftNativeOptions.databaseDirectory`, because drift_flutter's own default is the
  *documents* directory, which on Linux is the user's real `~/Documents`.
  `path_provider` is a direct dependency only because that override needs it.
- **Drift's `.watch()` streams only see writes made through the same `AppDatabase`
  instance.** Editing the file with the `sqlite3` CLI while the app runs changes nothing
  on screen until a restart. This is a property of drift, not a bug to fix.

## Layout

```txt
lib/
  main.dart                  # runApp, MaterialApp wiring, AppShell
  l10n/                      # ARB files (committed) + generated localizations (gitignored)
  settings/
    settings_data.dart       # AppSettingsData, AppThemeMode, formatMoney; pure
    settings_store.dart      # the only file that knows a preference key
    app_settings.dart        # ambient InheritedWidget; sits above MaterialApp
  data/
    database.dart            # AppDatabase, schemaVersion, migrations, FK pragma
    database_provider.dart   # Database InheritedWidget; owns the AppDatabase instance
    errors.dart, group_usage.dart, logical_day.dart
    tables/                  # one file per table; enums live beside their table
    views/user_balances_view.dart
    daos/                    # users_dao, items_dao, transactions_dao
  theme/app_theme.dart       # memoized ColorScheme.fromSeed / ThemeData helpers
  utils/                     # banking (IBAN + EPC), random_emoji, time_of_day
  screens/
    settings_screen.dart     # admin settings; openSettings() is the PIN gate
    setup_wizard.dart        # first-run wizard
    start_screen.dart, users_screen.dart, stats_screen.dart   # the three tabs
    management_stub_screen.dart
  widgets/
    palette_picker.dart      # curated color lists, inline picker + swatch grid dialog
    emoji_picker_dialog.dart # emoji_picker_flutter's grid in a dialog, themed by hand
    user_avatar.dart         # a member's emoji in a circle from their own seed color
    pin_dialog.dart          # keypad, and the enter/set dialogs around it
    settings_text_field.dart # commit-on-blur field bound to one setting
    settings_fields.dart     # the controls the settings screen and wizard share
    empty_state.dart, epc_qr_code.dart
build.yaml                   # drift codegen options (manager API off)
```

## Current state

Settings and theming are complete: every setting has a control that writes immediately,
and the app re-themes and re-localizes as choices are made. The tree is
`Database` -> `AppSettings` -> `MaterialApp`. `MainApp.home` is the wizard while
`setupCompletedAt` is null and `AppShell` afterwards, so finishing the wizard swaps
`home` over with no navigation. The wizard holds **no pending state**: every step writes
straight through and reuses the settings screen's own fields from
`widgets/settings_fields.dart`, so an interrupted wizard reappears with what was already
chosen in place.

**The schema is complete; almost none of it has UI yet.** Five tables — `user_groups`/
`users` and `item_groups`/`items` (each a group table and a leaf table with a non-null
`groupId`, `sortOrder` and `archivedAt`), plus `transactions`. One view, `user_balances`:
`SUM` per member with voided rows excluded, not a cache but an indexed query. Members
with no live transactions have no row in it, so readers left-join and read a missing row
as 0. Five indexes carry it; the composites the Stats page will want are deliberately
not added, because an unused index is write cost on every ledger row.

Three DAOs cover the queries. `TransactionsDao` is the only writer of a ledger row, and
its two single-day queries take a **required** `at` rather than defaulting to now.

Several DAO methods, `EpcQrCode`, `logicalDayFromKey` and a few ARB keys are written
ahead of the UI that will consume them — deliberate scaffolding, not dead code.

Still target design, not code: **the rest of the UI over this schema.** The Start page
is a temporary demo of `UserAvatar` and `ColorPicker` over local `setState` — replace the
body when the real Start page is built, but keep the settings `IconButton`, the only
route into settings. Members and Stats are empty states, and the three management cards
lead to one stub screen. `test/emoji_picker_dialog_test.dart` is the one **widget** test:
`EmojiPicker` measures itself off `constraints.maxWidth` and puts a `Flexible` in a
`Column`, so a missing bound is a layout exception no unit test would catch.

## Working preferences

- The repo owner is new to Flutter. Explain non-obvious Flutter idioms briefly when
  introducing them; don't assume familiarity with Dart conventions.
- **Never touch git.** No commits, branches, staging or amends unless asked in that
  message. Read-only git is fine. Work lands on `main`, and the owner writes his own
  commit messages.
- **Never reference this document's rules from a code comment.** No `see rule 2`, no
  `CLAUDE.md rule 4`. A comment says the thing itself in a clause, or it is deleted —
  otherwise reordering a rule silently invalidates comments across `lib/`.
- **Keep comments short.** One line for a simple point. Don't restate what the code
  already says, and don't justify every routine choice. A short paragraph is for
  reasoning that is genuinely non-obvious *and* not already written down here.
- Prefer small, verifiable steps. After changes, run `flutter analyze` and
  `flutter run -d linux` to confirm the app still builds.
- `analysis_options.yaml` goes beyond `flutter_lints` — strict type checking
  (`strict-casts`/`strict-inference`/`strict-raw-types`) plus extra rules. `analyze`
  is expected to be **zero issues**, so treat lint findings as build failures. Two
  that bite most often: imports within `lib/` must be **relative**
  (`prefer_relative_imports`), and every `Future` must be awaited or explicitly
  wrapped in `unawaited(...)`.
- `users_dao.dart` and `items_dao.dart` are structurally parallel, and so are the two
  group tables. **Leave that duplication alone** — generic helpers over drift's
  generated table and companion types read worse than the repetition.
- Do not add dependencies without flagging the tradeoff first. The dependency list
  above is deliberate and minimal.
- Do not add networking, telemetry, analytics, crash reporting, or cloud sync.
