import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/emotion_map.dart';
import '../../data/providers.dart';
import '../../ui/widgets.dart';

/// Read-only walk through the current version of every map, meant for the
/// pre-market warm-up so the early signals are fresh in mind.
class MapReviewScreen extends ConsumerStatefulWidget {
  const MapReviewScreen({super.key});

  @override
  ConsumerState<MapReviewScreen> createState() => _MapReviewScreenState();
}

class _MapReviewScreenState extends ConsumerState<MapReviewScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maps = ref.watch(currentMapsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pre-market review')),
      body: AsyncBody(
        value: maps,
        builder: (all) {
          final list = all.where((m) => m.filledLevels > 0).toList();
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.stacked_bar_chart,
              title: 'Nothing to review yet',
              message: 'Fill in some levels on a map first.',
            );
          }
          return Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: list.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _ReviewPage(list[i]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < list.length; i++)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _page
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewPage extends StatelessWidget {
  const _ReviewPage(this.map);

  final EmotionMap map;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Row(
          children: [
            Icon(map.problem.icon, color: map.problem.color, size: 28),
            const SizedBox(width: 10),
            Expanded(
                child: Text(map.name, style: theme.textTheme.headlineSmall)),
            Text('v${map.version}', style: theme.textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 4),
        Text(map.scale.label, style: theme.textTheme.bodySmall),
        if (map.ideal.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('Ideal'),
              subtitle: Text(map.ideal),
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (final e in map.filledEntries)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: map.scale.color(e.key),
                    child: Text('${e.key}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.value.mental.isNotEmpty) Text(e.value.mental),
                        if (e.value.technical.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            e.value.technical,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SectionHeader('Legend'),
        Text('Regular text: mental & emotional. Italic: technical.',
            style: theme.textTheme.bodySmall),
      ],
    );
  }
}
