import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_game/data/models/app_settings.dart';
import 'package:mental_game/data/models/drill_card.dart';
import 'package:mental_game/data/models/game.dart';
import 'package:mental_game/data/models/journal_entry.dart';
import 'package:mental_game/data/models/mental_hand_history.dart';
import 'package:mental_game/data/providers.dart';
import 'package:mental_game/data/repository.dart';
import 'package:mental_game/services/auto_backup.dart';
import 'package:mental_game/services/backup_target.dart';
import 'package:mental_game/services/snapshots/snapshot_store_io.dart';

import 'helpers.dart';

class FakeTarget implements BackupTarget {
  final writes = <String>[];
  final released = <String>[];
  PickedTarget? next =
      const PickedTarget(uri: 'content://drive/1', name: 'backup.json', persisted: true);
  bool fail = false;

  @override
  bool get isSupported => true;

  @override
  Future<PickedTarget?> pick(String fileName) async => next;

  @override
  Future<void> write(String uri, Uint8List bytes) async {
    if (fail) throw PlatformException(code: 'write_failed', message: 'offline');
    writes.add(utf8.decode(bytes));
  }

  @override
  Future<void> release(String uri) async => released.add(uri);
}

void main() {
  final day = DateTime(2026, 5, 20, 9);

  group('DrillCard', () {
    test('nailing moves up a box, missing drops to the first', () {
      var c = const DrillCard(id: 'm');
      c = c.graded(DrillGrade.nailed, day);
      expect((c.box, c.attempts, c.nailed), (2, 1, 1));
      c = c.graded(DrillGrade.close, day);
      expect(c.box, 2);
      c = c.graded(DrillGrade.missed, day);
      expect((c.box, c.attempts, c.nailed), (1, 3, 1));
      for (var i = 0; i < 10; i++) {
        c = c.graded(DrillGrade.nailed, day);
      }
      expect(c.box, DrillCard.maxBox);
    });

    test('higher boxes wait longer before coming back', () {
      expect(const DrillCard(id: 'm').isDue(day), isTrue);
      final box1 = DrillCard(id: 'm', box: 1, lastReviewed: day);
      expect(box1.isDue(day), isTrue);
      final box3 = DrillCard(id: 'm', box: 3, lastReviewed: day);
      expect(box3.isDue(day.add(const Duration(days: 2))), isFalse);
      expect(box3.isDue(day.add(const Duration(days: 3))), isTrue);
      final back = DrillCard.fromJson(box3.toJson());
      expect(back.toJson(), box3.toJson());
    });
  });

  test('new fields survive a JSON round trip', () {
    final e = JournalEntry(id: 'j', createdAt: day, mistakeType: GameLevel.c);
    expect(JournalEntry.fromJson(e.toJson()).mistakeType, GameLevel.c);
    final m = MentalHandHistory(id: 'm', createdAt: day, logicLine: 'Take the hit');
    expect(MentalHandHistory.fromJson(m.toJson()).logicLine, 'Take the hit');
    const s = AppSettings(
        reminderKind: ReminderKind.missedFactors, reminderText: 'Check volume');
    final back = AppSettings.fromJson(s.toJson());
    expect((back.reminderKind, back.reminderText),
        (ReminderKind.missedFactors, 'Check volume'));
  });

  group('AutoBackupService', () {
    late FakeTarget target;
    late ProviderContainer c;

    setUp(() async {
      target = FakeTarget();
      c = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(await memoryDb()),
        clockProvider.overrideWithValue(() => day),
        backupTargetProvider.overrideWithValue(target),
      ]);
      addTearDown(c.dispose);
    });

    test('does nothing until a location is chosen', () async {
      await c.read(autoBackupProvider).run();
      expect(target.writes, isEmpty);
    });

    test('writes on choose, then only when data changes', () async {
      final service = c.read(autoBackupProvider);
      expect(await service.choose(), isTrue);
      expect(target.writes, hasLength(1));
      expect(jsonDecode(target.writes.single)['format'], 'mental-game-backup');

      await service.run();
      expect(target.writes, hasLength(1), reason: 'nothing changed');

      await c.read(journalRepoProvider).save(JournalEntry(id: 'j', createdAt: day));
      await service.run();
      expect(target.writes, hasLength(2));
      final state = await service.state();
      expect(state!.lastBackupAt, day);
      expect(state.lastError, isNull);
    });

    test('the backup location itself is never exported', () async {
      await c.read(autoBackupProvider).choose();
      final export = await c.read(backupServiceProvider).export();
      expect((export['stores'] as Map).containsKey(Stores.meta), isFalse);
      expect(target.writes.single, isNot(contains('content://drive/1')));
    });

    test('records write failures and retries on the next run', () async {
      final service = c.read(autoBackupProvider);
      target.fail = true;
      await service.choose();
      expect((await service.state())!.lastError, contains('offline'));

      target.fail = false;
      await service.run();
      expect(target.writes, hasLength(1));
      expect((await service.state())!.lastError, isNull);
    });

    test('warns when the location only allows one-off saves', () async {
      target.next = const PickedTarget(
          uri: 'content://x/1', name: 'x.json', persisted: false);
      await c.read(autoBackupProvider).choose();
      expect((await c.read(autoBackupProvider).state())!.lastError,
          contains('one-off'));
    });

    test('changing location releases the old one; turning off clears it',
        () async {
      final service = c.read(autoBackupProvider);
      await service.choose();
      target.next = const PickedTarget(
          uri: 'content://drive/2', name: 'b.json', persisted: true);
      await service.choose();
      expect(target.released, ['content://drive/1']);
      await service.turnOff();
      expect(target.released, ['content://drive/1', 'content://drive/2']);
      expect(await service.state(), isNull);
    });
  });

  group('FileSnapshotStore', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('snap'));
    tearDown(() async => dir.delete(recursive: true));

    test('keeps one file per day, newest first, and trims old ones', () async {
      final store = FileSnapshotStore(baseDir: () async => dir);
      for (var d = 1; d <= 9; d++) {
        await store.save('{"day":$d}', DateTime(2026, 5, d), keep: 7);
      }
      await store.save('{"day":"9b"}', DateTime(2026, 5, 9, 18), keep: 7);
      final list = await store.list();
      expect(list, hasLength(7));
      expect(list.first.date, DateTime(2026, 5, 9));
      expect(list.last.date, DateTime(2026, 5, 3));
      expect(await store.read(list.first.id), '{"day":"9b"}');
    });
  });
}
