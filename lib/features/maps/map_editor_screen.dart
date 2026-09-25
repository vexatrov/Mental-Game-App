import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/emotion_map.dart';
import '../../data/providers.dart';
import '../../ui/widgets.dart';
import 'maps_screen.dart';

class MapEditorScreen extends ConsumerStatefulWidget {
  const MapEditorScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<MapEditorScreen> createState() => _MapEditorScreenState();
}

class _MapEditorScreenState extends ConsumerState<MapEditorScreen> {
  EmotionMap? _map;
  bool _isLatest = true;
  bool _missing = false;
  bool _dirty = false;

  final _mental = <int, TextEditingController>{};
  final _technical = <int, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(mapRepoProvider);
    final map = await repo.get(widget.id);
    if (map == null) {
      if (mounted) setState(() => _missing = true);
      return;
    }
    final series =
        (await repo.getAll()).where((m) => m.seriesId == map.seriesId);
    final latest = series.fold<int>(0, (v, m) => m.version > v ? m.version : v);
    for (var level = 1; level <= EmotionMap.maxLevel; level++) {
      final l = map.levels[level] ?? const MapLevel();
      _mental[level] = TextEditingController(text: l.mental)
        ..addListener(_markDirty);
      _technical[level] = TextEditingController(text: l.technical)
        ..addListener(_markDirty);
    }
    if (!mounted) return;
    setState(() {
      _map = map;
      _isLatest = map.version >= latest;
    });
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final c in [..._mental.values, ..._technical.values]) {
      c.dispose();
    }
    super.dispose();
  }

  EmotionMap _build() => _map!.copyWith(
        updatedAt: ref.read(clockProvider)(),
        levels: {
          for (var level = 1; level <= EmotionMap.maxLevel; level++)
            level: MapLevel(
              mental: _mental[level]!.text.trim(),
              technical: _technical[level]!.text.trim(),
            ),
        },
      );

  Future<void> _save() async {
    final map = _build();
    await ref.read(mapRepoProvider).save(map);
    setState(() {
      _map = map;
      _dirty = false;
    });
  }

  Future<void> _saveAndClose() async {
    await _save();
    if (mounted) context.pop();
  }

  Future<void> _newVersion() async {
    final ok = await confirm(
      context,
      title: 'Start version ${_map!.version + 1}?',
      message: 'Only revise a map once you have solid evidence the pattern '
          'has changed. The current version is kept so you can compare them.',
      confirmLabel: 'Create version',
    );
    if (!ok) return;
    await _save();
    final next =
        _map!.nextVersion(id: newId(), now: ref.read(clockProvider)());
    await ref.read(mapRepoProvider).save(next);
    if (mounted) context.pushReplacement('/maps/edit?id=${next.id}');
  }

  Future<void> _deleteSeries() async {
    final ok = await confirm(context,
        title: 'Delete this map?',
        message: 'All versions of "${_map!.name}" will be deleted.');
    if (!ok) return;
    final repo = ref.read(mapRepoProvider);
    for (final m in await repo.getAll()) {
      if (m.seriesId == _map!.seriesId) await repo.delete(m.id);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_missing) {
      return Scaffold(
          appBar: AppBar(), body: const Center(child: Text('Map not found.')));
    }
    final map = _map;
    if (map == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    final readOnly = !_isLatest;
    return UnsavedChangesGuard(
      dirty: _dirty,
      onSave: _save,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${map.name} · v${map.version}'),
          actions: [
            if (!readOnly)
              IconButton(
                key: const Key('saveMap'),
                tooltip: 'Save',
                onPressed: _saveAndClose,
                icon: const Icon(Icons.check),
              ),
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'version' => _newVersion(),
                'history' =>
                  context.push('/maps/history?series=${map.seriesId}'),
                'delete' => _deleteSeries(),
                _ => null,
              },
              itemBuilder: (_) => [
                if (!readOnly)
                  const PopupMenuItem(
                      value: 'version', child: Text('Start new version')),
                const PopupMenuItem(
                    value: 'history', child: Text('Version history')),
                const PopupMenuItem(
                    value: 'delete', child: Text('Delete map')),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            if (readOnly)
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: const ListTile(
                  leading: Icon(Icons.history),
                  title: Text('Older version (read-only)'),
                  subtitle: Text('Open the latest version to make changes.'),
                ),
              )
            else
              Text(
                'Level 1 is the first small sign. Level 10 is completely out of '
                'control. On each level, describe the mental and emotional side '
                'and what happens to your trading. Fill in at least '
                '${EmotionMap.minLevels} levels.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            const SizedBox(height: 12),
            for (var level = 1; level <= EmotionMap.maxLevel; level++)
              _LevelRow(
                level: level,
                mental: _mental[level]!,
                technical: _technical[level]!,
                readOnly: readOnly,
              ),
          ],
        ),
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.level,
    required this.mental,
    required this.technical,
    required this.readOnly,
  });

  final int level;
  final TextEditingController mental;
  final TextEditingController technical;
  final bool readOnly;

  Widget _field(String label, TextEditingController c, String key) => TextField(
        key: Key('map${key}_$level'),
        controller: c,
        readOnly: readOnly,
        minLines: 1,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label, isDense: true),
      );

  @override
  Widget build(BuildContext context) {
    final color = levelColor(level);
    final fields = [
      _field('Mental & emotional', mental, 'Mental'),
      _field('Technical', technical, 'Technical'),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text('$level',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => c.maxWidth > 520
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: fields[0]),
                          const SizedBox(width: 8),
                          Expanded(child: fields[1]),
                        ],
                      )
                    : Column(
                        children: [fields[0], const SizedBox(height: 8), fields[1]],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
