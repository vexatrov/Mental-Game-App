import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

import 'backup_service.dart';
import 'models/app_settings.dart';
import 'models/emotion_map.dart';
import 'models/game.dart';
import 'models/journal_entry.dart';
import 'models/mental_hand_history.dart';
import 'repository.dart';

/// Opened in `main` (or a test) and injected with `overrideWithValue`.
final databaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

/// Injectable clock so tests can pin "now".
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

const _uuid = Uuid();
String newId() => _uuid.v4();

final journalRepoProvider = Provider((ref) => DocRepository<JournalEntry>(
      ref.watch(databaseProvider),
      Stores.journal,
      JournalEntry.fromJson,
      sortField: 'createdAt',
    ));

final mhhRepoProvider = Provider((ref) => DocRepository<MentalHandHistory>(
      ref.watch(databaseProvider),
      Stores.mhh,
      MentalHandHistory.fromJson,
      sortField: 'updatedAt',
    ));

final mapRepoProvider = Provider((ref) => DocRepository<EmotionMap>(
      ref.watch(databaseProvider),
      Stores.maps,
      EmotionMap.fromJson,
      sortField: 'createdAt',
    ));

final analysisRepoProvider = Provider((ref) => DocRepository<GameAnalysis>(
      ref.watch(databaseProvider),
      Stores.analyses,
      GameAnalysis.fromJson,
      sortField: 'createdAt',
    ));

final sessionRepoProvider = Provider((ref) => DocRepository<TradingSession>(
      ref.watch(databaseProvider),
      Stores.sessions,
      TradingSession.fromJson,
      sortField: 'date',
    ));

final settingsRepoProvider = Provider((ref) => DocRepository<AppSettings>(
      ref.watch(databaseProvider),
      Stores.settings,
      AppSettings.fromJson,
      sortField: 'id',
    ));

final backupServiceProvider =
    Provider((ref) => BackupService(ref.watch(databaseProvider)));

final journalProvider = StreamProvider<List<JournalEntry>>(
    (ref) => ref.watch(journalRepoProvider).watchAll());

final mhhListProvider = StreamProvider<List<MentalHandHistory>>(
    (ref) => ref.watch(mhhRepoProvider).watchAll());

/// All map documents, newest first.
final allMapsProvider = StreamProvider<List<EmotionMap>>(
    (ref) => ref.watch(mapRepoProvider).watchAll());

/// The latest version of each map series, ordered by problem then name.
final currentMapsProvider = Provider<AsyncValue<List<EmotionMap>>>((ref) {
  return ref.watch(allMapsProvider).whenData((maps) {
    final latest = <String, EmotionMap>{};
    for (final m in maps) {
      final existing = latest[m.seriesId];
      if (existing == null || m.version > existing.version) {
        latest[m.seriesId] = m;
      }
    }
    return latest.values.toList()
      ..sort((a, b) {
        final byProblem = a.problem.index.compareTo(b.problem.index);
        return byProblem != 0 ? byProblem : a.name.compareTo(b.name);
      });
  });
});

final analysesProvider = StreamProvider<List<GameAnalysis>>(
    (ref) => ref.watch(analysisRepoProvider).watchAll());

/// The analysis in force: the most recently created version.
final currentAnalysisProvider = Provider<AsyncValue<GameAnalysis?>>((ref) =>
    ref.watch(analysesProvider).whenData((l) => l.isEmpty ? null : l.first));

final sessionsProvider = StreamProvider<List<TradingSession>>(
    (ref) => ref.watch(sessionRepoProvider).watchAll());

final settingsProvider = StreamProvider<AppSettings>((ref) => ref
    .watch(settingsRepoProvider)
    .watch(AppSettings.docId)
    .map((s) => s ?? const AppSettings()));
