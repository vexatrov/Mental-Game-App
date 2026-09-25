# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flutter app (Android first; the web target also builds, iOS is not set up) that serves as a companion notebook for *The Mental Game of Trading* (Jared Tendler). It implements the book's tools: pattern-mapping journal, Mental Hand History, 1–10 emotion maps, A- to C-game analysis, and session scoring with the Inchworm chart. Use the book's frameworks and short labels, but write all UI copy in your own words. Never paste book text into the app.

## Commands

```sh
flutter pub get
flutter analyze                          # must be clean ("No issues found!")
flutter test                             # all tests
flutter test test/data_test.dart         # one file
flutter test --plain-name 'band counts'  # one test by name
flutter build apk --debug                # needs Android SDK
flutter build apk --release --split-per-abi
flutter build web --no-web-resources-cdn # CanvasKit bundled; useful for headless UI checks
```

CI (`.github/workflows/android.yml`) runs analyze, test and a split-per-ABI release build, then uploads the APKs as the `mental-game-apk` artifact. Release builds are signed with the debug key (sideloading only).

## Architecture

- **Storage: sembast**, a JSON document DB. Each model is one store, and store names live in `Stores` (`lib/data/repository.dart`). `DocRepository<T extends Doc>` provides typed CRUD and `watchAll()` streams sorted by one field. The DB is opened per platform through a conditional export in `lib/data/db/open_db.dart` (io: `path_provider` file; web: IndexedDB).
- **Models** (`lib/data/models/`) are hand-written immutable classes with `toJson`/`fromJson` (no codegen).
  - Dates are stored as epoch milliseconds.
  - `fromJson` must tolerate missing or unknown values, because backups from older versions are imported as-is.
  - When adding a store, add it to `Stores.all` so backup includes it.
- **Versioned documents:**
  - `EmotionMap` revisions are separate documents sharing a `seriesId`. The highest `version` is current (`currentMapsProvider`), and older versions open read-only.
  - `GameAnalysis` works the same way: the newest `createdAt` is current. For 30 days (`lockPeriod`) edits change that version in place; after that, saving creates a new version.
- **State: Riverpod 3.** `lib/data/providers.dart` holds the repository providers and `StreamProvider`s.
  - `databaseProvider` must be overridden: in `main.dart` with the opened DB, in tests with an in-memory DB (`test/helpers.dart`).
  - `clockProvider` is injectable, so tests pin "now".
  - Don't use legacy `StateProvider`.
- **Routing: go_router** (`lib/app.dart`).
  - A `StatefulShellRoute.indexedStack` holds the five bottom-nav tabs.
  - Editors are top-level routes pushed over the shell, taking query params (`/journal/edit?id=`, `/mhh/edit?entry=`, `/maps/edit?id=`, …).
  - Editors keep local controllers, save explicitly, and wrap their body in `UnsavedChangesGuard`. `context.pop()` bypasses that guard, so call it only after saving.
- **Backup** (`lib/data/backup_service.dart`): the export is `{format, schemaVersion, exportedAt, stores:{name:[docs]}}`. Import validates the whole file before replacing every store in a single transaction. Bump `schemaVersion` only for incompatible changes.
- **Domain logic without Flutter widgets** lives in `lib/domain/`:
  - problem/subtype catalog and pattern fields: `problem_types.dart`
  - monthly percentiles, band counts and the KDE curve for the Inchworm charts: `inchworm_stats.dart`
- **Date locale:** `lib/ui/locale.dart` loads intl data and picks the device locale, falling back to `en_US`. Browsers can report locales such as `en-US@posix` that intl rejects.
