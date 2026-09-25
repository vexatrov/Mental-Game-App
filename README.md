# Mental Game

An Android notebook for readers of *The Mental Game of Trading* by Jared Tendler. It turns the book's tools into something you use every trading day. Not affiliated with the author or publisher.

## Features

- **Journal / pattern mapping.** Add a quick note mid-session. Afterwards, expand it with the details around the mistake: trigger, thoughts, emotions, things said out loud, behaviors, actions, and the changes in your decision-making and market perception.
- **Mental Hand History.** The 5-step worksheet for finding and fixing the flawed logic behind a problem. It supports several reasons per problem, and each reason gets its own steps 3–5. Entries can be linked back to journal notes.
- **Emotion maps.** 1–10 maps for greed, fear, tilt, confidence and discipline, and their subtypes.
  - Each map has a mental/emotional column next to a technical column, plus a description of your ideal state.
  - Scales fit the problem: 1 = first sign for greed, fear and tilt; 5 = ideal for confidence; 10 = optimal for discipline.
  - Versions are kept, and a pre-market review screen shows them before the open.
- **Warm-up & cool-down.** Daily checklists for before the open and after the close, and you can add your own steps.
  - Warm-up: review your maps and corrections, rate the emotion carried over from yesterday, start the check-in timer.
  - Cool-down: score the session, expand notes, write things out, note what improved.
- **Check-in timer.** A reminder every 15, 30 or 60 minutes during your session, as an Android notification or in-app. Each reminder asks you to scan your state and jot down anything building.
- **A- to C-game analysis.** Describe each level of your game, keeping the mental side separate from the tactical side. It stays stable for a month, and side notes collect changes for the next revision.
- **Sessions & Inchworm.** Score each session's decision quality from 1 to 100; scores are banded into A/B/C. You also record how much emotion carried over from earlier sessions. Charts show your monthly bell curve and whether the back end (C-game) and front end (A-game) are moving forward.
- **Backup.** Everything stays on the device. Export to a JSON file, or share it (e.g. to Google Drive), and restore from it.

## Install on your phone

Every push builds APKs in GitHub Actions: open **Actions → Android → latest run → Artifacts → mental-game-apk**. Most phones need `app-arm64-v8a-release.apk`. Allow installs from unknown sources when Android asks.

## Development

Requires Flutter (stable) and, for APK builds, the Android SDK.

```sh
flutter pub get
flutter run                 # on a connected device or emulator
flutter test
flutter analyze
flutter build apk --release --split-per-abi
```
