import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_game/app.dart';
import 'package:mental_game/data/models/daily_routine.dart';
import 'package:mental_game/data/models/emotion_map.dart';
import 'package:mental_game/data/models/game.dart';
import 'package:mental_game/data/models/mental_hand_history.dart';
import 'package:mental_game/data/providers.dart';
import 'package:mental_game/domain/problem_types.dart';

import '../helpers.dart';

void main() {
  final now = DateTime(2026, 5, 20, 10);

  Future<ProviderContainer> pumpApp(WidgetTester tester,
      {Future<void> Function(ProviderContainer)? seed}) async {
    final db = (await tester.runAsync(memoryDb))!;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(c.dispose);
    if (seed != null) await tester.runAsync(() => seed(c));
    await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const MentalGameApp()));
    await tester.pumpAndSettle();
    return c;
  }

  Future<void> seedTilt(ProviderContainer c) async {
    await c.read(mapRepoProvider).save(EmotionMap(
          id: 'map1',
          seriesId: 's1',
          createdAt: now,
          problem: ProblemType.tilt,
          levels: {
            2: const MapLevel(mental: 'Gripping the mouse'),
            6: const MapLevel(mental: 'Sizing up to win it back'),
          },
        ));
    await c.read(mhhRepoProvider).save(MentalHandHistory(
          id: 'mhh1',
          createdAt: now,
          problem: ProblemType.tilt,
          description: 'I chase losses',
          reasons: const [MhhReason(flaw: 'One trade decides nothing')],
          logicLine: 'Take the hit and stay in my system',
        ));
  }

  testWidgets('the reset flow walks four steps and logs the moment',
      (tester) async {
    final c = await pumpApp(tester, seed: seedTilt);
    await tester.tap(find.byKey(const Key('homeReset')));
    await tester.pumpAndSettle();

    expect(find.text('What\'s building?'), findsOneWidget);
    await tester.tap(find.text('Tilt'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resetLevel_6')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resetNext')));
    await tester.pumpAndSettle();

    expect(find.text('Break the momentum'), findsOneWidget);
    await tester.tap(find.text('Write'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('resetWrite')), 'Hot after the stop');
    await tester.tap(find.byKey(const Key('resetNext')));
    await tester.pumpAndSettle();

    expect(find.text('Take the hit and stay in my system'), findsOneWidget);
    await tester.tap(find.byKey(const Key('resetNext')));
    await tester.pumpAndSettle();

    expect(find.text('Protect your execution'), findsOneWidget);
    await tester.tap(find.byKey(const Key('resetDone')));
    await tester.pumpAndSettle();

    expect(find.text('Something building? Reset'), findsOneWidget);
    final entries = (await tester.runAsync(
        () => c.read(journalRepoProvider).getAll()))!;
    expect(entries.single.problem, ProblemType.tilt);
    expect(entries.single.note, contains('Tilt at level 6'));
    expect(entries.single.note, contains('Hot after the stop'));
    expect(entries.single.intensity, 6);
    final routine = (await tester.runAsync(
        () => c.read(routineRepoProvider).get(dayKey(now))))!;
    expect(routine.resets, 1);
  });

  testWidgets('drilling a correction line schedules it and ticks warm-up',
      (tester) async {
    final c = await pumpApp(tester, seed: seedTilt);
    await tester.tap(find.byKey(const Key('routineCard_warmup')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.text('I chase losses'), findsOneWidget);
    expect(find.text('One trade decides nothing'), findsOneWidget);
    expect(find.text('Take the hit and stay in my system'), findsNothing);
    await tester.tap(find.byKey(const Key('drillReveal')));
    await tester.pumpAndSettle();
    expect(find.text('Take the hit and stay in my system'), findsOneWidget);
    await tester.tap(find.byKey(const Key('grade_nailed')));
    await tester.pumpAndSettle();

    expect(find.text('Drill done'), findsOneWidget);
    await tester.tap(find.byKey(const Key('drillDone')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 5'), findsOneWidget);

    final card = (await tester.runAsync(
        () => c.read(drillRepoProvider).get('mhh1')))!;
    expect(card.box, 2);
  });

  testWidgets('journal mistakes can be tagged A, B or C', (tester) async {
    final c = await pumpApp(tester);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New detailed entry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Forced a trade');
    await tester.scrollUntilVisible(
        find.byKey(const Key('mistake_c')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('mistake_c')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveEntry')));
    await tester.pumpAndSettle();

    final entries = (await tester.runAsync(
        () => c.read(journalRepoProvider).getAll()))!;
    expect(entries.single.mistakeType, GameLevel.c);
    expect(find.byTooltip('Obvious mistake'), findsOneWidget);
  });
}
