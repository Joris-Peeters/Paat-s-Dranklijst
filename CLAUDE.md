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
- Users are adults — leaders, ex-leaders and friends of the Chiro group — tapping
  with cold, wet fingers on a fridge door. Touch targets must be generous. UI must
  be obvious without instruction.
- **Portrait-first**, and a **tablet** is the primary form factor — a phone is a
  secondary one that must still work, not a size the layout is designed around.
  Landscape is not a target: the tablet is bolted to a fridge door one way up.
- **No networking.** No audio. No device integrations beyond (eventually) the camera.

## Stack

| Concern | Choice |
| --- | --- |
| Framework | Flutter |
| UI | Material 3 (`useMaterial3: true`), built-in widgets only |
| App state | Drift `.watch()` streams + `StreamBuilder`; `setState` for ephemeral widget state. **No state-management package** — no Provider, Riverpod, BLoC or GetX. |
| Navigation | `Navigator.push` / `Navigator.pop`. **No `go_router`** — a kiosk has no URLs and no deep links to route. |
| Database | `drift` + `drift_flutter` |
| Settings | `shared_preferences` |
| QR codes | `qr` for the matrix, drawn by `widgets/qr_matrix.dart` |
| Compression | `archive` — bzip2 for the balances QR code |
| Emoji picker | `emoji_picker_flutter` |
| i18n | `flutter_localizations` + `intl` + ARB / `gen-l10n` |
| Charts | `fl_chart` — vertical bars and lines; ranked lists are plain widgets |
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

Every consumption, top-up and adjustment is a permanent row. **Never rewrite a
transaction**, and never DELETE one except through the five-second snackbar undo
described below. The only permitted updates are the one-way void and confirming a
top-up, both also below.

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

#### Undoing: two mechanisms, not one

There is no login and anyone can tap anything, so which mechanism applies is decided by
*when*, not by who asks.

**Within 5 seconds: the snackbar Undo hard-DELETEs the row.** Logging a consumption
raises a snackbar with an **Undo** action, and taking it removes the row outright — no
PIN, no trace, no strikethrough in history. This is one of two deliberate exceptions to
append-only. It is safe precisely because it is unreachable by anyone but the person
still standing at the fridge, and a row that existed for five seconds has told nobody
anything. The other is a **database reset** from admin settings, which saves a backup
first. Nothing else in the app may DELETE a transaction.

**After that: voiding, and it always takes the admin PIN.** There is no grace period —
once the snackbar is gone, correcting a row is an admin action every time. `voidedAt`
goes from null to a timestamp and `voidedNote` records why. The transition is
**one-way** — never cleared, never DELETEd, and the DAO guards on `voidedAt IS NULL` so
a second call is a no-op. The row itself is never rewritten, and voided rows still
render in history, struck through: hidden from balances, not from the record.

