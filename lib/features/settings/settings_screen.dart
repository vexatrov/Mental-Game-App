import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/backup_service.dart';
import '../../data/models/app_settings.dart';
import '../../data/providers.dart';
import '../../ui/widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  RangeValues? _dragging;

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  String _fileName() =>
      'mental-game-backup-${DateFormat('yyyy-MM-dd').format(ref.read(clockProvider)())}.json';

  Future<Uint8List> _backupBytes() async => Uint8List.fromList(
      utf8.encode(await ref.read(backupServiceProvider).exportJson()));

  Future<void> _saveBackup() async {
    try {
      final uri = await FilePicker.saveFile(
        fileName: _fileName(),
        bytes: await _backupBytes(),
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (uri != null) _snack('Backup saved.');
    } catch (e) {
      _snack('Could not save the backup: $e');
    }
  }

  Future<void> _shareBackup() async {
    try {
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(await _backupBytes(), mimeType: 'application/json'),
        ],
        fileNameOverrides: [_fileName()],
        subject: 'Mental Game backup',
      ));
    } catch (e) {
      _snack('Could not share the backup: $e');
    }
  }

  Future<void> _restore() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null || !mounted) return;
    final ok = await confirm(
      context,
      title: 'Replace all data?',
      message: 'Everything in the app will be replaced with the contents of '
          '"${file.name}". Consider saving a backup first.',
      confirmLabel: 'Restore',
    );
    if (!ok) return;
    try {
      final counts = await ref
          .read(backupServiceProvider)
          .importJson(await file.xFile.readAsString());
      final total = counts.values.fold<int>(0, (a, b) => a + b);
      _snack('Restored $total records.');
    } on BackupFormatException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Could not read the file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final range = _dragging ??
        RangeValues(settings.cMax.toDouble(), settings.bMax.toDouble());
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const SectionHeader('A / B / C bands'),
          Text(
            'Which session scores count as C-, B- and A-game.',
            style: theme.textTheme.bodySmall,
          ),
          RangeSlider(
            values: range,
            min: 1,
            max: 99,
            divisions: 98,
            labels: RangeLabels(
                'C ≤ ${range.start.round()}', 'A > ${range.end.round()}'),
            onChanged: (v) {
              if (v.end - v.start < 1) return;
              setState(() => _dragging = v);
            },
            onChangeEnd: (v) async {
              await ref.read(settingsRepoProvider).save(settings.copyWith(
                  cMax: v.start.round(), bMax: v.end.round()));
              setState(() => _dragging = null);
            },
          ),
          Text(
            'C: 1–${range.start.round()} · '
            'B: ${range.start.round() + 1}–${range.end.round()} · '
            'A: ${range.end.round() + 1}–100',
            textAlign: TextAlign.center,
          ),
          const SectionHeader('Backup'),
          Text(
            'Your data lives only on this device. Save a backup file regularly, '
            'for example to Google Drive through Share.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('Save backup file'),
            onTap: _saveBackup,
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share backup'),
            subtitle: const Text('Send to Drive, email, or another app'),
            onTap: _shareBackup,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore from backup'),
            subtitle: const Text('Replaces all current data'),
            onTap: _restore,
          ),
          const SectionHeader('About'),
          Text(
            'A companion notebook for readers of "The Mental Game of Trading" by '
            'Jared Tendler. The app is not affiliated with the author or '
            'publisher. Read the book for the full system.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
