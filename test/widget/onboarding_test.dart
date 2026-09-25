import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_game/app.dart';
import 'package:mental_game/data/providers.dart';
import 'package:mental_game/data/repository.dart';
import 'package:sembast/sembast.dart' hide Finder;

import '../helpers.dart';

void main() {
  testWidgets('first run shows the intro once, then lands on Today',
      (tester) async {
    final db = (await tester.runAsync(memoryDb))!;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => DateTime(2026, 5, 20, 9)),
        initialLocationProvider.overrideWithValue('/welcome'),
      ],
      child: const MentalGameApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Trader\'s Mind'), findsOneWidget);
    expect(find.textContaining('Jared Tendler'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('onboardingNext')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Your notes stay yours'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Trader\'s Mind'), findsOneWidget);
    expect(find.text('Something building? Reset'), findsOneWidget);
    final flag = await tester.runAsync(
        () => Stores.ref(Stores.meta).record('onboarding').get(db));
    expect(flag, isNotNull);
  });
}
