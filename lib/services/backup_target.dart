import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PickedTarget {
  const PickedTarget({
    required this.uri,
    required this.name,
    required this.persisted,
  });

  final String uri;
  final String name;

  /// Whether the app keeps access after a restart. Some storage providers
  /// don't allow that, and automatic backup can't work with them.
  final bool persisted;
}

/// A user-chosen file that the app can keep overwriting with a backup.
abstract interface class BackupTarget {
  bool get isSupported;

  /// Opens the system picker to create the backup file. Null if cancelled.
  Future<PickedTarget?> pick(String fileName);

  Future<void> write(String uri, Uint8List bytes);

  Future<void> release(String uri);
}

class UnsupportedBackupTarget implements BackupTarget {
  const UnsupportedBackupTarget();

  @override
  bool get isSupported => false;

  @override
  Future<PickedTarget?> pick(String fileName) async => null;

  @override
  Future<void> write(String uri, Uint8List bytes) async =>
      throw UnsupportedError('Automatic backup needs the Android app');

  @override
  Future<void> release(String uri) async {}
}

/// Talks to the storage access code in `MainActivity.kt`.
class AndroidBackupTarget implements BackupTarget {
  static const _channel = MethodChannel('mental_game/backup');

  @override
  bool get isSupported => true;

  @override
  Future<PickedTarget?> pick(String fileName) async {
    final result = await _channel
        .invokeMapMethod<String, Object?>('pickTarget', {'fileName': fileName});
    if (result == null) return null;
    return PickedTarget(
      uri: result['uri'] as String,
      name: result['name'] as String? ?? 'Backup file',
      persisted: result['persisted'] as bool? ?? false,
    );
  }

  @override
  Future<void> write(String uri, Uint8List bytes) =>
      _channel.invokeMethod('write', {'uri': uri, 'bytes': bytes});

  @override
  Future<void> release(String uri) =>
      _channel.invokeMethod('release', {'uri': uri});
}

BackupTarget platformBackupTarget() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? AndroidBackupTarget()
        : const UnsupportedBackupTarget();
