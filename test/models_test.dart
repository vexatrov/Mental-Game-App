import 'package:flutter_test/flutter_test.dart';
import 'package:mental_game/data/models/app_settings.dart';
import 'package:mental_game/data/models/emotion_map.dart';
import 'package:mental_game/data/models/game.dart';
import 'package:mental_game/data/models/journal_entry.dart';
import 'package:mental_game/data/models/mental_hand_history.dart';
import 'package:mental_game/domain/problem_types.dart';

void main() {
  final t = DateTime(2026, 3, 14, 9, 30);

  group('JournalEntry', () {
    test('round-trips through JSON', () {
      final e = JournalEntry(
        id: 'j1',
        createdAt: t,
        problem: ProblemType.tilt,
        subtype: 'Revenge trading',
        note: 'Doubled size after a stop-out',
        intensity: 7,
        fields: {PatternField.trigger: 'Stopped by one tick'},
      );
      final back = JournalEntry.fromJson(e.toJson());
      expect(back.toJson(), e.toJson());
      expect(back.isQuick, isFalse);
    });

    test('is quick until a pattern field has content', () {
      final e = JournalEntry(id: 'j', createdAt: t, note: 'x');
      expect(e.isQuick, isTrue);
      expect(e.copyWith(fields: {PatternField.mistake: '  '}).isQuick, isTrue);
      expect(e.copyWith(fields: {PatternField.mistake: 'Chased'}).isQuick,
          isFalse);
    });

    test('tolerates unknown problems and fields', () {
      final e = JournalEntry.fromJson({
        'id': 'j',
        'createdAt': 0,
        'problem': 'boredom-that-does-not-exist',
        'fields': {'nope': 'x', 'thoughts': 'y'},
      });
      expect(e.problem, isNull);
      expect(e.fields, {PatternField.thoughts: 'y'});
    });
  });

  group('MentalHandHistory', () {
    test('counts a step only when every reason has it', () {
      final m = MentalHandHistory(
        id: 'm',
        createdAt: t,
        description: 'I cannot accept big losses',
        reasons: const [
          MhhReason(why: 'My strategy is profitable', flaw: 'Implies no losses'),
          MhhReason(why: 'Losses mean I failed'),
        ],
      );
      expect(m.stepsDone, 2);
      final back = MentalHandHistory.fromJson(m.toJson());
      expect(back.toJson(), m.toJson());
    });
  });

  group('EmotionMap', () {
    test('drops empty and out-of-range levels', () {
      final m = EmotionMap.fromJson({
        'id': 'e',
        'seriesId': 's',
        'createdAt': 0,
        'problem': 'greed',
        'levels': {
          '1': {'mental': 'Peeking at PnL', 'technical': ''},
          '11': {'mental': 'invalid'},
          'x': {'mental': 'invalid'},
        },
      });
      expect(m.filledLevels, 1);
      expect(m.levels.keys, [1]);
    });

    test('next version keeps content and series', () {
      final m = EmotionMap(
        id: 'a',
        seriesId: 's',
        createdAt: t,
        problem: ProblemType.fear,
        subtype: 'Fear of losing',
        levels: {3: const MapLevel(mental: 'Tight chest')},
      );
      final next = m.nextVersion(id: 'b', now: t);
      expect(next.version, 2);
      expect(next.seriesId, 's');
      expect(next.levels[3]!.mental, 'Tight chest');
      expect(next.name, 'Fear of losing');
    });
  });

  group('Game', () {
    test('analysis locks for a month', () {
      final a = GameAnalysis(id: 'a', createdAt: t);
      expect(a.isLocked(t.add(const Duration(days: 29))), isTrue);
      expect(a.isLocked(t.add(const Duration(days: 31))), isFalse);
      final back = GameAnalysis.fromJson(a
          .copyWith(levels: {GameLevel.c: const LevelDescription(mental: 'x')})
          .toJson());
      expect(back.level(GameLevel.c).mental, 'x');
      expect(back.level(GameLevel.a).isEmpty, isTrue);
    });

    test('session score is clamped when read', () {
      final s = TradingSession.fromJson(
          {'id': 's', 'date': 0, 'score': 250, 'carryOver': -5});
      expect(s.score, 100);
      expect(s.carryOver, 0);
    });

    test('settings map scores to bands', () {
      const s = AppSettings(cMax: 40, bMax: 70);
      expect(s.bandFor(1), GameLevel.c);
      expect(s.bandFor(40), GameLevel.c);
      expect(s.bandFor(41), GameLevel.b);
      expect(s.bandFor(70), GameLevel.b);
      expect(s.bandFor(71), GameLevel.a);
    });

    test('settings repair inverted thresholds', () {
      final s = AppSettings.fromJson({'cMax': 80, 'bMax': 20});
      expect(s.cMax, 80);
      expect(s.bMax, greaterThan(80));
    });
  });
}
