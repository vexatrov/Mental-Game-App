import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_game/data/models/daily_routine.dart';
import 'package:mental_game/data/providers.dart';

import 'helpers.dart';

void main() {
  test('today moves on after midnight once refreshed', () async {
    var now = DateTime(2026, 5, 20, 23, 59);
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(await memoryDb()),
      clockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(c.dispose);

    await c.read(routineActionsProvider).setVent('late night');
    final sub = c.listen(todayRoutineProvider, (_, _) {});
    addTearDown(sub.close);
    expect((await c.read(todayRoutineProvider.future)).vent, 'late night');

    now = DateTime(2026, 5, 21, 0, 1);
    c.read(todayKeyProvider.notifier).refresh();
    final today = await c.read(todayRoutineProvider.future);
    expect(today.id, dayKey(now));
    expect(today.vent, isEmpty, reason: 'a new day starts fresh');
  });
}
