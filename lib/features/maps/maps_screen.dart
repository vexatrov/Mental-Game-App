import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/emotion_map.dart';
import '../../data/providers.dart';
import '../../domain/problem_types.dart';
import '../../ui/widgets.dart';

/// Colour for a severity level, from calm (1) to out of control (10).
Color levelColor(int level) {
  const calm = Color(0xFF3FAE6A);
  const warn = Color(0xFFF2A516);
  const hot = Color(0xFFE0524D);
  final t = (level - 1) / 9;
  return t < 0.5
      ? Color.lerp(calm, warn, t * 2)!
      : Color.lerp(warn, hot, (t - 0.5) * 2)!;
}

class MapsScreen extends ConsumerWidget {
  const MapsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final choice = await showDialog<(ProblemType, String?)>(
      context: context,
      builder: (_) => const _NewMapDialog(),
    );
    if (choice == null) return;
    final now = ref.read(clockProvider)();
    final id = newId();
    await ref.read(mapRepoProvider).save(EmotionMap(
          id: id,
          seriesId: newId(),
          createdAt: now,
          problem: choice.$1,
          subtype: choice.$2,
        ));
    if (context.mounted) context.push('/maps/edit?id=$id');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maps = ref.watch(currentMapsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Emotion maps')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'mapsFab',
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New map'),
      ),
      body: AsyncBody(
        value: maps,
        builder: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.stacked_bar_chart,
              title: 'Map each emotion from 1 to 10',
              message:
                  'Write what each level of greed, fear, tilt and so on looks '
                  'like: your thoughts and feelings on one side, what happens '
                  'to your decisions on the other. Fill in at least 3 levels. '
                  'Spotting the early levels lets you step in sooner.',
              action: FilledButton.icon(
                onPressed: () => _create(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Create your first map'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Pre-market review'),
                  subtitle: const Text('Read your maps before you trade'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/maps/review'),
                ),
              ),
              for (final p in ProblemType.values)
                if (list.any((m) => m.problem == p)) ...[
                  SectionHeader(p.label),
                  for (final m in list.where((m) => m.problem == p))
                    _MapTile(m),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _MapTile extends StatelessWidget {
  const _MapTile(this.map);

  final EmotionMap map;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filled = {for (final e in map.filledEntries) e.key};
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/maps/edit?id=${map.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(map.problem.icon, color: map.problem.color),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(map.name, style: theme.textTheme.titleMedium)),
                  Text('v${map.version}', style: theme.textTheme.labelMedium),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var level = 1; level <= EmotionMap.maxLevel; level++)
                    Expanded(
                      child: Container(
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: filled.contains(level)
                              ? levelColor(level)
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                map.filledLevels < EmotionMap.minLevels
                    ? '${map.filledLevels} levels · aim for at least ${EmotionMap.minLevels}'
                    : '${map.filledLevels} levels mapped',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewMapDialog extends StatefulWidget {
  const _NewMapDialog();

  @override
  State<_NewMapDialog> createState() => _NewMapDialogState();
}

class _NewMapDialogState extends State<_NewMapDialog> {
  ProblemType _problem = ProblemType.greed;
  String? _subtype;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New emotion map'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProblemPicker(
              value: _problem,
              allowNone: false,
              onChanged: (p) => setState(() {
                _problem = p!;
                _subtype = null;
              }),
            ),
            const SizedBox(height: 16),
            SubtypeDropdown(
              problem: _problem,
              value: _subtype,
              onChanged: (s) => setState(() => _subtype = s),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_problem, _subtype)),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
