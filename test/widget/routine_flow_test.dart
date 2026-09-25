import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_game/app.dart';
import 'package:mental_game/data/models/daily_routine.dart';
import 'package:mental_game/data/providers.dart';
import 'package:sembast/sembast.dart' show Database;

import '../helpers.dart';

void main() {
  final now = DateTime(2026, 5, 20, 9, 0);

  Future<(Database, ProviderContainer)> pumpApp(WidgetTester tester) async {
    final db = (await tester.runAsync(memoryDb))!;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MentalGameApp(),
    ));
    await tester.pumpAndSettle();
    return (db, container);
  }

  /// Scrolls the current screen's list until [finder] is built and visible.
  Future<void> scrollTo(WidgetTester tester, Finder finder,
      {double delta = 200}) async {
    await tester.scrollUntilVisible(finder, delta,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
  }

  Future<DailyRoutine?> today(WidgetTester tester, ProviderContainer c) =>
      tester.runAsync(() => c.read(routineRepoProvider).get(dayKey(now))).then((r) => r);

  testWidgets('ticking a warm-up step updates progress on home',
      (tester) async {
    final (_, container) = await pumpApp(tester);
    expect(find.text('0/5'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('routineCard_warmup')));
    await tester.pumpAndSettle();
    expect(find.text('Rehearse a recent trigger'), findsOneWidget);
    await tester.tap(find.byKey(const Key('routineCheck_rehearse')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 5'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1/5'), findsOneWidget);
    expect((await today(tester, container))!.warmupChecked, {'rehearse'});
  });

  testWidgets('starting the check-in timer shows it on home and stops',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('routineCard_warmup')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('startTimer')));
    await tester.tap(find.byKey(const Key('startTimer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stopTimer')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Check-ins every 30 min'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(find.text('Check-ins every 30 min'), findsNothing);
  });

  testWidgets('a due check-in prompts and records an all-clear',
      (tester) async {
    final (_, container) = await pumpApp(tester);
    container.read(checkInPromptProvider.notifier).trigger();
    await tester.pumpAndSettle();
    expect(find.text('Check-in'), findsOneWidget);

    await tester.tap(find.byKey(const Key('checkInClear')));
    await tester.pumpAndSettle();
    expect(find.text('Check-in'), findsNothing);
    expect((await today(tester, container))!.checkIns, 1);
  });

  testWidgets('custom steps can be added to the cool-down', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('routineCard_cooldown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit list'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('newRoutineItem')));
    await tester.enterText(
        find.byKey(const Key('newRoutineItem')), 'Screenshot my trades');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Screenshot my trades'), findsOneWidget);
    await scrollTo(tester, find.text('0 / 6'), delta: -200);
    expect(find.text('0 / 6'), findsOneWidget);
  });

  testWidgets('a confidence map is read with 5 as ideal', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Maps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create your first map'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confidence').last);
    await tester.pumpAndSettle();
    expect(find.text('5 = ideal · 1–4 too low · 6–10 too high'), findsOneWidget);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Confidence · v1'), findsOneWidget);
    expect(find.byKey(const Key('mapIdeal')), findsOneWidget);
    await scrollTo(tester, find.text('Ideal'));
    expect(find.text('Ideal'), findsOneWidget);
  });
}
