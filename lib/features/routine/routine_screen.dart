import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/app_settings.dart';
import '../../data/models/daily_routine.dart';
import '../../data/providers.dart';
import '../../domain/routine.dart';
import '../../ui/widgets.dart';

/// Progress through [phase] today: (done, total).
(int, int) routineProgress(
  RoutinePhase phase,
  AppSettings settings,
  DailyRoutine routine, {
  required bool sessionLogged,
}) {
  final items = settings.routineItems(phase);
  final done = items
      .where((i) =>
          isItemDone(i, phase, routine, sessionLogged: sessionLogged))
      .length;
  return (done, items.length);
}

class RoutineScreen extends ConsumerStatefulWidget {
  const RoutineScreen({super.key, required this.phase});

  final RoutinePhase phase;

  @override
  ConsumerState<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends ConsumerState<RoutineScreen> {
  bool _editing = false;
  final _newItem = TextEditingController();

  @override
  void dispose() {
    _newItem.dispose();
    super.dispose();
  }

  Future<void> _addItem(AppSettings settings) async {
    final label = _newItem.text.trim();
    if (label.isEmpty) return;
    final items = [
      ...settings.customItems(widget.phase),
      RoutineItem(id: '${RoutineItem.customPrefix}${newId()}', label: label),
    ];
    await ref
        .read(settingsRepoProvider)
        .save(settings.withCustomItems(widget.phase, items));
    _newItem.clear();
  }

  Future<void> _removeItem(AppSettings settings, RoutineItem item) async {
    final items = [...settings.customItems(widget.phase)]
      ..removeWhere((i) => i.id == item.id);
    await ref
        .read(settingsRepoProvider)
        .save(settings.withCustomItems(widget.phase, items));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final routineValue = ref.watch(todayRoutineProvider);
    final now = ref.watch(clockProvider)();
    final sessions = ref.watch(sessionsProvider).value ?? const [];
    final sessionToday = sessions.where((s) => isSameDay(s.date, now)).firstOrNull;
    final isWarmup = widget.phase == RoutinePhase.warmup;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.phase.label),
        actions: [
          TextButton(
            onPressed: () => setState(() => _editing = !_editing),
            child: Text(_editing ? 'Done' : 'Edit list'),
          ),
        ],
      ),
      body: AsyncBody(
        value: routineValue,
        builder: (routine) {
          final items = settings.routineItems(widget.phase);
          final (done, total) = routineProgress(widget.phase, settings, routine,
              sessionLogged: sessionToday != null);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              Text(
                isWarmup
                    ? 'A few focused minutes before the open, so your signals '
                        'and corrections are front of mind.'
                    : 'Within half an hour of the close, while the details '
                        'are still fresh.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : done / total,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('$done / $total', style: theme.textTheme.labelLarge),
                ],
              ),
              const SizedBox(height: 12),
              for (final item in items)
                _ItemCard(
                  key: ValueKey(item.id),
                  item: item,
                  phase: widget.phase,
                  routine: routine,
                  settings: settings,
                  sessionId: sessionToday?.id,
                  editing: _editing,
                  onRemove: () => _removeItem(settings, item),
                ),
              if (_editing)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('newRoutineItem'),
                          controller: _newItem,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                              hintText: 'Add your own step'),
                          onSubmitted: (_) => _addItem(settings),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Add',
                        onPressed: () => _addItem(settings),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              if (!isWarmup && routine.checkIns > 0) ...[
                const SectionHeader('Check-ins today'),
                Text(
                  '${routine.checkIns} check-ins, ${routine.flaggedCheckIns} '
                  'with something building.',
                ),
              ],
              if (isWarmup && routine.timerStart == null) ...[
                const SizedBox(height: 8),
                Text(
                  'Tip: your own steps (Edit list) could include checking the '
                  'news calendar or your strategy notes.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  const _ItemCard({
    super.key,
    required this.item,
    required this.phase,
    required this.routine,
    required this.settings,
    required this.sessionId,
    required this.editing,
    required this.onRemove,
  });

