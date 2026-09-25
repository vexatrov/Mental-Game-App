import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/game.dart';
import '../../data/models/journal_entry.dart';
import '../../data/providers.dart';
import '../../domain/problem_types.dart';
import '../../ui/widgets.dart';

class JournalEditorScreen extends ConsumerStatefulWidget {
  const JournalEditorScreen({super.key, this.id, this.initialProblem});

  final String? id;
  final String? initialProblem;

  @override
  ConsumerState<JournalEditorScreen> createState() =>
      _JournalEditorScreenState();
}

class _JournalEditorScreenState extends ConsumerState<JournalEditorScreen> {
  JournalEntry? _entry;
  bool _isNew = true;
  bool _dirty = false;

  final _note = TextEditingController();
  final _fields = {
    for (final f in PatternField.values) f: TextEditingController(),
  };
  ProblemType? _problem;
  String? _subtype;
  int? _intensity;
  GameLevel? _mistakeType;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final existing = widget.id == null
        ? null
        : await ref.read(journalRepoProvider).get(widget.id!);
    final entry = existing ??
        JournalEntry(
          id: widget.id ?? newId(),
          createdAt: ref.read(clockProvider)(),
          problem: ProblemType.tryParse(widget.initialProblem),
        );
    _note.text = entry.note;
    for (final f in PatternField.values) {
      _fields[f]!.text = entry.fields[f] ?? '';
    }
    for (final c in [_note, ..._fields.values]) {
      c.addListener(_markDirty);
    }
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _isNew = existing == null;
      _problem = entry.problem;
      _subtype = entry.subtype;
      _intensity = entry.intensity;
      _mistakeType = entry.mistakeType;
    });
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _note.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  JournalEntry _build() => _entry!.copyWith(
        updatedAt: ref.read(clockProvider)(),
        note: _note.text.trim(),
        problem: _problem,
        clearProblem: _problem == null,
        subtype: _subtype,
        clearSubtype: _subtype == null,
        intensity: _intensity,
        clearIntensity: _intensity == null,
        mistakeType: _mistakeType,
        clearMistakeType: _mistakeType == null,
        fields: {for (final e in _fields.entries) e.key: e.value.text.trim()},
      );

  Future<void> _save() async {
    final entry = _build();
    await ref.read(journalRepoProvider).save(entry);
    setState(() {
      _entry = entry;
      _isNew = false;
      _dirty = false;
    });
  }

  Future<void> _saveAndClose() async {
    await _save();
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final ok = await confirm(context,
        title: 'Delete entry?', message: 'This cannot be undone.');
    if (!ok) return;
    await ref.read(journalRepoProvider).delete(_entry!.id);
    if (mounted) context.pop();
  }

  Future<void> _startMhh() async {
    await _save();
    if (mounted) context.push('/mhh/edit?entry=${_entry!.id}');
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    if (entry == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    return UnsavedChangesGuard(
      dirty: _dirty,
      onSave: _save,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'New entry' : 'Journal entry'),
          actions: [
            if (!_isNew)
              IconButton(
                tooltip: 'Delete',
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
              ),
            IconButton(
              key: const Key('saveEntry'),
              tooltip: 'Save',
              onPressed: _saveAndClose,
              icon: const Icon(Icons.check),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text(formatDateTime(entry.createdAt),
                style: theme.textTheme.labelMedium),
            const SizedBox(height: 12),
            NoteField(
              controller: _note,
              label: 'What happened?',
              hint: 'A short summary of the moment',
              autofocus: _isNew,
            ),
            ProblemPicker(
              value: _problem,
              onChanged: (p) => setState(() {
                _problem = p;
                _subtype = null;
                _dirty = true;
              }),
            ),
            if (_problem != null) ...[
              const SizedBox(height: 12),
              SubtypeDropdown(
                problem: _problem!,
                value: _subtype,
                onChanged: (s) => setState(() {
                  _subtype = s;
                  _dirty = true;
                }),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Intensity', style: theme.textTheme.labelLarge),
                Expanded(
                  child: Slider(
                    value: (_intensity ?? 0).toDouble(),
                    max: 10,
                    divisions: 10,
                    label: _intensity == null ? 'Not rated' : '$_intensity',
                    onChanged: (v) => setState(() {
                      _intensity = v == 0 ? null : v.round();
                      _dirty = true;
                    }),
                  ),
                ),
                SizedBox(
                    width: 28, child: Text(_intensity?.toString() ?? '–')),
              ],
            ),
            SectionHeader('Map the pattern',
                trailing: Text('Fill in what you can',
                    style: theme.textTheme.labelSmall)),
            for (final f in PatternField.values)
              NoteField(
                controller: _fields[f]!,
                label: f.label,
                hint: f.hint,
                minLines: 1,
              ),
            Text('What kind of mistake was it?',
                style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            RadioGroup<GameLevel>(
              groupValue: _mistakeType,
              onChanged: (v) => setState(() {
                _mistakeType = v;
                _dirty = true;
              }),
              child: Column(
                children: [
                  for (final level in GameLevel.values.reversed)
                    RadioListTile<GameLevel>(
                      key: Key('mistake_${level.name}'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      toggleable: true,
                      value: level,
                      secondary: BandBadge(level),
                      title: Text(level.mistakeLabel),
                      subtitle: Text(level.mistakeHint),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _startMhh,
              icon: const Icon(Icons.psychology),
              label: const Text('Find the root with a Mental Hand History'),
            ),
          ],
        ),
      ),
    );
  }
}
