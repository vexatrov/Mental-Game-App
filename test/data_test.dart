import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_game/data/backup_service.dart';
import 'package:mental_game/data/models/game.dart';
import 'package:mental_game/data/models/journal_entry.dart';
import 'package:mental_game/data/repository.dart';
import 'package:mental_game/domain/problem_types.dart';

import 'helpers.dart';

void main() {
  JournalEntry entry(String id, int day) => JournalEntry(
        id: id,
        createdAt: DateTime(2026, 1, day),
        problem: ProblemType.greed,
        note: 'note $id',
      );

  group('DocRepository', () {
    test('saves, sorts newest first, and deletes', () async {
      final db = await memoryDb();
      final repo = DocRepository<JournalEntry>(
          db, Stores.journal, JournalEntry.fromJson,
          sortField: 'createdAt');
      await repo.save(entry('a', 1));
      await repo.save(entry('b', 3));
      await repo.save(entry('c', 2));
      expect((await repo.getAll()).map((e) => e.id), ['b', 'c', 'a']);
      expect((await repo.get('c'))!.note, 'note c');

      await repo.delete('b');
      expect((await repo.getAll()).map((e) => e.id), ['c', 'a']);
      expect(await repo.get('b'), isNull);
    });

    test('watchAll emits updates', () async {
      final db = await memoryDb();
      final repo = DocRepository<JournalEntry>(
          db, Stores.journal, JournalEntry.fromJson,
          sortField: 'createdAt');
      final emitted = <int>[];
      final sub = repo.watchAll().listen((l) => emitted.add(l.length));
      await pumpEventQueue();
      await repo.save(entry('a', 1));
      await pumpEventQueue();
      await repo.save(entry('b', 2));
      await pumpEventQueue();
      await sub.cancel();
      expect(emitted, [0, 1, 2]);
    });
  });

  group('BackupService', () {
    test('export then import restores everything into a fresh database',
        () async {
      final source = await memoryDb();
      await DocRepository<JournalEntry>(
              source, Stores.journal, JournalEntry.fromJson,
              sortField: 'createdAt')
          .save(entry('a', 1));
      await DocRepository<TradingSession>(
              source, Stores.sessions, TradingSession.fromJson,
              sortField: 'date')
          .save(TradingSession(id: 's', date: DateTime(2026, 1, 2), score: 64));

      final json = await BackupService(source).exportJson();

      final target = await memoryDb();
      final sessions = DocRepository<TradingSession>(
          target, Stores.sessions, TradingSession.fromJson,
          sortField: 'date');
      await sessions.save(TradingSession(
          id: 'stale', date: DateTime(2025, 1, 1), score: 10));

      final counts = await BackupService(target).importJson(json);
      expect(counts[Stores.journal], 1);
      expect(counts[Stores.sessions], 1);
      expect((await sessions.getAll()).map((s) => s.id), ['s'],
          reason: 'import replaces existing data');
      expect(await BackupService(target).exportJson(now: DateTime(2000)),
          await BackupService(source).exportJson(now: DateTime(2000)));
    });

    test('rejects files that are not backups, without touching data',
        () async {
      final db = await memoryDb();
      final repo = DocRepository<JournalEntry>(
          db, Stores.journal, JournalEntry.fromJson,
          sortField: 'createdAt');
      await repo.save(entry('keep', 1));
      final service = BackupService(db);

      for (final bad in [
        'not json',
        '[]',
        jsonEncode({'format': 'something-else'}),
        jsonEncode({'format': BackupService.format, 'schemaVersion': 99}),
        jsonEncode({
          'format': BackupService.format,
          'schemaVersion': 1,
          'stores': {
            'journal': [
              {'no': 'id'},
            ],
          },
        }),
      ]) {
        await expectLater(
            service.importJson(bad), throwsA(isA<BackupFormatException>()),
            reason: bad);
      }
      expect((await repo.getAll()).map((e) => e.id), ['keep']);
    });
  });
}