  final RoutineItem item;
  final RoutinePhase phase;
  final DailyRoutine routine;
  final AppSettings settings;
  final String? sessionId;
  final bool editing;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final done = isItemDone(item, phase, routine, sessionLogged: sessionId != null);
    final actions = ref.read(routineActionsProvider);
    final (String, VoidCallback)? link = switch (item.action) {
      RoutineAction.reviewMaps => ('Open', () => context.push('/maps/review')),
      RoutineAction.reviewHandHistories => ('Open', () => context.go('/mhh')),
      RoutineAction.logSession => (
          sessionId == null ? 'Log' : 'Edit',
          () => context.push(sessionId == null
              ? '/game/session'
              : '/game/session?id=$sessionId'),
        ),
      RoutineAction.expandNotes => ('Open', () => context.go('/journal')),
      RoutineAction.handHistory => ('New', () => context.push('/mhh/edit')),
      _ => null,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  key: Key('routineCheck_${item.id}'),
                  value: done,
                  onChanged: (_) => actions.toggle(phase, item.id),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              decoration:
                                  done ? TextDecoration.lineThrough : null,
                            )),
                        if (item.hint != null)
                          Text(item.hint!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                if (editing && item.isCustom)
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  )
                else if (link != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton(onPressed: link.$2, child: Text(link.$1)),
                  ),
              ],
            ),
            switch (item.action) {
              RoutineAction.carryOver => _CarryOverSlider(routine: routine),
              RoutineAction.timer =>
                _TimerControls(routine: routine, settings: settings),
              RoutineAction.vent => _AutosaveField(
                  key: const Key('ventField'),
                  initial: routine.vent,
                  hint: 'Whatever is still bouncing around: trades, feelings, '
                      'what you would do differently',
                  onSave: actions.setVent,
                ),
              RoutineAction.improved => _AutosaveField(
                  key: const Key('improvedField'),
                  initial: routine.improved,
                  hint: 'e.g. Caught the urge to chase and stayed out',
                  onSave: actions.setImproved,
                ),
              _ => const SizedBox.shrink(),
            },
          ],
        ),
      ),
    );
  }
}

class _CarryOverSlider extends ConsumerStatefulWidget {
  const _CarryOverSlider({required this.routine});

  final DailyRoutine routine;

  @override
  ConsumerState<_CarryOverSlider> createState() => _CarryOverSliderState();
}

class _CarryOverSliderState extends ConsumerState<_CarryOverSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final value = _dragging ?? (widget.routine.carryOver ?? 0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        children: [
          Expanded(
            child: Slider(
              key: const Key('carryOverSlider'),
              value: value,
              max: 100,
              divisions: 20,
              label: '${value.round()}%',
              onChanged: (v) => setState(() => _dragging = v),
              onChangeEnd: (v) async {
                await ref.read(routineActionsProvider).setCarryOver(v.round());
                if (mounted) setState(() => _dragging = null);
              },
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(widget.routine.carryOver == null && _dragging == null
                ? '–'
                : '${value.round()}%'),
          ),
        ],
      ),
    );
  }
}

class _TimerControls extends ConsumerStatefulWidget {
  const _TimerControls({required this.routine, required this.settings});

  final DailyRoutine routine;
  final AppSettings settings;

  @override
  ConsumerState<_TimerControls> createState() => _TimerControlsState();
}

class _TimerControlsState extends ConsumerState<_TimerControls> {
  bool _exact = true;

  @override
  void initState() {
    super.initState();
    ref.read(reminderSchedulerProvider).canBeExact().then((v) {
      if (mounted) setState(() => _exact = v);
    });
  }

  Future<void> _start() async {
    final allowed = await ref.read(routineActionsProvider).startTimer(
          minutes: widget.settings.checkInMinutes,
          hours: widget.settings.sessionHours,
        );
    if (!allowed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Notifications are off, so check-ins will only '
            'appear while the app is open.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final routine = widget.routine;
    final running = routine.timerRunning(now);
    final time = DateFormat.jm();
    final next = running
        ? checkInTimes(routine.timerStart!, routine.timerEnd!,
                Duration(minutes: routine.timerMinutes))
            .where((t) => t.isAfter(now))
            .firstOrNull
        : null;
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (running) ...[
            Text('Every ${routine.timerMinutes} min until '
                '${time.format(routine.timerEnd!)}'
                '${next == null ? '' : ' · next at ${time.format(next)}'}'),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              key: const Key('stopTimer'),
              onPressed: () => ref.read(routineActionsProvider).stopTimer(),
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
            ),
          ] else
            FilledButton.tonalIcon(
              key: const Key('startTimer'),
              onPressed: _start,
              icon: const Icon(Icons.timer_outlined),
              label: Text('Every ${widget.settings.checkInMinutes} min for '
                  '${widget.settings.sessionHours} h'),
            ),
          if (!_exact)
            TextButton(
              onPressed: () =>
                  ref.read(reminderSchedulerProvider).requestExact(),
              child: const Text('Allow exact reminder times'),
            ),
        ],
      ),
    );
  }
}

/// A text field that saves itself shortly after typing stops.
class _AutosaveField extends StatefulWidget {
  const _AutosaveField({
    super.key,
    required this.initial,
    required this.hint,
    required this.onSave,
  });

  final String initial;
  final String hint;
  final Future<void> Function(String) onSave;

  @override
  State<_AutosaveField> createState() => _AutosaveFieldState();
}

class _AutosaveFieldState extends State<_AutosaveField> {
  late final _controller = TextEditingController(text: widget.initial);
  Timer? _debounce;

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      widget.onSave(_controller.text.trim());
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 6),
      child: TextField(
        controller: _controller,
        minLines: 2,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: widget.hint),
        onChanged: (text) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 600),
              () => widget.onSave(text.trim()));
        },
      ),
    );
  }
}
