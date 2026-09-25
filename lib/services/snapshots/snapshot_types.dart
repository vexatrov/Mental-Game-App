class SnapshotInfo {
  const SnapshotInfo({required this.id, required this.date, required this.bytes});

  /// File name, used to read it back.
  final String id;
  final DateTime date;
  final int bytes;
}

/// Daily copies of the backup kept inside the app's own storage.
abstract interface class SnapshotStore {
  bool get isSupported;

  /// Writes today's snapshot (replacing an earlier one from today) and
  /// keeps only the newest [keep].
  Future<void> save(String json, DateTime now, {int keep = 7});

  Future<List<SnapshotInfo>> list();

  Future<String> read(String id);
}

class NoopSnapshotStore implements SnapshotStore {
  const NoopSnapshotStore();

  @override
  bool get isSupported => false;

  @override
  Future<void> save(String json, DateTime now, {int keep = 7}) async {}

  @override
  Future<List<SnapshotInfo>> list() async => const [];

  @override
  Future<String> read(String id) async => throw UnsupportedError('No snapshots');
}
