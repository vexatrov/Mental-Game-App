import 'package:flutter_test/flutter_test.dart';
import 'package:mental_game/data/models/app_settings.dart';
import 'package:mental_game/data/models/daily_routine.dart';
import 'package:mental_game/data/models/emotion_map.dart';
import 'package:mental_game/domain/problem_types.dart';
import 'package:mental_game/domain/routine.dart';

void main() {
  final day = DateTime(2026, 5, 20);

  group('MapScale', () {
    test('defaults follow the problem', () {
      expect(MapScale.defaultFor(ProblemType.greed), MapScale.worstAtTen);
      expect(MapScale.defaultFor(ProblemType.confidence), MapScale.idealAtFive);
      expect(MapScale.defaultFor(ProblemType.discipline), MapScale.bestAtTen);
    });

    test('severity is zero at the ideal level', () {
      expect(MapScale.worstAtTen.severity(1), 0);
      expect(MapScale.worstAtTen.severity(10), 1);
      expect(MapScale.bestAtTen.severity(10), 0);
      expect(MapScale.bestAtTen.severity(1), 1);
      expect(MapScale.idealAtFive.severity(5), 0);
      expect(MapScale.idealAtFive.severity(10), 1);
      expect(MapScale.idealAtFive.severity(1), closeTo(0.8, 1e-9));
    });

    test('ideal level gets the calm colour on every scale', () {
      final calm = MapScale.worstAtTen.color(1);
      expect(MapScale.bestAtTen.color(10), calm);
      expect(MapScale.idealAtFive.color(5), calm);
      expect(MapScale.idealAtFive.color(2), isNot(MapScale.idealAtFive.color(8)),
          reason: 'too low and too high read differently');
    });

    test('maps saved before scales existed read 1 = first sign', () {
      final m = EmotionMap.fromJson({
        'id': 'e',
        'seriesId': 's',
        'createdAt': 0,
        'problem': 'confidence',
        'levels': {
          '2': {'mental': 'a'},
          '9': {'mental': 'b'},
        },
      });
      expect(m.scale, MapScale.worstAtTen);
      expect(m.filledEntries.map((e) => e.key), [2, 9]);
    });

    test('scale and ideal survive a round trip and a new version', () {
      final m = EmotionMap(
        id: 'a',
        seriesId: 's',
        createdAt: day,
        problem: ProblemType.confidence,
        scale: MapScale.idealAtFive,
        ideal: 'Calm and clear',
        levels: {
          2: const MapLevel(mental: 'low'),
          5: const MapLevel(mental: 'ideal'),
          8: const MapLevel(mental: 'high'),
        },
      );
      final back = EmotionMap.fromJson(m.toJson());
      expect(back.scale, MapScale.idealAtFive);
      expect(back.ideal, 'Calm and clear');
      expect(back.filledEntries.map((e) => e.key), [8, 5, 2]);
      final next = m.nextVersion(id: 'b', now: day);
      expect((next.scale, next.ideal), (MapScale.idealAtFive, 'Calm and clear'));
    });
  });

  group('DailyRoutine', () {
    test('round-trips through JSON and is keyed by date', () {
      final r = DailyRoutine(
        day: day,
        warmupChecked: {'rehearse'},
        cooldownChecked: {'expand_notes'},
        carryOver: 20,
        vent: 'v',
        improved: 'i',
        checkIns: 3,
        flaggedCheckIns: 1,
        timerStart: day.add(const Duration(hours: 9)),
        timerEnd: day.add(const Duration(hours: 13)),
        timerMinutes: 15,
      );
      expect(r.id, '2026-05-20');
      expect(DailyRoutine.fromJson(r.toJson()).toJson(), r.toJson());
    });

    test('timer runs only between start and end', () {
      final r = DailyRoutine(
        day: day,
        timerStart: day.add(const Duration(hours: 9)),
        timerEnd: day.add(const Duration(hours: 10)),
      );
      expect(r.timerRunning(day.add(const Duration(hours: 8))), isTrue,
          reason: 'end is what matters once started');
      expect(r.timerRunning(day.add(const Duration(hours: 10))), isFalse);
      expect(DailyRoutine.empty(day).timerRunning(day), isFalse);
    });
  });

  group('routine items', () {
    test('items complete by hand or by doing them', () {
      final item = warmupItems.firstWhere((i) => i.id == 'carry_over');
      final rehearse = warmupItems.firstWhere((i) => i.id == 'rehearse');
      final empty = DailyRoutine.empty(day);
      expect(isItemDone(item, RoutinePhase.warmup, empty, sessionLogged: false),
          isFalse);
      expect(
          isItemDone(item, RoutinePhase.warmup, empty.copyWith(carryOver: 0),
              sessionLogged: false),
          isTrue);
      expect(
          isItemDone(rehearse, RoutinePhase.warmup,
              empty.copyWith(warmupChecked: {'rehearse'}),
              sessionLogged: false),
          isTrue);
      final log = cooldownItems.firstWhere((i) => i.id == 'log_session');
      expect(isItemDone(log, RoutinePhase.cooldown, empty, sessionLogged: true),
          isTrue);
    });

    test('custom items are stored in settings', () {
      const custom = RoutineItem(id: '${RoutineItem.customPrefix}1', label: 'News');
      final s = const AppSettings()
          .withCustomItems(RoutinePhase.warmup, [custom]);
      final back = AppSettings.fromJson(s.toJson());
      expect(back.customWarmup.single.label, 'News');
      expect(back.customWarmup.single.isCustom, isTrue);
      expect(back.routineItems(RoutinePhase.warmup).length,
          warmupItems.length + 1);
      expect(back.customCooldown, isEmpty);
    });
  });

  test('check-in times fill the window at the interval', () {
    final start = DateTime(2026, 5, 20, 9, 30);
    final times = checkInTimes(
        start, start.add(const Duration(hours: 1)), const Duration(minutes: 20));
    expect(times.map((t) => t.minute), [50, 10, 30]);
    expect(checkInTimes(start, start, const Duration(minutes: 20)), isEmpty);
    expect(checkInTimes(start, start.add(const Duration(hours: 1)), Duration.zero),
        isEmpty);
  });
}
