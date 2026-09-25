import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/mental_hand_history.dart';
import '../../data/providers.dart';
import '../../ui/widgets.dart';

class MhhScreen extends ConsumerWidget {
  const MhhScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(mhhListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mental Hand History'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/drill'),
            icon: const Icon(Icons.school_outlined),
            label: const Text('Drill'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'mhhFab',
        onPressed: () => context.push('/mhh/edit'),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: AsyncBody(
        value: list,
        builder: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.psychology,
              title: 'Find the root of the problem',
              message:
                  'Five steps: describe the problem, explain why it makes sense '
                  'that you have it, find the flaw in that logic, correct it, '
                  'and explain why the correction is right.',
              action: FilledButton.icon(
                onPressed: () => context.push('/mhh/edit'),
                icon: const Icon(Icons.add),
                label: const Text('Start one'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _MhhTile(items[i]),
          );
        },
      ),
    );
  }
}

class _MhhTile extends StatelessWidget {
  const _MhhTile(this.mhh);

  final MentalHandHistory mhh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final solid = mhh.status == MhhStatus.solid;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/mhh/edit?id=${mhh.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (mhh.problem != null) ProblemBadge(mhh.problem!),
                  const Spacer(),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(solid ? Icons.verified : Icons.edit, size: 16),
                    label: Text(mhh.status.label),
                  ),
                ],
              ),
              Text(mhh.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: mhh.stepsDone / 5,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${mhh.stepsDone}/5 steps',
                      style: theme.textTheme.labelSmall),
                ],
              ),
              if (mhh.logicLine.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.bolt, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(mhh.logicLine,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ],
              if (mhh.reasons.length > 1) ...[
                const SizedBox(height: 4),
                Text('${mhh.reasons.length} reasons',
                    style: theme.textTheme.labelSmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
