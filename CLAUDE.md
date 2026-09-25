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

CI (`.github/workflows/android.yml`) runs analyze and test, then builds split-per-ABI release APKs with `--build-number=<run number>` (the versionCode). It publishes them as a `build-N` GitHub Release, which is the link users install from.

**Signing:** `android/app/build.gradle.kts` signs release builds with the Play upload key when `android/key.properties` exists, and otherwise falls back to the debug key. When the `KEYSTORE_BASE64` and `KEYSTORE_PASSWORD` repository secrets exist, CI writes that file and also builds `app-release.aab` for Google Play. Never commit a keystore or `key.properties`; both are git-ignored.

Play Store material (listing, console answers, launch guide, screenshots) lives in `docs/play-store/`. The in-app About screen links to `docs/privacy-policy.md` on GitHub, so keep that file's path stable.

## Architecture

- **Branding:** the app is "Trader's Mind" (Android label, `com.vexatrov.tradersmind`). Tendler's tool names are kept deliberately, with credit on the About screen and in onboarding. Don't rebrand his tools, and don't imply the app is endorsed.
- **Startup** (`lib/main.dart`):
  - Opens the DB. If that fails, it shows `StartupErrorApp`.
  - Reads the onboarding flag from the `meta` store and routes to `/welcome` the first time.
  - Injects the Android-only services (reminders, backup target, snapshots) as provider overrides.
- **"Today" rolls over:** `todayKeyProvider` is refreshed at midnight (by a timer) and when the app resumes. Anything keyed by the current day should watch it rather than read the clock once.

- **Storage: sembast**, a JSON document DB. Each model is one store, and store names live in `Stores` (`lib/data/repository.dart`). `DocRepository<T extends Doc>` provides typed CRUD and `watchAll()` streams sorted by one field. The DB is opened per platform through a conditional export in `lib/data/db/open_db.dart` (io: `path_provider` file; web: IndexedDB).
- **Models** (`lib/data/models/`) are hand-written immutable classes with `toJson`/`fromJson` (no codegen).
  - Dates are stored as epoch milliseconds.
  - `fromJson` must tolerate missing or unknown values, because backups from older versions are imported as-is.
  - When adding a store, add it to `Stores.all` so backup includes it.
- **Map scales:** each `EmotionMap` has a `MapScale`, and colours, level order and level tags all come from it.
  - `worstAtTen` is the default for greed, fear and tilt, and for any map saved before scales existed.
  - `bestAtTen` is the default for discipline.
  - `idealAtFive` is the default for confidence.
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
- **Routines and check-ins:**
  - Each day's warm-up and cool-down is one `DailyRoutine` document, keyed by `dayKey(date)`.
  - The built-in steps live in `lib/domain/routine.dart`. Custom steps are stored in `AppSettings`.
  - A step counts as done when ticked by hand or when its action happened (`isItemDone`), for example a session was logged or the vent text is filled.
  - Writes go through `RoutineActions`.
- **Check-in timer:**
  - In the app, `CheckInTicker` (it wraps the shell) runs a Dart `Timer` and bumps `checkInPromptProvider`, which opens the check-in sheet.
  - In the background, `ReminderScheduler` (`lib/services/reminders.dart`) schedules OS notifications. The real implementation, `LocalNotificationScheduler`, is only injected in `main.dart` on Android.
  - Tests and the web use the default `NoopReminderScheduler`.
  - Android needs core library desugaring and the manifest receivers/permissions that `flutter_local_notifications` requires.
  - The status-bar icon is `drawable/ic_stat_notify` (white on transparent). It is named only from Dart, so `res/raw/keep.xml` stops resource shrinking from stripping it in release builds.
- **Reset flow** (`lib/features/reset/`): the real-time strategy in four steps, each step a page of a non-swipeable `PageView`.
  - Recognize: pick the problem and your current map level.
  - Disrupt: breathe, write, stand up or talk.
  - Correct: shows each `MentalHandHistory.logicLine`.
  - Execute: shows the Strategic Reminder (`AppSettings.reminderKind` and `reminderText`).
  - Finishing logs a `JournalEntry` and counts the reset on the day's routine.
- **Drill** (`lib/features/drill/`): recall practice on correction lines. Each hand history's progress is a `DrillCard` in a Leitner box (`drill_cards` store); higher boxes come back less often.
- **Automatic backup** (`lib/services/auto_backup.dart`):
  - On Android the user picks a file once through the system picker, and the app keeps permission to it (the `mental_game/backup` channel in `MainActivity.kt`).
  - The app rewrites that file when it goes to the background, and only if the data's SHA-1 changed.
  - It also keeps 7 daily on-device snapshots (`lib/services/snapshots/`).
  - The target lives in the `meta` store, which is deliberately left out of `Stores.all` so it's never exported.
- **Backup** (`lib/data/backup_service.dart`): the export is `{format, schemaVersion, exportedAt, stores:{name:[docs]}}`. Import validates the whole file before replacing every store in a single transaction. Bump `schemaVersion` only for incompatible changes.
- **Domain logic without Flutter widgets** lives in `lib/domain/`:
  - problem/subtype catalog and pattern fields: `problem_types.dart`
  - monthly percentiles, band counts and the KDE curve for the Inchworm charts: `inchworm_stats.dart`
- **Layout checks:** `test/widget/screen_sweep_test.dart` opens every route with long sample data on a small phone at 1.6× text in dark mode, and again at default size. It fails on any overflow. Add new routes to its list.
- **Date locale:** `lib/ui/locale.dart` loads intl data and picks the device locale, falling back to `en_US`. Browsers can report locales such as `en-US@posix` that intl rejects.
