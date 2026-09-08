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

Every consumption, top-up and adjustment is a permanent row. **Never DELETE a
transaction, and never rewrite one.** The only permitted update is the one-way void
described below.

#### Money and direction

`amountMinorUnits` is **signed**, and it is the **line total**, never a unit price.
Positive means the member holds credit, negative means they owe — the app is a prepaid
tab, so a top-up is positive and a consumption is negative.

Keeping the direction in the amount rather than deriving it from `type` makes the
balance one type-agnostic query, so a fourth transaction type would need no change to
any balance logic:

```sql
SELECT SUM(amount_minor_units) FROM transactions
WHERE user_id = ? AND voided_at IS NULL
```

Two €1.50 colas is one row: `quantity = 2`, `itemUnitPriceSnapshot = 150`,
`amountMinorUnits = -300`. `quantity` is display only — the multiplication is already
done. `TransactionsDao.logConsumption` is the only code that computes this, so the
invariant lives in exactly one place.

#### Snapshots: items yes, users no

Each transaction freezes the item's name and unit price at purchase time in
`itemNameSnapshot` and `itemUnitPriceSnapshot` rather than joining to the current items
table. Renaming "Cola" or changing its price must never rewrite history.

Users are deliberately **not** snapshotted — the row holds a plain `userId` foreign key.
The asymmetry is the point: items are *catalogue entries*, so history keeps what was
actually paid; users are *identities*, so fixing a typo in a name should fix it
everywhere, old rows included.

#### Voiding

A mis-tap should vanish, not appear twice in history, so a row can be voided: `voidedAt`
goes from null to a timestamp and `voidedNote` records why.

- The transition is **one-way**. Never cleared, never DELETEd. The DAO guards on
  `voidedAt IS NULL`, so a second call is a no-op rather than a second timestamp.
- The row itself is never rewritten — amount, snapshots and `createdAt` stay frozen
  exactly as recorded.
- Voided rows still render in history, struck through. They are hidden from balances,
  not from the record.

Gate it by time and PIN, because there is no login and anyone can tap anything: an
inline **Undo** with no PIN within ~60 seconds of creation, which covers essentially
every real case, and after that the admin PIN plus a `voidedNote`.

