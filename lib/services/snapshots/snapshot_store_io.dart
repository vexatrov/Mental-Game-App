import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/models/daily_routine.dart';
import 'snapshot_types.dart';

export 'snapshot_types.dart';

SnapshotStore platformSnapshotStore() => FileSnapshotStore();

class FileSnapshotStore implements SnapshotStore {
  FileSnapshotStore({Future<Directory> Function()? baseDir})
      : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  static const _prefix = 'mental-game-';
  final Future<Directory> Function() _baseDir;

  Future<Directory> _dir() async {
    final dir = Directory(p.join((await _baseDir()).path, 'backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<File>> _files() async => (await _dir())
      .listSync()
      .whereType<File>()
      .where((f) => p.basename(f.path).startsWith(_prefix))
      .toList()
    ..sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));

  @override
  bool get isSupported => true;

  @override
  Future<void> save(String json, DateTime now, {int keep = 7}) async {
    final dir = await _dir();
    await File(p.join(dir.path, '$_prefix${dayKey(now)}.json'))
        .writeAsString(json, flush: true);
    for (final old in (await _files()).skip(keep)) {
      await old.delete();
    }
  }

  @override
  Future<List<SnapshotInfo>> list() async => [
        for (final f in await _files())
          if (DateTime.tryParse(p
                  .basenameWithoutExtension(f.path)
                  .substring(_prefix.length)) case final date?)
            SnapshotInfo(id: p.basename(f.path), date: date, bytes: f.lengthSync()),
      ];

  @override
  Future<String> read(String id) async =>
      File(p.join((await _dir()).path, p.basename(id))).readAsString();
}
