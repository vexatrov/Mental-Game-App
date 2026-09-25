import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_game/app.dart';
import 'package:mental_game/data/models/game.dart';
import 'package:mental_game/data/providers.dart';
import 'package:sembast/sembast.dart';

import '../helpers.dart';

void main() {
  final now = DateTime(2026, 5, 20, 17);

  Future<Database> pumpApp(WidgetTester tester) async {
    final db = await tester.runAsync(memoryDb);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db!),
        clockProvider.overrideWithValue(() => now),
      ],
      child: const MentalGameApp(),
    ));
    await tester.pumpAndSettle();
    return db;
  }

  testWidgets('quick note appears as an entry to expand', (tester) async {
    await pumpApp(tester);
    expect(find.text('How did you trade today?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('homeQuickNote')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('quickNoteField')), 'Urge to move my target');
    await tester.tap(find.text('Greed').last);
    await tester.pump();
    await tester.tap(find.byKey(const Key('quickNoteSave')));
    await tester.pumpAndSettle();

    expect(find.text('Quick notes to expand (1)'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Urge to move my target'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Urge to move my target'), findsOneWidget);

    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    expect(find.text('Urge to move my target'), findsOneWidget);
    expect(find.text('Quick note: tap to add the details'), findsOneWidget);
  });

  testWidgets('logging a session shows it on the home screen',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    expect(find.text('Log session'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);

    await tester.tap(find.byKey(const Key('saveSession')));
    await tester.pumpAndSettle();
    expect(find.text('Today: 50/100'), findsOneWidget);
    expect(find.text(GameLevel.b.label), findsOneWidget);
  });

  testWidgets('creating a map and filling a level', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Maps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create your first map'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Greed · v1'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('mapMental_1')), 'Peeking at open PnL');
    await tester.tap(find.byKey(const Key('saveMap')));
    await tester.pumpAndSettle();

    expect(find.text('1 levels · aim for at least 3'), findsOneWidget);
    expect(find.text('Pre-market review'), findsOneWidget);
  });

  testWidgets('leaving an edited entry asks to save', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New detailed entry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Chased the open');
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Save changes?'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Chased the open'), findsOneWidget);
  });
}
