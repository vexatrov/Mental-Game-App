import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/emotion_map.dart';
import '../../data/providers.dart';
import '../../ui/widgets.dart';

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
  final _ideal = TextEditingController();
  MapScale _scale = MapScale.worstAtTen;

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
    _ideal.text = map.ideal;
    _ideal.addListener(_markDirty);
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
      _scale = map.scale;
      _isLatest = map.version >= latest;
    });
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final c in [..._mental.values, ..._technical.values, _ideal]) {
      c.dispose();
    }
    super.dispose();
  }

  EmotionMap _build() => _map!.copyWith(
        updatedAt: ref.read(clockProvider)(),
        scale: _scale,
        ideal: _ideal.text.trim(),
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

  Future<void> _changeScale() async {
    final picked = await showDialog<MapScale>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('How to read the levels'),
        children: [
          for (final s in MapScale.values)
            ListTile(
              leading: Icon(s == _scale
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              title: Text(s.label),
              onTap: () => Navigator.pop(context, s),
            ),
        ],
      ),
    );
    if (picked != null && picked != _scale) {
      setState(() {
        _scale = picked;
        _dirty = true;
      });
    }
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
                'scale' => _changeScale(),
                'history' =>
                  context.push('/maps/history?series=${map.seriesId}'),
                'delete' => _deleteSeries(),
                _ => null,
              },
              itemBuilder: (_) => [
                if (!readOnly) ...[
                  const PopupMenuItem(
                      value: 'version', child: Text('Start new version')),
                  const PopupMenuItem(
                      value: 'scale', child: Text('Change level scale')),
                ],
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
                '${_scale.label}. On each level, describe the mental and '
                'emotional side and what happens to your trading. Fill in at '
                'least ${EmotionMap.minLevels} levels.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('mapIdeal'),
              controller: _ideal,
              readOnly: readOnly,
              minLines: 2,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Your ideal state',
                hintText: _idealHint(map),
                prefixIcon: const Icon(Icons.wb_sunny_outlined),
              ),
            ),
            const SizedBox(height: 16),
            for (final level in _scale.displayOrder)
              _LevelRow(
                level: level,
                scale: _scale,
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

String _idealHint(EmotionMap map) => switch (map.scale) {
      MapScale.idealAtFive =>
        'Balanced: how you decide, focus and feel when confidence is right',
      MapScale.bestAtTen =>
        'At your most disciplined: routine, focus, energy, execution',
      MapScale.worstAtTen =>
        'Optional: what trading feels like when this is not a problem',
    };

/// One level of the map. Empty levels collapse to a single line so a new
/// map isn't a wall of 20 fields; the scale's anchor levels stay open.
class _LevelRow extends StatefulWidget {
  const _LevelRow({
    required this.level,
    required this.scale,
    required this.mental,
    required this.technical,
    required this.readOnly,
  });

  final int level;
  final MapScale scale;
  final TextEditingController mental;
  final TextEditingController technical;
  final bool readOnly;

  @override
  State<_LevelRow> createState() => _LevelRowState();
}

class _LevelRowState extends State<_LevelRow> {
  late bool _expanded = !_isEmpty || widget.scale.tagFor(widget.level) != null;
  bool _focusNew = false;

  bool get _isEmpty =>
      widget.mental.text.trim().isEmpty && widget.technical.text.trim().isEmpty;

  Widget _field(String label, TextEditingController c, String key,
          {bool autofocus = false}) =>
      TextField(
        key: Key('map${key}_${widget.level}'),
        controller: c,
        readOnly: widget.readOnly,
        autofocus: autofocus,
        minLines: 1,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label, isDense: true),
      );

  Widget _badge(BuildContext context, Color color, String? tag) => SizedBox(
        width: 44,
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text('${widget.level}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            if (tag != null) ...[
              const SizedBox(height: 4),
              Text(tag,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(fontSize: 9, color: color)),
            ],
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.scale.color(widget.level);
    final tag = widget.scale.tagFor(widget.level);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: color.withValues(alpha: 0.6)),
    );

    if (!_expanded) {
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: shape,
        child: InkWell(
          key: Key('mapLevel_${widget.level}'),
          borderRadius: BorderRadius.circular(14),
          onTap: widget.readOnly
              ? null
              : () => setState(() {
                    _expanded = true;
                    _focusNew = true;
                  }),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _badge(context, color, tag),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.readOnly ? '–' : 'Tap to describe level ${widget.level}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                if (!widget.readOnly)
                  Icon(Icons.add, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      );
    }

    final fields = [
      _field('Mental & emotional', widget.mental, 'Mental',
          autofocus: _focusNew),
      _field('Technical', widget.technical, 'Technical'),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: shape,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _badge(context, color, tag),
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
