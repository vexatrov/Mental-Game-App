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
import '../../services/auto_backup.dart';
import '../../services/snapshots/snapshot_store.dart';
import '../../ui/widgets.dart';
import '../reset/reset_screen.dart';

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

  Future<void> _restoreJson(String json, String source) async {
    try {
      final counts = await ref.read(backupServiceProvider).importJson(json);
      final total = counts.values.fold<int>(0, (a, b) => a + b);
      _snack('Restored $total records from $source.');
    } on BackupFormatException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _restoreSnapshot(SnapshotInfo snap) async {
    final ok = await confirm(
      context,
      title: 'Restore ${formatDay(snap.date)}?',
      message: 'Everything in the app will be replaced with this daily copy.',
      confirmLabel: 'Restore',
    );
    if (!ok) return;
    final json = await ref.read(snapshotStoreProvider).read(snap.id);
    await _restoreJson(json, 'the ${formatDay(snap.date)} copy');
    setState(() {});
  }

  Future<void> _chooseAutoBackup() async {
    try {
      await ref.read(autoBackupProvider).choose();
    } catch (e) {
      _snack('Couldn\'t set up automatic backup: $e');
    }
  }

  Future<void> _editReminder(AppSettings settings) async {
    final result = await showDialog<(ReminderKind, String)>(
      context: context,
      builder: (_) => StrategicReminderDialog(settings: settings),
    );
    if (result == null) return;
    await ref.read(settingsRepoProvider).save(settings.copyWith(
        reminderKind: result.$1, reminderText: result.$2.trim()));
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
          const SectionHeader('Check-ins'),
          Text(
            'How often the check-in timer nudges you to scan your state, and '
            'how long it runs once started.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              for (final m in AppSettings.checkInChoices)
                ButtonSegment(value: m, label: Text('$m min')),
            ],
            selected: {
              AppSettings.checkInChoices.contains(settings.checkInMinutes)
                  ? settings.checkInMinutes
                  : 30,
            },
            onSelectionChanged: (s) => ref
                .read(settingsRepoProvider)
                .save(settings.copyWith(checkInMinutes: s.first)),
          ),
          Row(
            children: [
              const Text('Runs for'),
              Expanded(
                child: Slider(
                  value: settings.sessionHours.toDouble(),
                  min: 1,
                  max: 12,
                  divisions: 11,
                  label: '${settings.sessionHours} h',
                  onChanged: (v) => ref
                      .read(settingsRepoProvider)
                      .save(settings.copyWith(sessionHours: v.round())),
                ),
              ),
              SizedBox(width: 40, child: Text('${settings.sessionHours} h')),
            ],
          ),
          const SectionHeader('Strategic Reminder'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.checklist),
              title: Text(settings.reminderKind.label),
              subtitle: Text(
                settings.reminderText.isEmpty
                    ? 'Shown at the end of a reset. Tap to write it.'
                    : settings.reminderText,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editReminder(settings),
            ),
          ),
          const SectionHeader('Automatic backup'),
          _AutoBackupCard(onChoose: _chooseAutoBackup),
          _SnapshotList(onRestore: _restoreSnapshot),
          const SectionHeader('Manual backup'),
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

class _AutoBackupCard extends ConsumerWidget {
  const _AutoBackupCard({required this.onChoose});

  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final supported = ref.watch(backupTargetProvider).isSupported;
    final state = ref.watch(autoBackupStateProvider).value;

    if (!supported) {
      return Text(
        'Automatic backup is available in the Android app. Here, use the '
        'manual backup below.',
        style: theme.textTheme.bodySmall,
      );
    }
    if (state == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pick a place for your backup file once. Choose Google Drive '
                'in the picker to keep it off your phone. The app then '
                'updates that file every time you leave it.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('chooseAutoBackup'),
                onPressed: onChoose,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Choose backup location'),
              ),
            ],
          ),
        ),
      );
    }
    final error = state.lastError;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                error == null ? Icons.cloud_done_outlined : Icons.cloud_off,
                color: error == null
                    ? const Color(0xFF3FAE6A)
                    : theme.colorScheme.error,
              ),
              title: Text(state.name),
              subtitle: Text(
                error ??
                    (state.lastBackupAt == null
                        ? 'Not saved yet'
                        : 'Last saved ${formatDateTime(state.lastBackupAt!)}'),
                style: error == null
                    ? null
                    : TextStyle(color: theme.colorScheme.error),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () =>
                      ref.read(autoBackupProvider).run(force: true),
                  child: const Text('Back up now'),
                ),
                TextButton(
                  onPressed: onChoose,
                  child: const Text('Change'),
                ),
                TextButton(
                  onPressed: () => ref.read(autoBackupProvider).turnOff(),
                  child: const Text('Turn off'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotList extends ConsumerWidget {
  const _SnapshotList({required this.onRestore});

  final Future<void> Function(SnapshotInfo) onRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(snapshotStoreProvider);
    if (!store.isSupported) return const SizedBox.shrink();
    // Re-listed whenever the backup state changes (i.e. after each run).
    ref.watch(autoBackupStateProvider);
    return FutureBuilder<List<SnapshotInfo>>(
      future: store.list(),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        return ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const Icon(Icons.history),
          title: const Text('Daily copies on this phone'),
          subtitle: Text(items.isEmpty
              ? 'Made automatically, last 7 days kept'
              : '${items.length} kept · newest ${formatDay(items.first.date)}'),
          children: [
            for (final s in items)
              ListTile(
                title: Text(formatDay(s.date)),
                subtitle: Text('${(s.bytes / 1024).toStringAsFixed(1)} KB'),
                trailing: TextButton(
                  onPressed: () => onRestore(s),
                  child: const Text('Restore'),
                ),
              ),
          ],
        );
      },
    );
  }
}
