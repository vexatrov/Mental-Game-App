import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

import 'backup_service.dart';
import '../domain/routine.dart';
import '../services/reminders.dart';
import 'models/app_settings.dart';
import 'models/daily_routine.dart';
import 'models/drill_card.dart';
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

final routineRepoProvider = Provider((ref) => DocRepository<DailyRoutine>(
      ref.watch(databaseProvider),
      Stores.routines,
      DailyRoutine.fromJson,
      sortField: 'day',
    ));

final drillRepoProvider = Provider((ref) => DocRepository<DrillCard>(
      ref.watch(databaseProvider),
      Stores.drills,
      DrillCard.fromJson,
      sortField: 'id',
    ));

final drillCardsProvider = StreamProvider<List<DrillCard>>(
    (ref) => ref.watch(drillRepoProvider).watchAll());

/// Overridden in `main` with the platform scheduler on Android.
final reminderSchedulerProvider =
    Provider<ReminderScheduler>((ref) => const NoopReminderScheduler());

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

/// The current calendar day. Refreshed by the app at midnight and on
/// resume, so screens left open overnight move on to the new day.
class TodayKey extends Notifier<String> {
  @override
  String build() => dayKey(ref.read(clockProvider)());

  void refresh() {
    final key = dayKey(ref.read(clockProvider)());
    if (key != state) state = key;
  }
}

final todayKeyProvider = NotifierProvider<TodayKey, String>(TodayKey.new);

/// Today's routine, or an empty one if nothing was recorded yet.
final todayRoutineProvider = StreamProvider<DailyRoutine>((ref) {
  final key = ref.watch(todayKeyProvider);
  final now = ref.read(clockProvider)();
  return ref
      .watch(routineRepoProvider)
      .watch(key)
      .map((r) => r ?? DailyRoutine.empty(now));
});

/// Bumped each time a check-in is due; the app shell listens and prompts.
class CheckInPrompt extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state++;
}

final checkInPromptProvider =
    NotifierProvider<CheckInPrompt, int>(CheckInPrompt.new);

/// Writes to today's routine and drives the check-in timer.
class RoutineActions {
  RoutineActions(this.ref);

  final Ref ref;

  DateTime get _now => ref.read(clockProvider)();

  Future<DailyRoutine> _today() async {
    final now = _now;
    return await ref.read(routineRepoProvider).get(dayKey(now)) ??
        DailyRoutine.empty(now);
  }

  Future<void> _update(DailyRoutine Function(DailyRoutine) change) async =>
      ref.read(routineRepoProvider).save(change(await _today()));

  Future<void> toggle(RoutinePhase phase, String itemId) => _update((r) {
        final set = {
          ...(phase == RoutinePhase.warmup ? r.warmupChecked : r.cooldownChecked),
        };
        if (!set.remove(itemId)) set.add(itemId);
        return phase == RoutinePhase.warmup
            ? r.copyWith(warmupChecked: set)
            : r.copyWith(cooldownChecked: set);
      });

  Future<void> setCarryOver(int value) =>
      _update((r) => r.copyWith(carryOver: value));

  Future<void> setVent(String text) => _update((r) => r.copyWith(vent: text));

  Future<void> setImproved(String text) =>
      _update((r) => r.copyWith(improved: text));

  Future<void> recordCheckIn({required bool flagged}) => _update((r) =>
      r.copyWith(
        checkIns: r.checkIns + 1,
        flaggedCheckIns: r.flaggedCheckIns + (flagged ? 1 : 0),
      ));

  Future<void> recordDrill() =>
      _update((r) => r.copyWith(drills: r.drills + 1));

  Future<void> recordReset() =>
      _update((r) => r.copyWith(resets: r.resets + 1));

  /// Starts check-ins every [minutes] for [hours]. Returns false if the OS
  /// refused notification permission (the in-app prompt still runs).
  Future<bool> startTimer({required int minutes, required int hours}) async {
    final now = _now;
    final end = now.add(Duration(hours: hours));
    await _update((r) =>
        r.copyWith(timerStart: now, timerEnd: end, timerMinutes: minutes));
    final scheduler = ref.read(reminderSchedulerProvider);
    final allowed = await scheduler.requestPermission();
    if (allowed) {
      await scheduler.schedule(
          checkInTimes(now, end, Duration(minutes: minutes)));
    }
    return allowed;
  }

  Future<void> stopTimer() async {
    await _update((r) => r.copyWith(timerEnd: _now));
    await ref.read(reminderSchedulerProvider).cancelAll();
  }
}

final routineActionsProvider = Provider((ref) => RoutineActions(ref));