Use an `adjustment`, not a void, for a genuine correction that is not a mistake ("Jonas
paid €10 cash"). **Voiding erases; adjusting records.**

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
`AppLocalizations.of(context)` pattern: it carries the stored language and currency
code, so callers never pass either by hand.

```dart
String formatMoney(int minorUnits) {
  final format = NumberFormat.simpleCurrency(
    locale: _settings.languageCode,
    name: _settings.currencyCode,
  );
  final divisor = pow(10, format.decimalDigits ?? 2);
  return format.format(minorUnits / divisor);
}
```

`name:` is always passed explicitly. Without it the currency is derived from the
locale, which would ignore the setting whenever the two disagree.

It must be `simpleCurrency`, **not** `currency`. `NumberFormat.currency` fills the
pattern's `¤` placeholder with the currency *code* unless an explicit `symbol:` is
passed, so it renders `EUR 12,50` instead of `€ 12,50`. `simpleCurrency` resolves the
symbol from the code via intl's own lookup table, which keeps the symbol derived from
data rather than hardcoded.

`currencyCode` defaults to `'EUR'` and is set from the settings screen or the
first-run wizard. It flows through `AppSettings` as data rather than a hardcoded
symbol, so nothing at a call site assumes euros.

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
  ephemeral widget state uses `setState`. The one exception is `AppSettings`, which
  subscribes to its stream directly because it has to merge it with a timer — see
  rule 4.

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
random on creation (rule 6), so there is no "falls back to the global seed" path.

Light/dark is a stored `AppThemeMode` — `light`, `dark`, or `scheduled` between two
wall-clock times. There is deliberately no "follow system": a kiosk tablet's system
theme is fixed and irrelevant. `AppSettings` resolves it to a real `ThemeMode`, so
`ThemeMode.system` is never produced. It re-resolves on every settings emission, once
a minute, and on app resume — the clock crossing a boundary is not something the
database stream can tell it about.

The two window bounds (`darkStart`, `darkEnd`) are **stored as minutes since
midnight** — comparable with integer arithmetic and never malformed — but surfaced as
`TimeOfDay` by `TimeOfDayConverter` (`lib/data/converters.dart`), so no call site
does `~/ 60` or `* 60` by hand and `showTimePicker` needs no conversion in either
direction. The window logic itself is the top-level `isDarkAt` in
`lib/app_settings.dart`: pure, and unit-tested without a widget harness.

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

**`AppSettings`** (in `lib/app_settings.dart`) publishes the settings row to the whole
tree. It is a plain widget wrapping a private `_AppSettingsScope` `InheritedWidget`,
the same shape Flutter's own `Theme` uses. `AppSettings.of(context)` returns the
`SettingsRow` itself — no accessor object in between — and
`AppSettings.themeModeOf(context)` returns the schedule-resolved `ThemeMode`, the one
value that is not a column.

`formatMoney` is an extension on `SettingsRow` in the same file, so
`AppSettings.of(context).formatMoney(1250)` reads exactly like
`AppLocalizations.of(context)` while staying a plain method on the row.

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

Render order: uploaded image if present → emoji. **There is no initials fallback** —
`avatarEmoji` is non-null, so every member always has something to draw.

```dart
TextColumn get avatarEmoji => text()();              // TEXT — emoji are multi-codepoint
BlobColumn get avatarImage => blob().nullable()();   // reserved; feature not built yet
```

`avatarEmoji` is TEXT because emoji use skin-tone modifiers and ZWJ sequences and
cannot be stored as a single int codepoint. The blob column exists now specifically so
the future camera feature needs no migration.

**The create screen picks a random emoji and a random palette colour** for a new member,
which is why both columns are non-null and neither has a schema default: a default would
let an insert quietly give everyone the same face. `UsersDao.createUser` therefore takes
`avatarEmoji` and `seedColorArgb` as required arguments — the data layer has no business
knowing the curated palette (rule 4), so the caller does the picking. `ItemsDao
.createItem` requires `emoji` for the same reason.

Group emoji (`user_groups`, `item_groups`) stay **nullable**: a group is named, and an
admin creating one is choosing deliberately rather than being handed a random face.

### 7. Deletion is soft for anything the ledger references

Two tiers, decided by what points at the row.

**`users` and `items` are soft-deleted.** Every consumption row holds a permanent
foreign key to both, so after a member's first tap they can never be removed without
destroying history. `archivedAt` is a nullable timestamp and list queries filter
`archived_at IS NULL`. Preferred over a boolean `active` because it carries *when* for
free, and it matches `setupCompletedAt` and `voidedAt`.

A member whose balance is not zero **cannot be archived** — settle up or post an
`adjustment` first. Archiving is not a way to make a debt disappear quietly.

**`user_groups` and `item_groups` are hard-deleted, and only while unreferenced.** They
carry no `archivedAt` at all.

"Unreferenced" means **no rows at all, including archived ones**. This is the subtle
part: a departed member is archived rather than deleted, and their row still holds a
`groupId`. A group can therefore look empty in the UI while archived rows still pin it.
Counting only active members and hard-deleting would leave dangling references that
crash whenever an archived member's history is rendered.

Because archiving and deleting a group would then have identical preconditions, a soft
delete on groups could never be meaningfully set — hence no column.

Being empty is the *only* precondition. The last group of a kind may be deleted, the
seeded one included, leaving the table empty — the management screen has a `+` button,
so an admin can always make another. There is deliberately no "at least one group" rule
to enforce; it would be one more failure mode for a state the UI can walk straight out
of.

A default group of each kind is still seeded in `onCreate`, so a fresh install can add
a member without visiting the group screen first. It is named plainly (`General`) so an
admin renames it rather than it looking like sample data.

Accept the practical consequence: a group in use for a season is effectively permanent,
since archived members keep it pinned. That matches reality — Chiro age groups don't
disappear. The deletion that actually happens is "I typed the name wrong ten seconds
ago", and that group genuinely is empty.

The count and the delete run in **one transaction** so the check cannot go stale, and it
throws `GroupInUseException` from `lib/data/errors.dart` rather than letting a constraint
blow up. In the UI, disable the delete action with an explanation ("3 members, including
1 archived") rather than letting it fail after the tap.

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
- **A `TypeConverter` used by a table must be imported by `lib/data/database.dart`,
  along with the Dart type it produces** — importing it in the table file is not
  enough. `database.g.dart` is a `part of` `database.dart` and so has no imports of
  its own; codegen succeeds either way and the failure only shows up as
  `'X' isn't a type` in the generated file at analyze time. The same applies to any
  enum used with `textEnum`: keep it in the table file, which `database.dart` already
  imports, rather than moving it somewhere only the table sees.
- **SQLite leaves foreign key enforcement OFF by default.** It is turned on in
  `beforeOpen` with `PRAGMA foreign_keys = ON`. Never wrap that in a transaction — the
  pragma is silently ignored there. Drift only toggles it around `alterTable`, so
  without the `beforeOpen` line a bad delete leaves dangling references rather than
  failing. It runs *after* `onCreate`, so the seed inserts are not themselves checked.
- **A Dart-defined `View`'s `as()` body must not be parenthesised.** drift_dev walks
  the AST and accepts only method invocations and cascades, so
  `Query as() => (select(...)..where(...));` fails codegen with "invalid expression
  type ParenthesizedExpression". Drop the parens. The class must also be `abstract`,
  with its table getters declared abstract and bodyless.
- **A view's computed columns always generate as nullable**, whatever the expression —
  drift hardcodes it. `SUM(...)` therefore arrives as `int?`, and `coalesce` in the view
  will not change the Dart type. Collapse the `?? 0` in one place in the DAO.
- **Index names must be unique across the whole database**, not per table, and each
  becomes a camelCase getter on the database class — so an index named `users` would
  collide with the `users` table getter. Prefix every index with its table name.
- **A constraint violation is a `SqliteException` in tests but a `DriftRemoteException`
  in the app.** `driftDatabase` uses `NativeDatabase.createBackgroundConnection`, so the
  error crosses an isolate boundary and the real cause lands in `.remoteCause`. A test
  asserting `isA<SqliteException>()` passes while the app's matching catch never fires —
  prefer the DAOs' own typed errors, and match on the message when the raw violation is
  the subject.
- **Generated `.g.dart` files are excluded from analysis.** drift's own
  `ignore_for_file: type=lint` header silences the linter but not analyzer warnings, and
  a view's generated `Query?` getter trips `strict-raw-types` — a raw type that cannot be
  spelled differently from our source.
- Drift schema changes require re-running `build_runner` **and** bumping
  `schemaVersion` with a matching migration step. As long as we are in the development
  phase and no deployments have been done, migrations are not needed — but that means
  `onCreate` will not re-run against a database file that already exists, so **delete
  the dev database** after a schema change or every query fails with `no such table`:
  `rm ~/.local/share/xyz.jpsystems.paats_dranklijst/paats_dranklijst.sqlite`. This also
  clears `setupCompletedAt`, so the wizard reappears.
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
                             # also resolves the dark-mode schedule and formatMoney
  l10n/                      # ARB files (committed) + generated localizations (gitignored)
  data/
    database.dart            # AppDatabase, schemaVersion, migrations, FK pragma
    database_provider.dart   # Database InheritedWidget; owns the AppDatabase instance
    converters.dart          # drift TypeConverters; TimeOfDay <-> minutes so far
    errors.dart              # typed domain failures the DAOs throw (see rule 7)
    tables/                  # drift table definitions
      settings_table.dart    # }
      user_groups_table.dart # }
      users_table.dart       # } one file per table; enums live beside their table
      item_groups_table.dart # }
      items_table.dart       # }
      transactions_table.dart# }
    views/
      user_balances_view.dart # per-member SUM, voided rows excluded
    daos/                    # queries, grouped by concern
      settings_dao.dart      # the single settings row
      users_dao.dart         # members + their groups + balances
      items_dao.dart         # drinks + their groups
      transactions_dao.dart  # the ledger; the only writer of a transaction row
  theme/
    app_theme.dart           # ColorScheme.fromSeed helpers
  utils/
    banking.dart             # IBAN mod-97 and currency-code checks; EPC QR payload
  screens/
    app_shell.dart           # NavigationBar frame; owns the selected tab
    settings_screen.dart     # admin settings; openSettings() is the PIN gate
    setup_wizard.dart        # first-run wizard
    management_screens.dart  # CRUD stubs behind the management cards
    start_screen.dart        # } the three tabs; empty states for now
    users_screen.dart        # }
    stats_screen.dart        # }
  widgets/
    palette_picker.dart      # curated color lists, inline picker + swatch grid dialog
    pin_dialog.dart          # keypad, and the enter/set dialogs around it
    settings_text_field.dart # commit-on-blur field bound to one settings column
    empty_state.dart         # centred icon and message
    epc_qr_code.dart         # SEPA payment QR code; byte-mode wrapper over buildEpcPayload
    member_row.dart          # member list row shape; not rendered yet
test/                        # unit tests; no widget tests yet
build.yaml                   # drift codegen options (manager API off)
```

## Current state

Implemented: rules 2, 4 and 5 in full for the app's own settings, and rule 3's
foundation. Every setting has a control that writes straight to the database and takes
effect immediately.

The settings screen groups its controls into three cards — Appearance, Admin, Settling
up — under section headers, below the management cards. The section header, the group
card and the note line are private widgets in `settings_screen.dart`, its only consumer.
`SettingsTextField` is not: the wizard needs the same field, so it lives in
`widgets/`.

The tree is `Database` -> `AppSettings` -> `MaterialApp`. `Database`
(`lib/data/database_provider.dart`) owns the `AppDatabase` and is stateful so the
connection opens and closes exactly once. `AppSettings` watches the settings row and
feeds `MaterialApp`'s `locale:`, `theme:`, `darkTheme:` and `themeMode:`. It renders
nothing for the frame or two before the first row arrives — the native launch screen
covers that gap, so there is no splash screen.

`MainApp.home` is the wizard while `setupCompletedAt` is null, and `AppShell`
afterwards. The wizard writes that column on its last step, so finishing it swaps
`home` over with no navigation.

The wizard holds **no pending state**: every step writes straight to the database like
the settings screen, and reuses the same controls, so the app re-themes and
re-localizes as the choices are made. Only `setupCompletedAt` waits for the end — an
interrupted wizard reappears with what was already chosen still in place. It needs no
`Theme` or `Localizations` override to preview a choice, because the real ones above
`MaterialApp` already follow the database.

`AppShell` owns the selected tab as `State` seeded once in `didChangeDependencies`.
Deriving it from the settings row on every build would throw whoever is using the app
back to the resting page on every unrelated settings change. `AppShellState
.goToRestingPage()` is the single call the consumption flow will make once a drink has
been logged.

The admin PIN is exactly `pinLength` (4) digits. `widgets/pin_dialog.dart` holds the
lock-screen-style keypad and both dialogs around it — `PinEnterDialog` for the gate,
`PinSetDialog` for choose-then-confirm — so no other screen builds PIN UI or handles a
raw PIN string. The wizard and the settings row both go through `showPinSetDialog`.

**The schema is complete; none of it has UI yet.** Six tables and one view:

- `settings` — single-row, typed columns, a `CHECK (id = 1)` constraint, and the row
  inserted in `onCreate` so no code anywhere handles "settings is null". Two of its
  columns go through a converter: `themeMode` (drift's own `textEnum`) and
  `darkStart`/`darkEnd` (`TimeOfDayConverter`, see rule 4).
- `user_groups` / `users` and `item_groups` / `items` — the two catalogs, each a group
  table and a member table with a non-null `groupId`, `sortOrder`, and (on `users` and
  `items` only) `archivedAt`. `users.avatarEmoji`, `users.seedColorArgb` and
  `items.emoji` are non-null and picked at random by the create screen (rule 6); the two
  group tables' `emoji` stay nullable.
- `transactions` — the append-only ledger of rule 1, with a `TransactionType` textEnum,
  a signed `amountMinorUnits`, the two item snapshot columns, and the one-way
  `voidedAt`.
- `user_balances` — a Dart-defined view: `SUM(amount_minor_units)` per member with
  voided rows excluded. Not a cache; an indexed query. Members with no live
  transactions have no row in it, so readers left-join and read a missing row as 0.

Four indexes carry it: `users(group_id)`, `items(group_id)`,
`transactions(user_id, voided_at)` for balances, and `transactions(created_at)` for the
Start page. Foreign keys are enforced (`beforeOpen`), so a bad delete fails loudly.

`schemaVersion` is 1 and the `onUpgrade` scaffolding is empty. Nothing is deployed, so
schema changes are made by editing the tables and **deleting the dev database file**
rather than writing a migration.

Nothing is seeded from the device. A fresh database takes every value from the schema
defaults — `en`, `EUR`, teal, scheduled dark mode — plus one `General` group of each
kind (rule 7), and the wizard is where an admin changes them.

Four DAOs cover the queries. `UsersDao` also exposes `MemberWithBalance` (a member, her
group and her balance in one row) and `GroupUsage` (active and archived counts, so the
UI can explain a disabled delete). `TransactionsDao` is the only writer of a ledger row.
`test/database_test.dart` covers the invariants that matter — signed balances, snapshot
freezing, one-way voiding, the archive and group-deletion guards — against an in-memory
database through the `AppDatabase({QueryExecutor? executor})` seam.

Still target design, not code: **all of the UI over this schema**, plus per-user theming
and avatars. The Start, Members and Stats pages are empty states, and the three
management cards lead to stubs. `widgets/member_row.dart` carries the member row's two
tap targets (avatar opens the account page, name starts a consumption) but nothing
renders it yet.

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
