import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/journal_entry.dart';
import '../../data/providers.dart';
import '../../domain/problem_types.dart';
import '../../ui/widgets.dart';
import 'quick_note_sheet.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  ProblemType? _filter;
  bool _quickOnly = false;

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(journalProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'journalFab',
        onPressed: () => showQuickNoteSheet(context),
        icon: const Icon(Icons.bolt),
        label: const Text('Quick note'),
      ),
      body: AsyncBody(
        value: entries,
        builder: (all) {
          if (all.isEmpty) {
            return EmptyState(
              icon: Icons.edit_note,
              title: 'Map your pattern',
              message:
                  'Emotions are signals. Each time a mistake happens, write down '
                  'what came before and after it: the trigger, your thoughts, '
                  'what you did. Over time these notes show you the pattern.',
              action: FilledButton.icon(
                onPressed: () => context.push('/journal/edit'),
                icon: const Icon(Icons.add),
                label: const Text('New detailed entry'),
              ),
            );
          }
          final visible = all
              .where((e) => _filter == null || e.problem == _filter)
              .where((e) => !_quickOnly || e.isQuick)
              .toList();
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _filters(all)),
              if (visible.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('No entries match this filter.')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                  sliver: SliverList.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => JournalTile(entry: visible[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _filters(List<JournalEntry> all) {
    final quickCount = all.where((e) => e.isQuick).length;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          FilterChip(
            label: Text('To expand ($quickCount)'),
            selected: _quickOnly,
            onSelected: (v) => setState(() => _quickOnly = v),
          ),
          const SizedBox(width: 8),
          for (final p in ProblemType.values) ...[
            FilterChip(
              avatar: Icon(p.icon, size: 16, color: p.color),
              label: Text(p.label),
              selected: _filter == p,
              onSelected: (v) => setState(() => _filter = v ? p : null),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class JournalTile extends StatelessWidget {
  const JournalTile({super.key, required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filled = entry.fields.values.where((v) => v.trim().isNotEmpty).length;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/journal/edit?id=${entry.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (entry.problem != null)
                    Flexible(
                      child: ProblemBadge(entry.problem!,
                          subtype: entry.subtype),
                    ),
                  if (entry.intensity != null) ...[
                    const SizedBox(width: 6),
                    Text('${entry.intensity}/10',
                        style: theme.textTheme.labelSmall),
                  ],
                  const Spacer(),
                  Text(formatDateTime(entry.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 8),
              Text(entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge),
              const SizedBox(height: 6),
              Text(
                entry.isQuick
                    ? 'Quick note: tap to add the details'
                    : '$filled of ${PatternField.values.length} details mapped',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: entry.isQuick
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
