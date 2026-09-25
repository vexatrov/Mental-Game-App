import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../data/models/doc.dart';
import '../data/providers.dart';
import '../data/repository.dart';
import 'backup_target.dart';
import 'snapshots/snapshot_store.dart';

/// Where automatic backups go on this device. Kept in the `meta` store so
/// it's never exported or restored onto another phone.
class AutoBackupState implements Doc {
  const AutoBackupState({
    required this.uri,
    required this.name,
    this.persisted = true,
    this.lastBackupAt,
    this.lastHash,
    this.lastError,
  });

  static const docId = 'auto_backup';

  final String uri;
  final String name;

  /// False when the storage provider won't let the app keep access, so the
  /// file can only be written until the app restarts.
  final bool persisted;
  final DateTime? lastBackupAt;
  final String? lastHash;
  final String? lastError;

  @override
  String get id => docId;

  AutoBackupState copyWith({
    DateTime? lastBackupAt,
    String? lastHash,
    String? lastError,
    bool clearError = false,
  }) =>
      AutoBackupState(
        uri: uri,
        name: name,
        persisted: persisted,
        lastBackupAt: lastBackupAt ?? this.lastBackupAt,
        lastHash: lastHash ?? this.lastHash,
        lastError: clearError ? null : lastError ?? this.lastError,
      );

  @override
  Map<String, Object?> toJson() => {
        'id': id,
        'uri': uri,
        'name': name,
        'persisted': persisted,
        'lastBackupAt': lastBackupAt?.millisecondsSinceEpoch,
        'lastHash': lastHash,
        'lastError': lastError,
      };

  factory AutoBackupState.fromJson(Map<String, Object?> json) =>
      AutoBackupState(
        uri: readString(json['uri']),
        name: readString(json['name']),
        persisted: json['persisted'] != false,
        lastBackupAt:
            json['lastBackupAt'] is num ? readDate(json['lastBackupAt']) : null,
        lastHash: readNullableString(json['lastHash']),
        lastError: readNullableString(json['lastError']),
      );
}

/// Overridden in `main` with the Android implementation.
final backupTargetProvider =
    Provider<BackupTarget>((ref) => const UnsupportedBackupTarget());

/// Overridden in `main` with file storage on Android.
final snapshotStoreProvider =
    Provider<SnapshotStore>((ref) => const NoopSnapshotStore());

final autoBackupStateProvider = StreamProvider<AutoBackupState?>((ref) => Stores
    .ref(Stores.meta)
    .record(AutoBackupState.docId)
    .onSnapshot(ref.watch(databaseProvider))
    .map((s) => s == null ? null : AutoBackupState.fromJson(s.value)));

final autoBackupProvider = Provider((ref) => AutoBackupService(ref));

class AutoBackupService {
  AutoBackupService(this.ref);

  final Ref ref;

  static const fileName = 'traders-mind-backup.json';

  static const _notPersistedWarning =
      'This location only allows one-off saves. Choose another place '
      '(e.g. Google Drive or on-device storage) for automatic backup.';

  RecordRef<String, Map<String, Object?>> get _record =>
      Stores.ref(Stores.meta).record(AutoBackupState.docId);

  Database get _db => ref.read(databaseProvider);

  Future<AutoBackupState?> state() async {
    final value = await _record.get(_db);
    return value == null ? null : AutoBackupState.fromJson(value);
  }

  Future<void> _save(AutoBackupState s) => _record.put(_db, s.toJson());

  /// Lets the user pick the backup file, then writes to it straight away.
  /// Returns false if they cancelled.
  Future<bool> choose() async {
    final target = ref.read(backupTargetProvider);
    final picked = await target.pick(fileName);
    if (picked == null) return false;
    final old = await state();
    if (old != null && old.uri != picked.uri) await target.release(old.uri);
    await _save(AutoBackupState(
      uri: picked.uri,
      name: picked.name,
      persisted: picked.persisted,
    ));
    await run(force: true);
    return true;
  }

  Future<void> turnOff() async {
    final old = await state();
    if (old != null) await ref.read(backupTargetProvider).release(old.uri);
    await _record.delete(_db);
  }

  /// Writes the backup file and today's on-device snapshot if the data
  /// changed since the last run (or always, when [force]).
  Future<void> run({bool force = false}) async {
    final export = await ref.read(backupServiceProvider).export();
    final stores = jsonEncode(export['stores']);
    final hash = sha1.convert(utf8.encode(stores)).toString();
    final json = const JsonEncoder.withIndent('  ').convert(export);
    final now = ref.read(clockProvider)();

    final snapshots = ref.read(snapshotStoreProvider);
    if (snapshots.isSupported) {
      try {
        await snapshots.save(json, now);
      } catch (_) {
        // A failed snapshot must not block the main backup.
      }
    }

    final current = await state();
    if (current == null) return;
    final healthy = current.lastError == null || !current.persisted;
    if (!force && current.lastHash == hash && healthy) return;
    try {
      await ref
          .read(backupTargetProvider)
          .write(current.uri, Uint8List.fromList(utf8.encode(json)));
      await _save(current.copyWith(
        lastBackupAt: now,
        lastHash: hash,
        lastError: current.persisted ? null : _notPersistedWarning,
        clearError: current.persisted,
      ));
    } on PlatformException catch (e) {
      await _save(current.copyWith(
          lastError: 'Couldn\'t write the backup: ${e.message ?? e.code}. '
              'Choose the location again if this keeps happening.'));
    } catch (e) {
      await _save(current.copyWith(lastError: 'Couldn\'t write the backup: $e'));
    }
  }
}
