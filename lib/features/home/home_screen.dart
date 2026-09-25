import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../data/models/app_settings.dart';
import '../../data/models/daily_routine.dart';
import '../../domain/routine.dart';
import '../routine/routine_screen.dart';
import '../../data/models/mental_hand_history.dart';
import '../../data/providers.dart';
import '../../ui/widgets.dart';
import '../journal/journal_screen.dart';
import '../journal/quick_note_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    final sessions = ref.watch(sessionsProvider).value ?? const [];
    final entries = ref.watch(journalProvider).value ?? const [];
    final maps = ref.watch(currentMapsProvider).value ?? const [];
    final mhh = ref.watch(mhhListProvider).value ?? const [];
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final routine =
        ref.watch(todayRoutineProvider).value ?? DailyRoutine.empty(now);

    final today = sessions.where((s) => isSameDay(s.date, now)).firstOrNull;
    final toExpand = entries.where((e) => e.isQuick).toList();
    final drafts = mhh.where((m) => m.status == MhhStatus.draft).length;
    final monthScores = sessions
        .where((s) => s.date.year == now.year && s.date.month == now.month)
        .map((s) => s.score)
        .toList();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekEntries = entries.where((e) => e.createdAt.isAfter(weekAgo)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mental Game'),
        actions: [
          IconButton(
            tooltip: 'Settings & backup',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('homeQuickNote'),
        heroTag: 'homeFab',
        onPressed: () => showQuickNoteSheet(context),
        icon: const Icon(Icons.bolt),
        label: const Text('Quick note'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(formatDay(now), style: theme.textTheme.titleMedium),
          ),
          if (maps.isEmpty)
            Card(
              color: theme.colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.stacked_bar_chart),
                title: const Text('Map your first emotion'),
                subtitle: const Text(
                    'Knowing the early signs is how you catch them in time.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/maps'),
              ),
            ),
          // Before trading.
          _RoutineCard(
            phase: RoutinePhase.warmup,
            icon: Icons.wb_sunny_outlined,
            progress: routineProgress(RoutinePhase.warmup, settings, routine,
                sessionLogged: today != null),
            highlight: true,
          ),
          if (routine.timerRunning(now)) _TimerBanner(routine: routine, now: now),
          // After trading: rate the session.
          Card(
            child: today == null
                ? ListTile(
                    leading: const Icon(Icons.show_chart),
                    title: const Text('How did you trade today?'),
                    subtitle: const Text('Rate your decisions, not your PnL.'),
                    trailing: FilledButton(
                      onPressed: () => context.push('/game/session'),
                      child: const Text('Log'),
                    ),
                  )
                : ListTile(
                    leading: BandBadge(settings.bandFor(today.score)),
                    title: Text('Today: ${today.score}/100'),
                    subtitle: Text(settings.bandFor(today.score).label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/game/session?id=${today.id}'),
                  ),
          ),
          // After trading.
          _RoutineCard(
            phase: RoutinePhase.cooldown,
            icon: Icons.nights_stay_outlined,
            progress: routineProgress(RoutinePhase.cooldown, settings, routine,
                sessionLogged: today != null),
            highlight: false,
          ),
          Row(
            children: [
              _Stat(label: 'Notes this week', value: '$weekEntries'),
              _Stat(
                label: 'Avg score this month',
                value: monthScores.isEmpty
                    ? '–'
                    : (monthScores.reduce((a, b) => a + b) / monthScores.length)
                        .toStringAsFixed(0),
              ),
              _Stat(label: 'Open hand histories', value: '$drafts'),
            ],
          ),
          if (toExpand.isNotEmpty) ...[
            SectionHeader('Quick notes to expand (${toExpand.length})',
                trailing: TextButton(
                    onPressed: () => context.go('/journal'),
                    child: const Text('All'))),
            for (final e in toExpand.take(3)) ...[
              JournalTile(entry: e),
              const SizedBox(height: 8),
            ],
          ],
          if (entries.isEmpty && sessions.isEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'How to use this app',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const _HowTo(
              icon: Icons.bolt,
              text: 'While trading, add a quick note whenever emotion shows up. '
                  'Expand it after the close.',
            ),
            const _HowTo(
              icon: Icons.stacked_bar_chart,
              text: 'Build a 1–10 map for each problem and read it before the '
                  'open.',
            ),
            const _HowTo(
              icon: Icons.psychology,
              text: 'Use a Mental Hand History to find and fix the flawed logic '
                  'behind a repeat mistake.',
            ),
            const _HowTo(
              icon: Icons.show_chart,
              text: 'Rate every session, then watch your Inchworm move forward.',
            ),
          ],
        ],
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.phase,
    required this.icon,
    required this.progress,
    required this.highlight,
  });

  final RoutinePhase phase;
  final IconData icon;
  final (int, int) progress;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (done, total) = progress;
    final complete = total > 0 && done == total;
    return Card(
      color: highlight && !complete ? theme.colorScheme.primaryContainer : null,
      child: InkWell(
        key: Key('routineCard_${phase.name}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/routine?phase=${phase.name}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Icon(complete ? Icons.check_circle : icon,
                  color: complete ? const Color(0xFF3FAE6A) : null),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(phase.label, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: total == 0 ? 0 : done / total,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text('$done/$total', style: theme.textTheme.labelLarge),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerBanner extends ConsumerWidget {
  const _TimerBanner({required this.routine, required this.now});

  final DailyRoutine routine;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = checkInTimes(routine.timerStart!, routine.timerEnd!,
            Duration(minutes: routine.timerMinutes))
        .where((t) => t.isAfter(now))
        .firstOrNull;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.timer_outlined),
        title: Text('Check-ins every ${routine.timerMinutes} min'),
        subtitle: Text(next == null
            ? 'No more check-ins today'
            : 'Next at ${DateFormat.jm().format(next)} · '
                '${routine.checkIns} done'),
        trailing: TextButton(
          onPressed: () => ref.read(routineActionsProvider).stopTimer(),
          child: const Text('Stop'),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(value, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowTo extends StatelessWidget {
  const _HowTo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(text),
      );
}
