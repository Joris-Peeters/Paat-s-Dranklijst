# Paat's Dranklijst 🧊

**NL:** Een tablet app op de koelkast die bijhoudt wie wat neemt
en een duidelijk overzicht van de financiën maakt.

**EN:** A tablet app, stuck to the fridge, that tracks
who takes what, and keeps an honest overview of the finances.

Built for our youth movement, where the fridge has always run
on an honor system and a scrap of paper. This replaces the paper.

---

## What it does

- **Tap your name, tap what you took.** No login, touch-only. Pick several
  items at once, or log the same drink for a whole round of people. A mis-tap
  can be undone straight from the confirmation message.
- **A prepaid tab per person.** Every consumption, top-up and correction is
  kept in a ledger. Nothing is ever silently rewritten: a transaction undone
  later stays visible in the history, struck through.
- **Topping up.** Preset amounts or a custom one. With the group's bank
  details filled in, the app shows a payment QR code (EPC / SEPA, euro only)
  that a banking app can scan. An admin checklist marks top-ups as received
  once the money shows up.
- **Overviews.** Each person's history and spending, a full transaction
  history with filters, a list of who owes money, a leaderboard and a
  statistics page. A "day" runs from 07:00 to 07:00, so a late night counts
  as one evening.
- **Admin settings behind a PIN.** Manage users and groups, items and
  categories, balance corrections, what regular users are allowed to do, an
  optional low-balance warning, and returning to the start page after a minute
  without touches.
- **Backups.** Make and restore database backups, export and import balances
  as CSV, or show all balances as a QR code to scan with a phone.
- **Light and dark mode**, fixed or switching on a schedule, with a
  choosable theme colour.
- **Bilingual (EN/NL)** — the interface is bilingual, the docs are English.
- **Self-contained** — no network, no accounts, no cloud. Everything stays on
  the device.

## Why it exists

Manually tallying a paper list is tedious and time-consuming.
This puts the same "grab a drink, write it down" habit onto a tablet that
never runs out of paper and can total everything up on demand.

## Hardware

The app is made for a tablet in portrait mode, mounted to the fridge for quick
access. It targets second-hand iPads and cheap Android tablets.

The inteface was not designed for phones, but it might also work.

Linux is also supported, as an option for people who don't have a real
tablet available. It lets the app run on Microsoft Surface devices (with
the linux-surface kernel), cheap mini PCs, or an old laptop.

## Installation

Download the files from the
[Releases](https://github.com/Joris-Peeters/Paat-s-Dranklijst/releases) page.

The app does not keep the screen awake or start itself when the device boots.
Set that up in the device's own settings.

### iOS / iPadOS

I used and old iPad Air 2. Really cheap and works great.

The `.ipa` is **unsigned**. Install it with
[TrollStore](https://github.com/opa334/TrollStore). Running it in Single App
Mode is recommended, so the tablet stays in the app.

### Android

Pick the APK for the tablet's processor:

- `arm64-v8a` — almost every recent tablet
- `armeabi-v7a` — older 32-bit tablets
- `x86_64` — emulators and x86 devices

Sideload it by allowing installs from unknown sources. Kiosk mode is
recommended, so the tablet stays in the app.

### Linux

Extract the `linux-x64.tar.gz` bundle and run `./paats_dranklijst` from it.
It needs GTK 3 and an emoji font installed system-wide (on Arch:
`noto-fonts-emoji`); without one, emoji show as outlines or empty boxes.

## Backups

A backup is a copy of the database, saved to a backup folder:

| Platform | Backup folder |
| --- | --- |
| Android | `Android/data/xyz.jpsystems.paats_dranklijst/files`, reachable over USB |
| iOS / iPadOS | the app's files on the iPad itself |
| Linux | `~/Documents/Paats Dranklijst` |

On iOS the backup folder is currently **not** reachable over USB, only from the
iPad itself. This is a known issue, possibly caused by installing through
TrollStore.

Restoring a backup, importing balances and resetting the database each save a
backup of the current state first.

## Building from source

Install [Flutter](https://flutter.dev), then:

```bash
flutter pub get
flutter gen-l10n
flutter run -d linux                           # run on the development machine
flutter build apk --release --split-per-abi    # Android
flutter build linux --release                  # Linux
```

iOS builds need macOS and Xcode. The release builds for every platform are made
by GitHub Actions when a version tag is pushed.

## Stack

- **[Flutter](https://flutter.dev)** (Dart) — cross-platform UI toolkit;
  builds the app for Android, iOS, and Linux from one codebase
- **Material 3** — widgets and theming, including light and dark mode
- **[drift](https://drift.simonbinder.eu)** — type-safe SQLite database that
  stores the ledger, users and items
- **[shared_preferences](https://pub.dev/packages/shared_preferences)** —
  the app's settings
- **[screen_brightness](https://pub.dev/packages/screen_brightness)** — dims
  the backlight when the app has been idle
- **[qr](https://pub.dev/packages/qr)** — encodes the payment and balances QR
  codes, drawn by the app itself
- **[archive](https://pub.dev/packages/archive)** — compresses the balances
  QR code
- **[fl_chart](https://pub.dev/packages/fl_chart)** — the statistics charts
- **[emoji_picker_flutter](https://pub.dev/packages/emoji_picker_flutter)**
  — picker for the emoji used as avatars and item icons

## Status

v1.0.0 is the first release, so expect some rough edges.
It is being put into real use at our group, so issues will get fixed when they pop up.
Problems can be reported through [GitHub issues](https://github.com/Joris-Peeters/Paat-s-Dranklijst/issues).

## License

[MIT](LICENSE)