Use an `adjustment`, not a void, for a genuine correction that is not a mistake ("Jonas
paid €10 cash"). **Voiding erases; adjusting records.**

#### Confirming top-ups

A top-up is logged the moment someone taps **Paid** and counts toward the balance
straight away; nothing at the fridge can check the money arrived. `confirmedAt` is the
admin's tick against the bank statement or cash box. It is **bookkeeping, not
accounting**: balances ignore it, and a pending top-up counts exactly like a confirmed
one.

A top-up is *pending* while `confirmedAt` and `voidedAt` are both null — bank transfer
or cash alike, since the app does not record which. The pending list and its count share
one predicate in `TransactionsDao`, and the partial index `transactions_pending_top_ups`
repeats it, so it holds only the backlog rather than every ledger row.

`confirmTopUp` guards on that predicate, so a second call or a non-top-up is a no-op.
The one way back is the snackbar Undo raised right after confirming, which clears it
again — the same short window the consumption snackbar gets, for the same reason. A
payment that never came is **voided**, not left unconfirmed: that is what takes the
credit back out.

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

**Every user-facing string goes through the ARB files — no hardcoded literals in a
widget**.

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

A **database reset** is the one exception to all of this. Behind the PIN, it
hard-deletes every transaction, and optionally every user or item with its groups. It
reseeds nothing and always saves a `_before-reset` backup first (`data/database_reset.dart`).

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

### 8. Sort order is scoped to the group

Members and items are ordered **strictly within their group**. `sortOrder` therefore only
has to be unique *inside* one group, and every list query orders two levels deep:

```dart
query.orderBy([
  OrderingTerm(expression: userGroups.sortOrder),  // the group's own place
  OrderingTerm(expression: users.sortOrder),       // the member's place in it
]);
```

Reordering renumbers the affected rows `0..n-1` in one transaction — under a hundred
rows makes gap-based or fractional ordering pointless complexity.

Two places in the DAOs still work table-wide rather than per group. `_nextSortOrder`
takes `MAX(sort_order)` over the whole table, which is *correct but loose*: a global max
is by definition larger than anything in the target group, so a new row still lands last.
`ItemsDao.watchItems` orders on the item's own `sortOrder` alone without joining
`item_groups` — `UsersDao.watchMembersWithBalances` is the pattern to copy. Tightening
both to be genuinely per-group is wanted, not yet done.

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
  JSON file has to go too. The database path is set explicitly through
  `appDatabaseFile()`, because drift_flutter's own default is the *documents*
  directory, which on Linux is the user's real `~/Documents`. Restore reads the same
  function, so the two cannot disagree about which file is live.
- **SQLite does not count a partial index's own WHERE columns as covered.** An index
  `ON t (a, b) WHERE type = 'x' AND voided_at IS NULL` still reads every matching row
  back from the table to re-check `type` and `voided_at`. Both
  `transactions_consumptions_*` indexes therefore end in those two columns, and
  `test/stats_dao_test.dart` asserts every `StatsDao` query plan says `COVERING INDEX` —
  a new stats query has to pass it too.
- **Drift's `.watch()` streams only see writes made through the same `AppDatabase`
  instance.** Editing the file with the `sqlite3` CLI while the app runs changes nothing
  on screen until a restart. This is a property of drift, not a bug to fix.
- **Restoring a backup swaps the `AppDatabase` instance.** `Database` closes it, renames
  the backup over the file, opens a new one and bumps a key on its child. Everything
  below it is rebuilt, and the app lands on Start. Never hold an `AppDatabase` anywhere
  but the tree: a copy kept elsewhere is a closed connection after a restore.
- **`VACUUM INTO` and `ATTACH` refuse to run inside a transaction.** Backups use the
  first and validating a backup uses the second, both through the live connection. That
  is also why checking a file needs no `sqlite3` dependency.
- **Backups are only reachable over USB because of platform config.** iOS needs
  `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` in Info.plist. Without
  them the Documents folder never appears in Finder. Android uses the app-specific
  external directory, which MTP shows without a permission. A freshly written file may
  not appear there until the media scanner catches up.

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
    database_provider.dart   # Database InheritedWidget; owns the AppDatabase, swaps it on restore
    backups.dart             # backup folder, VACUUM INTO, validate, install a file
    balance_csv.dart         # name,group,balance CSV read, write and bzip2; pure
    balance_import.dart      # export, and the import plan and merge
    database_reset.dart      # the four reset scopes and what they would delete
    errors.dart, group_usage.dart, logical_day.dart
    stat_period.dart         # rolling windows, calendar weeks, percentChange; pure
    stat_buckets.dart        # zero-fills sparse per-day/month/hour rows for charts; pure
    user_sort.dart           # automatic orders for a group's users; pure
    tables/                  # one file per table; enums live beside their table
    views/user_balances_view.dart
    daos/                    # users_dao, items_dao, transactions_dao, stats_dao (read-only SQL)
  theme/app_theme.dart       # memoized ColorScheme.fromSeed / ThemeData helpers
  utils/                     # banking (IBAN + EPC), random_emoji, time_of_day
  screens/
    settings_screen.dart     # admin settings; openSettings() is the PIN gate
    pending_top_ups_screen.dart  # admin checklist: confirm or void unchecked top-ups
    debts_screen.dart        # compact list of who owes, per group, made for a screenshot
    backup_screen.dart       # PIN-free backup from the Start page
    restore_backup_screen.dart, import_balances_screen.dart  # pick a file from the backup folder
    setup_wizard.dart        # first-run wizard
    start_screen.dart, users_screen.dart, leaderboard_screen.dart, stats_screen.dart  # the four tabs
    management_stub_screen.dart
  widgets/
    palette_picker.dart      # curated color lists, inline picker + swatch grid dialog
    emoji_picker_dialog.dart # emoji_picker_flutter's grid in a dialog, themed by hand
    user_avatar.dart         # a member's emoji in a circle from their own seed color
    pin_dialog.dart          # keypad, and the enter/set dialogs around it
    settings_text_field.dart # commit-on-blur field bound to one setting
    settings_fields.dart     # the controls the settings screen and wizard share
    stat_tile.dart, stats_card.dart, period_chips.dart, podium.dart
    ranked_bar_list.dart     # hand-rolled ranking rows: avatar, name, bar, count
    count_bar_chart.dart, trend_line_chart.dart  # the fl_chart wrappers
    empty_state.dart, epc_qr_code.dart
    qr_matrix.dart           # a QR code drawn as one un-anti-aliased path, no seams
    backup_actions.dart      # saveBackup, the folder note, the shared file list
    balances_qr_card.dart    # the balances CSV as a binary QR code, backup screen only
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
as 0. Five indexes carry it, plus a partial one for pending top-ups and two partial
covering ones for statistics, `transactions_consumptions_by_day` and `_by_user`, which hold
live consumptions only. No other composite is added: an unused index is write cost on
every ledger row.

Four DAOs cover the queries. `TransactionsDao` is the only writer of a ledger row, and
its two single-day queries take a **required** `at` rather than defaulting to now.
`StatsDao` is read-only and written as custom SQL: rankings aggregate in a CTE and join
users or items to their five rows only, and the hour of night needs `strftime`.

**Statistics.** Periods are rolling windows of logical days (30 / 365 / all); weeks are
Mon–Sun and months are calendar months, both over logical dates. A count is always
`SUM(quantity)`, voided rows never count, archived users and items do. Δ is a percentage,
and "–" when the previous window is empty. The Start podium and the user page's stats are
live `.watch()` streams. The Leaderboard and Stats tabs are not: the `IndexedStack` keeps
them built, so live queries there would re-run on every tap at the fridge. `AppShell`
passes them `active` instead, and they load `Future`s each time they come on screen or a
filter changes. The podium only shows on a body at least 760 px tall; on a phone it would
crush the recent-transactions card.

**Backups.** A backup is a `VACUUM INTO` copy of the database, written to a folder
reachable over USB. It is made from a PIN-free screen off the Start page, or from
settings. Restore, balance import and every reset save a backup of the current state
first, suffixed `_before-restore`, `_before-import` or `_before-reset`. Files are picked
from a list of that folder, not with a file picker.

The backup screen also shows the balances CSV as a **bzip2-compressed binary QR code**
(error correction L), for a phone to scan. It is rebuilt each time the screen opens and
never written to disk. When the compressed data is past QR capacity, a placeholder says
so. Past version 40, `QrCode.fromUint8List` only finds out the data is too long when
the modules are laid out, so the card builds the `QrImage` itself inside the `try`.

The balances CSV is `name,group,balance`. It is written with commas and a point decimal;
semicolon files with a comma decimal are read too. **Import merges.** A user matches on
name alone, trimmed and case-insensitive, and the group column never moves anyone. A
known user's balance is corrected with one adjustment. A new name becomes a user with a
random emoji and colour, and their group is created if needed. A duplicate name, in the
file or among the active users it names, blocks the import. **Archived users take no
part in import or export.**

Several DAO methods, `EpcQrCode`, `logicalDayFromKey` and a few ARB keys are written
ahead of the UI that will consume them — deliberate scaffolding, not dead code.

Still target design, not code: **the rest of the UI over this schema.** The Start page
is a temporary demo of `UserAvatar` and `ColorPicker` over local `setState` — replace the
body when the real Start page is built, but keep the settings `IconButton`, the only
route into settings. Members is an empty state, and the three management cards
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
