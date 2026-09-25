import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/app_settings.dart';
import '../../data/models/game.dart';
import '../../data/providers.dart';
import '../../ui/widgets.dart';
import 'analysis_view.dart';
import 'inchworm_view.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your game'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Sessions'),
            Tab(text: 'Inchworm'),
            Tab(text: 'A–C analysis'),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'gameFab',
          onPressed: () => context.push('/game/session'),
          icon: const Icon(Icons.add),
          label: const Text('Log session'),
        ),
        body: const TabBarView(children: [
          _SessionsView(),
          InchwormView(),
          AnalysisView(),
        ]),
      ),
    );
  }
}

class _SessionsView extends ConsumerWidget {
  const _SessionsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    return AsyncBody(
      value: sessions,
      builder: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.show_chart,
            title: 'Rate decisions, not PnL',
            message:
                'After each session, score the quality of your decisions from 1 '
                'to 100. Over time the scores show your range and whether it is '
                'moving forward.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => SessionTile(list[i], settings: settings),
        );
      },
    );
  }
}

class SessionTile extends StatelessWidget {
  const SessionTile(this.session, {super.key, required this.settings});

  final TradingSession session;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: BandBadge(settings.bandFor(session.score)),
        title: Text(formatDay(session.date)),
        subtitle: session.notes.isEmpty
            ? null
            : Text(session.notes, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${session.score}', style: theme.textTheme.titleMedium),
            if (session.carryOver > 0)
              Text('+${session.carryOver}% carried',
                  style: theme.textTheme.labelSmall),
          ],
        ),
        onTap: () => context.push('/game/session?id=${session.id}'),
      ),
    );
  }
}
