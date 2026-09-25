import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/game.dart';
import '../../data/providers.dart';
import '../../ui/widgets.dart';

const _hints = {
  GameLevel.a: (
    'Emotions clear and stable, in or near the zone',
    'Mistakes here are learning mistakes: gaps in knowledge, new conditions',
  ),
  GameLevel.b: (
    'You feel the urge to make a C-game mistake but still have the control to avoid it',
    'Marginal errors that are not obvious yet',
  ),
  GameLevel.c: (
    'Emotion is high or energy is low. You know it was a mistake seconds later',
    'Obvious, basic errors: forcing trades, exiting early, chasing',
  ),
};

/// Creates or revises the A- to C-game analysis. Edits during the lock period
/// change the current version; after it, saving creates a new version.
class AnalysisEditorScreen extends ConsumerStatefulWidget {
  const AnalysisEditorScreen({super.key});

  @override
  ConsumerState<AnalysisEditorScreen> createState() =>
      _AnalysisEditorScreenState();
}

class _AnalysisEditorScreenState extends ConsumerState<AnalysisEditorScreen> {
  GameAnalysis? _current;
  bool _loaded = false;
  bool _dirty = false;

  final _mental = {for (final l in GameLevel.values) l: TextEditingController()};
  final _tactical = {
    for (final l in GameLevel.values) l: TextEditingController(),
  };
  final _alwaysSolid = TextEditingController();
  final _sideNotes = TextEditingController();

  List<TextEditingController> get _all => [
        ..._mental.values,
        ..._tactical.values,
        _alwaysSolid,
        _sideNotes,
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await ref.read(analysisRepoProvider).getAll();
    final current = all.isEmpty ? null : all.first;
    if (current != null) {
      for (final l in GameLevel.values) {
        _mental[l]!.text = current.level(l).mental;
        _tactical[l]!.text = current.level(l).tactical;
      }
      _alwaysSolid.text = current.alwaysSolid;
      _sideNotes.text = current.sideNotes;
    }
    for (final c in _all) {
      c.addListener(() {
        if (!_dirty) setState(() => _dirty = true);
      });
    }
    if (!mounted) return;
    setState(() {
      _current = current;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _createsVersion {
    final c = _current;
    return c != null && !c.isLocked(ref.read(clockProvider)());
  }

  Future<void> _save() async {
    final now = ref.read(clockProvider)();
    final levels = {
      for (final l in GameLevel.values)
        l: LevelDescription(
          mental: _mental[l]!.text.trim(),
          tactical: _tactical[l]!.text.trim(),
        ),
    };
    final current = _current;
    final GameAnalysis doc;
    if (current == null) {
      doc = GameAnalysis(id: newId(), createdAt: now);
    } else if (_createsVersion) {
      doc = current.nextVersion(id: newId(), now: now);
    } else {
      doc = current;
    }
    final saved = doc.copyWith(
      updatedAt: now,
      levels: levels,
      alwaysSolid: _alwaysSolid.text.trim(),
      sideNotes: _sideNotes.text.trim(),
    );
    await ref.read(analysisRepoProvider).save(saved);
    setState(() {
      _current = saved;
      _dirty = false;
    });
  }

  Future<void> _saveAndClose() async {
    await _save();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    return UnsavedChangesGuard(
      dirty: _dirty,
      onSave: _save,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('A- to C-game analysis'),
          actions: [
            IconButton(
              key: const Key('saveAnalysis'),
              tooltip: 'Save',
              onPressed: _saveAndClose,
              icon: const Icon(Icons.check),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            if (_createsVersion)
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text('Saving creates version ${_current!.version + 1}'),
                  subtitle:
                      const Text('The previous version is kept for comparison.'),
                ),
              ),
            for (final l in GameLevel.values) ...[
              SectionHeader(l.label, trailing: BandBadge(l)),
              NoteField(
                controller: _mental[l]!,
                label: 'Mental & emotional',
                hint: _hints[l]!.$1,
              ),
              NoteField(
                controller: _tactical[l]!,
                label: 'Tactical',
                hint: _hints[l]!.$2,
              ),
            ],
            const SectionHeader('Always solid'),
            NoteField(
              controller: _alwaysSolid,
              label: 'Strengths that show up even at your worst',
              hint: 'The floor under your C-game: skills that never break down',
            ),
            const SectionHeader('Side notes'),
            NoteField(
              controller: _sideNotes,
              label: 'Notes for the next revision',
            ),
          ],
        ),
      ),
    );
  }
}
