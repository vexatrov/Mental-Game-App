import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import 'app.dart';
import 'data/db/open_db.dart';
import 'data/providers.dart';
import 'data/repository.dart';
import 'services/auto_backup.dart';
import 'services/backup_target.dart';
import 'services/reminders.dart';
import 'services/snapshots/snapshot_store.dart';
import 'ui/locale.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDateLocale();
  final Database db;
  try {
    db = await openAppDatabase();
  } catch (e) {
    runApp(StartupErrorApp(error: e));
    return;
  }
  final reminders = platformReminderScheduler();
  final onboarded =
      await Stores.ref(Stores.meta).record('onboarding').get(db) != null;
  final container = ProviderContainer(overrides: [
    if (!onboarded) initialLocationProvider.overrideWithValue('/welcome'),
    databaseProvider.overrideWithValue(db),
    reminderSchedulerProvider.overrideWithValue(reminders),
    backupTargetProvider.overrideWithValue(platformBackupTarget()),
    snapshotStoreProvider.overrideWithValue(platformSnapshotStore()),
  ]);
  await reminders.init(
    onTap: () => container.read(checkInPromptProvider.notifier).trigger(),
  );
  runApp(UncontrolledProviderScope(
    container: container,
    child: const MentalGameApp(),
  ));
}

/// Shown instead of the app when the local database can't be opened, so the
/// user sees what happened rather than a blank screen.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: MentalGameApp.seed),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Your notes couldn\'t be opened',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nothing has been deleted. Try closing the app completely and '
                  'opening it again. If this keeps happening, reinstalling and '
                  'restoring from your automatic backup file will bring your '
                  'notes back.',
                ),
                const SizedBox(height: 16),
                SelectableText('Details: $error',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
