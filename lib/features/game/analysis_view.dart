import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/game.dart';
import '../../data/providers.dart';
import '../../ui/widgets.dart';

class AnalysisView extends ConsumerWidget {
  const AnalysisView({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, GameAnalysis? a) async {
    final now = ref.read(clockProvider)();
    if (a != null && a.isLocked(now)) {
      final ok = await confirm(
        context,
        title: 'Keep it stable for a month',
        message: 'This version is locked until ${formatDay(a.lockedUntil)}. '
            'A few days is too small a sample to prove your game changed. '
            'Add a side note for now, or edit anyway.',
        confirmLabel: 'Edit anyway',
      );
      if (!ok) return;
    }
    if (context.mounted) context.push('/game/analysis');
  }

  Future<void> _editNotes(
      BuildContext context, WidgetRef ref, GameAnalysis a) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _SideNotesDialog(initial: a.sideNotes),
    );
    if (result == null) return;
    await ref.read(analysisRepoProvider).save(a.copyWith(
        sideNotes: result.trim(), updatedAt: ref.read(clockProvider)()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(analysesProvider);
    return AsyncBody(
      value: all,
      builder: (versions) {
        if (versions.isEmpty) {
          return EmptyState(
            icon: Icons.stairs_outlined,
            title: 'Define your A-, B- and C-game',
            message:
                'Describe each level of your game, keeping the mental side '
                'separate from the tactical side. It becomes your measuring '
                'stick for each session. Consider it solid once three sessions '
                'in a row add nothing new.',
            action: FilledButton.icon(
              onPressed: () => context.push('/game/analysis'),
              icon: const Icon(Icons.edit),
              label: const Text('Write it'),
            ),
          );
        }
        final current = versions.first;
        final now = ref.watch(clockProvider)();
        final theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            Row(
              children: [
                Icon(current.isLocked(now) ? Icons.lock_clock : Icons.lock_open,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    current.isLocked(now)
                        ? 'v${current.version} · stable until ${formatDay(current.lockedUntil)}'
                        : 'v${current.version} · ready to revise',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Edit',
                  onPressed: () => _edit(context, ref, current),
                  icon: const Icon(Icons.edit),
                ),
              ],
            ),
            for (final level in GameLevel.values)
              _LevelCard(level: level, description: current.level(level)),
            if (current.alwaysSolid.isNotEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.foundation),
                  title: const Text('Always solid (even at my worst)'),
                  subtitle: Text(current.alwaysSolid),
                ),
              ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: const Text('Side notes'),
                subtitle: Text(current.sideNotes.isEmpty
                    ? 'Jot down changes you notice before the next revision.'
                    : current.sideNotes),
                trailing: const Icon(Icons.edit_note),
                onTap: () => _editNotes(context, ref, current),
              ),
            ),
            if (versions.length > 1)
              ExpansionTile(
                title: Text('Earlier versions (${versions.length - 1})',
                    style: theme.textTheme.titleSmall),
                children: [
                  for (final old in versions.skip(1))
                    ListTile(
                      title: Text('v${old.version} · ${formatDay(old.createdAt)}'),
                      subtitle: Text(
                        GameLevel.values
                            .map((l) =>
                                '${l.letter}: ${old.level(l).mental.isEmpty ? '–' : old.level(l).mental}')
                            .join('\n'),
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _SideNotesDialog extends StatefulWidget {
  const _SideNotesDialog({required this.initial});

  final String initial;

  @override
  State<_SideNotesDialog> createState() => _SideNotesDialogState();
}

class _SideNotesDialogState extends State<_SideNotesDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Side notes'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 4,
        maxLines: 10,
        decoration: const InputDecoration(
            hintText: 'What you notice now, to use in the next revision'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: const Text('Save')),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.level, required this.description});

  final GameLevel level;
  final LevelDescription description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget column(String title, String text) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: 4),
              Text(text.isEmpty ? '–' : text),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BandBadge(level),
            const SizedBox(width: 12),
            column('Mental', description.mental),
            const SizedBox(width: 12),
            column('Tactical', description.tactical),
          ],
        ),
      ),
    );
  }
}
