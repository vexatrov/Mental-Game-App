import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_game/app.dart';
import 'package:mental_game/data/models/app_settings.dart';
import 'package:mental_game/data/models/emotion_map.dart';
import 'package:mental_game/data/models/game.dart';
import 'package:mental_game/data/models/journal_entry.dart';
import 'package:mental_game/data/models/mental_hand_history.dart';
import 'package:mental_game/data/providers.dart';
import 'package:mental_game/domain/problem_types.dart';

import '../helpers.dart';

/// Opens every screen with realistic data and checks nothing overflows or
/// throws: on a small phone with large text in dark mode, and at defaults.
void main() {
  final now = DateTime(2026, 5, 20, 10);
  const long = 'A deliberately long piece of text that keeps going to check '
      'that cards, tiles and badges wrap instead of overflowing on a narrow '
      'screen with large system fonts turned on.';

  Future<void> seed(ProviderContainer c) async {
    await c.read(mapRepoProvider).save(EmotionMap(
          id: 'map1',
          seriesId: 's1',
          createdAt: now,
          problem: ProblemType.fear,
          subtype: 'Fear of missing out (FOMO)',
          ideal: long,
          levels: {
            1: const MapLevel(mental: long, technical: long),
            5: const MapLevel(mental: 'Refreshing charts', technical: 'Chasing'),
            10: const MapLevel(mental: 'Panic', technical: long),
          },
        ));
    await c.read(mapRepoProvider).save(EmotionMap(
          id: 'map2',
          seriesId: 's2',
          createdAt: now,
          problem: ProblemType.confidence,
          scale: MapScale.idealAtFive,
          levels: {
            2: const MapLevel(mental: 'Doubting my setup'),
            5: const MapLevel(mental: 'Calm and clear'),
            9: const MapLevel(mental: 'Feel invincible'),
          },
        ));
    await c.read(mhhRepoProvider).save(MentalHandHistory(
          id: 'm1',
          createdAt: now,
          problem: ProblemType.fear,
          description: long,
          reasons: const [
            MhhReason(why: long, flaw: long, correction: long, whyCorrect: long),
            MhhReason(why: 'Second reason'),
          ],
          logicLine: long,
          linkedEntryIds: const ['j1', 'missing'],
        ));
    await c.read(journalRepoProvider).save(JournalEntry(
          id: 'j1',
          createdAt: now,
          problem: ProblemType.fear,
          subtype: 'Fear of missing out (FOMO)',
          note: long,
          intensity: 7,
          mistakeType: GameLevel.c,
          fields: {for (final f in PatternField.values) f: long},
        ));
    await c.read(journalRepoProvider).save(JournalEntry(
        id: 'j2', createdAt: now, problem: ProblemType.tilt, note: 'Quick one'));
    for (var i = 0; i < 40; i++) {
      await c.read(sessionRepoProvider).save(TradingSession(
            id: 's$i',
            date: now.subtract(Duration(days: i * 2)),
            score: 30 + (i * 7) % 60,
            carryOver: (i % 5) * 10,
            notes: i == 0 ? long : '',
          ));
    }
    await c.read(analysisRepoProvider).save(GameAnalysis(
          id: 'a1',
          createdAt: now,
          levels: {
            for (final l in GameLevel.values)
              l: const LevelDescription(mental: long, tactical: long),
          },
          alwaysSolid: long,
          sideNotes: long,
        ));
    await c.read(settingsRepoProvider).save(const AppSettings(
          reminderText: long,
          customWarmup: [],
        ));
  }

  const routes = [
    '/home',
    '/journal',
    '/mhh',
    '/maps',
    '/game',
    '/journal/edit?id=j1',
    '/mhh/edit?id=m1',
    '/maps/edit?id=map1',
    '/maps/edit?id=map2',
    '/maps/review',
    '/maps/history?series=s1',
    '/game/session?id=s0',
    '/game/analysis',
    '/routine?phase=warmup',
    '/routine?phase=cooldown',
    '/reset?problem=fear',
    '/drill',
    '/settings',
    '/about',
    '/welcome',
  ];

  for (final (name, size, textScale, brightness) in [
    ('small phone, large text, dark', const Size(360, 640), 1.6, Brightness.dark),
    ('regular phone, defaults', const Size(412, 915), 1.0, Brightness.light),
  ]) {
    testWidgets('every screen renders cleanly: $name', (tester) async {
      final db = (await tester.runAsync(memoryDb))!;
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final c = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ]);
      addTearDown(c.dispose);
      await tester.runAsync(() => seed(c));
      await tester.pumpWidget(
          UncontrolledProviderScope(container: c, child: const MentalGameApp()));
      await tester.pumpAndSettle();

      final problems = <String>[];
      void check(String where) {
        final e = tester.takeException();
        if (e != null) problems.add('$where: $e');
      }

      final router = c.read(routerProvider);
      for (final route in routes) {
        router.go(route);
        await tester.pumpAndSettle();
        check(route);
        // Scroll to the bottom so lazily built content is laid out too.
        final scrollables = find.byType(Scrollable).hitTestable();
        if (scrollables.evaluate().isNotEmpty) {
          await tester.fling(scrollables.first, const Offset(0, -3000), 3000);
          await tester.pumpAndSettle();
          check('$route (scrolled)');
        }
        if (route == '/game') {
          for (final tab in ['Inchworm', 'A–C analysis']) {
            await tester.tap(find.text(tab));
            await tester.pumpAndSettle();
            check('$route $tab');
          }
        }
        if (route.startsWith('/reset')) {
          for (var i = 0; i < 3; i++) {
            await tester.tap(find.byKey(const Key('resetNext')));
            await tester.pumpAndSettle();
            check('$route step ${i + 2}');
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n\n'));
    });
  }
}
