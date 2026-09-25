import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/db/open_db.dart';
import 'data/providers.dart';
import 'services/reminders.dart';
import 'ui/locale.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDateLocale();
  final db = await openAppDatabase();
  final reminders = platformReminderScheduler();
  final container = ProviderContainer(overrides: [
    databaseProvider.overrideWithValue(db),
    reminderSchedulerProvider.overrideWithValue(reminders),
  ]);
  await reminders.init(
    onTap: () => container.read(checkInPromptProvider.notifier).trigger(),
  );
  runApp(UncontrolledProviderScope(
    container: container,
    child: const MentalGameApp(),
  ));
}
