# Trader's Mind

An Android notebook for the mental side of trading. It is built on the tools Jared Tendler created in *The Mental Game of Trading*, and turns them into something you use every trading day. The tools are his, so reading the book first is recommended.

Trader's Mind is an independent app. It is not affiliated with, endorsed by or sponsored by Jared Tendler or his publisher. It is a self-help journal, not therapy, and not financial advice.

No account, no ads, no tracking: everything stays on the phone ([privacy policy](docs/privacy-policy.md)).

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
- **Reset ("something building?").** A four-step screen for the moment you're triggered. You see your map signals, break the momentum (a guided breath, writing, a one-minute stand-up, or talking it out), read your correction lines, and check your Strategic Reminder. Each reset is logged in the journal, and "Call it a day" is always an option.
- **Drill.** Practice recalling your correction lines. Lines you remember come back less often, and ones you miss come back the next day. It's part of the warm-up.
- **Mistake tags.** Tag each journal mistake as A (learning), B (marginal) or C (obvious), and filter by tag.
- **A- to C-game analysis.** Describe each level of your game, keeping the mental side separate from the tactical side. It stays stable for a month, and side notes collect changes for the next revision.
- **Sessions & Inchworm.** Score each session's decision quality from 1 to 100; scores are banded into A/B/C. You also record how much emotion carried over from earlier sessions. Charts show your monthly bell curve and whether the back end (C-game) and front end (A-game) are moving forward.
- **Backup.**
  - Automatic (Android): pick a file location once, for example on Google Drive. The app updates it whenever you leave the app and keeps 7 daily copies on the phone.
  - Manual: export or share a JSON file and restore from it.

## Install on your phone

Open this link on your Android phone and install the file it downloads:

**https://github.com/vexatrov/Mental-Game-App/releases/latest/download/app-arm64-v8a-release.apk**

It always points to the newest build. Android will ask you to allow installs from your browser the first time. For older 32-bit phones, use `app-armeabi-v7a-release.apk` from the [latest release](https://github.com/vexatrov/Mental-Game-App/releases/latest) instead.

If Android says the app can't be updated, the new build is signed with a different key. In Settings, tap **Save backup file**, uninstall the app, install the new build, then tap **Restore from backup**.

## Google Play

Everything for the store is in [`docs/play-store/`](docs/play-store/):
- the launch steps ([LAUNCH.md](docs/play-store/LAUNCH.md))
- listing text, Play Console answers, graphics and screenshots
- monetization notes

## Development

Requires Flutter (stable) and, for APK builds, the Android SDK.

```sh
flutter pub get
flutter run                 # on a connected device or emulator
flutter test
flutter analyze
flutter build apk --release --split-per-abi
flutter build appbundle --release        # the .aab for Google Play
```

Release builds are signed with the Play upload key when `android/key.properties` exists (git-ignored). Otherwise they fall back to the debug key. CI writes that file from the `KEYSTORE_BASE64` and `KEYSTORE_PASSWORD` repository secrets.
