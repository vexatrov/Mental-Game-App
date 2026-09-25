import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/db/open_db.dart';
import 'data/providers.dart';
import 'ui/locale.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDateLocale();
  final db = await openAppDatabase();
  runApp(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: const MentalGameApp(),
  ));
}
