import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../ui/widgets.dart';

class MapHistoryScreen extends ConsumerWidget {
  const MapHistoryScreen({super.key, required this.seriesId});

  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maps = ref.watch(allMapsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Version history')),
      body: AsyncBody(
        value: maps,
        builder: (all) {
          final versions = all.where((m) => m.seriesId == seriesId).toList()
            ..sort((a, b) => b.version.compareTo(a.version));
          if (versions.isEmpty) {
            return const Center(child: Text('No versions found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final (i, m) in versions.indexed)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('v${m.version}')),
                    title: Text(i == 0 ? '${m.name} (current)' : m.name),
                    subtitle: Text(
                        '${m.filledLevels} levels · started ${formatDay(m.createdAt)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/maps/edit?id=${m.id}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
