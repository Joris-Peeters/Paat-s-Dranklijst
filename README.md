# Paat's Dranklijst 🧊

**NL:** Een tablet app op de koelkast die bijhoudt wie wat neemt
en een duidelijk overzicht van de financiën maakt.

**EN:** A tablet app, stuck to the fridge, that tracks
who takes what, and keeps an honest overview of the finances.

Built for our youth movement, where the fridge has always run
on an honor system and a scrap of paper. This replaces the paper.

---

## What it does

- **Tap your name, tap what you took** — a few seconds, touch-only, no login
- **Logs every consumption to a ledger** — nothing relies on memory or manual tallying
- **Financial overview** — who owes what, running totals, per-person and group-wide
- **QR codes** for quick top-ups / payment references
- **Light and dark mode**, with optional automatic switching
- **Bilingual (EN/NL)** — the interface is bilingual, the docs are English
- **Self-contained** — a tablet velcro'd to a fridge, no network, no peripherals

## Why it exists

Manually tallying a paper list is tedious and time-consuming.
This puts the same "grab a drink, write it down" habit onto a tablet that
never runs out of paper and can total everything up on demand.

## Hardware

The app targets Android and iOS as primary platforms, running on cheap
second-hand Android tablets locked into kiosk mode (Android's built-in
lock task mode), or second-hand iPads. The tablet can then be mounted to
the fridge for quick access.

Linux is also targeted, as an option for people who don't have a real
tablet available. It lets the app run on Microsoft Surface devices (with
the linux-surface kernel), cheap mini PCs, or an old laptop.

## Installation

TODO

## Stack

- **[Flutter](https://flutter.dev)** (Dart) — cross-platform UI toolkit;
  builds the app for Android, iOS, and Linux from one codebase
- **Material** — Material Design widgets and theming, including the
  light/dark mode support
- **[drift](https://drift.simonbinder.eu)** — reactive, type-safe local
  database (SQLite) that stores the consumption ledger and balances
- **[qr_flutter](https://pub.dev/packages/qr_flutter)** — generates the
  QR codes used for top-ups and payment references
- **[fl_chart](https://pub.dev/packages/fl_chart)** — charts for the
  financial overview
- **[emoji_picker_flutter](https://pub.dev/packages/emoji_picker_flutter)**
  — picker widget for choosing emoji, used for per-person avatars and
  item icons

## Status

🚧 Early development — hardware and OS groundwork done, application in
progress.

## License

TBD.
