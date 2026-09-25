import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/drill_card.dart';
import '../../data/models/mental_hand_history.dart';
import '../../data/providers.dart';
import '../../ui/widgets.dart';

/// Recall practice for correction lines: see the problem, say the line from
/// memory, then check yourself.
class DrillScreen extends ConsumerStatefulWidget {
  const DrillScreen({super.key});

  @override
  ConsumerState<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends ConsumerState<DrillScreen> {
  List<MentalHandHistory>? _queue;
  int _index = 0;
  bool _revealed = false;
  bool _practiceAll = false;
  final _attempt = TextEditingController();
  final _grades = <DrillGrade>[];

  @override
  void dispose() {
    _attempt.dispose();
    super.dispose();
  }

  List<MentalHandHistory> _buildQueue(
    List<MentalHandHistory> mhhs,
    List<DrillCard> cards,
    DateTime now, {
    required bool all,
  }) {
    final byId = {for (final c in cards) c.id: c};
    DrillCard card(MentalHandHistory m) => byId[m.id] ?? DrillCard(id: m.id);
    final withLines = mhhs.where((m) => m.logicLine.trim().isNotEmpty);
    final queue = withLines.where((m) => all || card(m).isDue(now)).toList()
      ..sort((a, b) {
        final byBox = card(a).box.compareTo(card(b).box);
        if (byBox != 0) return byBox;
        final la = card(a).lastReviewed?.millisecondsSinceEpoch ?? 0;
        final lb = card(b).lastReviewed?.millisecondsSinceEpoch ?? 0;
        return la.compareTo(lb);
      });
    return queue;
  }

  Future<void> _grade(MentalHandHistory m, DrillGrade grade) async {
    HapticFeedback.selectionClick();
    final repo = ref.read(drillRepoProvider);
    final now = ref.read(clockProvider)();
    final current = await repo.get(m.id) ?? DrillCard(id: m.id);
    await repo.save(current.graded(grade, now));
    _grades.add(grade);
    final last = _index >= _queue!.length - 1;
    if (last) await ref.read(routineActionsProvider).recordDrill();
    if (!mounted) return;
    setState(() {
      _index++;
      _revealed = false;
      _attempt.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mhhs = ref.watch(mhhListProvider);
    final cards = ref.watch(drillCardsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Drill')),
      body: switch ((mhhs, cards)) {
        (AsyncData(value: final m), AsyncData(value: final c)) =>
          _body(m, c),
        (AsyncError(:final error), _) || (_, AsyncError(:final error)) =>
          Center(child: Text('Something went wrong: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _body(List<MentalHandHistory> mhhs, List<DrillCard> cards) {
    final now = ref.read(clockProvider)();
    final queue = _queue ??=
        _buildQueue(mhhs, cards, now, all: _practiceAll);
    final hasLines = mhhs.any((m) => m.logicLine.trim().isNotEmpty);

    if (!hasLines) {
      return EmptyState(
        icon: Icons.school_outlined,
        title: 'No correction lines yet',
        message: 'At the end of each Mental Hand History, boil your '
            'correction down to one line. Those lines are what you drill here.',
        action: FilledButton.icon(
          onPressed: () => context.go('/mhh'),
          icon: const Icon(Icons.psychology),
          label: const Text('Go to hand histories'),
        ),
      );
    }
    if (queue.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline,
        title: 'All caught up',
        message: 'Nothing is due today. Lines you remember come back less '
            'often; ones you miss come back tomorrow.',
        action: OutlinedButton(
          key: const Key('practiceAll'),
          onPressed: () => setState(() {
            _practiceAll = true;
            _queue = null;
          }),
          child: const Text('Practice them all anyway'),
        ),
      );
    }
    if (_index >= queue.length) return _summary();
    return _card(queue[_index], queue.length);
  }

  Widget _summary() {
    final nailed = _grades.where((g) => g == DrillGrade.nailed).length;
    return EmptyState(
      icon: Icons.emoji_events_outlined,
      title: 'Drill done',
      message: '$nailed of ${_grades.length} nailed. Repetition is what makes '
          'these lines strong enough to use under pressure.',
      action: FilledButton(
        key: const Key('drillDone'),
        onPressed: () => context.pop(),
        child: const Text('Done'),
      ),
    );
  }

  Widget _card(MentalHandHistory m, int total) {
    final theme = Theme.of(context);
    final flaw = m.reasons
        .map((r) => r.flaw.trim())
        .firstWhere((f) => f.isNotEmpty, orElse: () => '');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(
          children: [
            if (m.problem != null) ProblemBadge(m.problem!),
            const Spacer(),
            Text('${_index + 1} of $total', style: theme.textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (_index + 1) / total,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('The problem', style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(m.title, style: theme.textTheme.titleLarge),
                if (flaw.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Where the logic breaks',
                      style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(flaw),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('What\'s your correction line?',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          key: const Key('drillAttempt'),
          controller: _attempt,
          readOnly: _revealed,
          minLines: 2,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              hintText: 'Say it or type it from memory (optional)'),
        ),
        const SizedBox(height: 16),
        if (!_revealed)
          FilledButton.icon(
            key: const Key('drillReveal'),
            onPressed: () => setState(() => _revealed = true),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Reveal'),
          )
        else ...[
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(m.logicLine,
                  style: theme.textTheme.headlineSmall?.copyWith(height: 1.3)),
            ),
          ),
          const SizedBox(height: 16),
          Text('How close were you?', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final g in DrillGrade.values) ...[
                Expanded(
                  child: g == DrillGrade.nailed
                      ? FilledButton(
                          key: Key('grade_${g.name}'),
                          onPressed: () => _grade(m, g),
                          child: Text(g.label),
                        )
                      : OutlinedButton(
                          key: Key('grade_${g.name}'),
                          onPressed: () => _grade(m, g),
                          child: Text(g.label),
                        ),
                ),
                if (g != DrillGrade.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
