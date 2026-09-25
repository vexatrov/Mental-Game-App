import 'dart:convert';

import 'package:sembast/sembast.dart';

import 'repository.dart';

class BackupFormatException implements Exception {
  BackupFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Exports every store to a single JSON document and restores from one.
class BackupService {
  BackupService(this.db);

  static const format = 'mental-game-backup';
  static const schemaVersion = 1;

  final Database db;

  Future<Map<String, Object?>> export({DateTime? now}) async {
    final stores = <String, Object?>{};
    for (final name in Stores.all) {
      final records = await Stores.ref(name).find(db);
      stores[name] = [for (final r in records) r.value];
    }
    return {
      'format': format,
      'schemaVersion': schemaVersion,
      'exportedAt': (now ?? DateTime.now()).toIso8601String(),
      'stores': stores,
    };
  }

  Future<String> exportJson({DateTime? now}) async =>
      const JsonEncoder.withIndent('  ').convert(await export(now: now));

  /// Replaces all data with the contents of [source]. Validates the whole
  /// file before touching the database. Returns the number of records
  /// restored per store.
  Future<Map<String, int>> importJson(String source) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw BackupFormatException('This file is not valid JSON.');
    }
    if (decoded is! Map || decoded['format'] != format) {
      throw BackupFormatException('This is not a Mental Game backup file.');
    }
    final version = decoded['schemaVersion'];
    if (version is! int || version > schemaVersion) {
      throw BackupFormatException(
          'This backup was made by a newer version of the app.');
    }
    final stores = decoded['stores'];
    if (stores is! Map) {
      throw BackupFormatException('The backup file has no data section.');
    }

    final parsed = <String, List<Map<String, Object?>>>{};
    for (final name in Stores.all) {
      final records = stores[name] ?? const [];
      if (records is! List) {
        throw BackupFormatException('The "$name" section is malformed.');
      }
      parsed[name] = [
        for (final r in records)
          if (r is Map && r['id'] is String)
            r.cast<String, Object?>()
          else
            throw BackupFormatException('A record in "$name" has no id.'),
      ];
    }

    await db.transaction((txn) async {
      for (final entry in parsed.entries) {
        final store = Stores.ref(entry.key);
        await store.delete(txn);
        for (final record in entry.value) {
          await store.record(record['id'] as String).put(txn, record);
        }
      }
    });
    return {for (final e in parsed.entries) e.key: e.value.length};
  }
}
