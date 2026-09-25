import '../data/models/daily_routine.dart';

enum RoutinePhase {
  warmup('Warm-up'),
  cooldown('Cool-down');

  const RoutinePhase(this.label);
  final String label;

  static RoutinePhase parse(Object? name) =>
      values.firstWhere((p) => p.name == name, orElse: () => warmup);
}

/// What tapping an item's action does, and how it can complete itself.
enum RoutineAction {
  none,
  reviewMaps,
  reviewHandHistories,
  carryOver,
  timer,
  logSession,
  expandNotes,
  vent,
  improved,
  handHistory,
}

class RoutineItem {
  const RoutineItem({
    required this.id,
    required this.label,
    this.hint,
    this.action = RoutineAction.none,
  });

  final String id;
  final String label;
  final String? hint;
  final RoutineAction action;

  bool get isCustom => id.startsWith(customPrefix);

  static const customPrefix = 'custom:';

  Map<String, Object?> toJson() => {'id': id, 'label': label};

  static RoutineItem? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final label = json['label'];
    if (id is! String || label is! String || label.trim().isEmpty) return null;
    return RoutineItem(id: id, label: label);
  }
}

const warmupItems = [
  RoutineItem(
    id: 'review_maps',
    label: 'Read through your emotion maps',
    hint: 'Refresh the early signals so you can spot them live.',
    action: RoutineAction.reviewMaps,
  ),
  RoutineItem(
    id: 'review_corrections',
    label: 'Reread your hand history corrections',
    hint: 'Keep the corrected logic fresh before you need it.',
    action: RoutineAction.reviewHandHistories,
  ),
  RoutineItem(
    id: 'rehearse',
    label: 'Rehearse a recent trigger',
    hint: 'Picture the signal, a deep breath, and your correction.',
  ),
  RoutineItem(
    id: 'carry_over',
    label: 'Rate the emotion you carried over',
    hint: 'Leftover emotion from earlier days makes today harder.',
    action: RoutineAction.carryOver,
  ),
  RoutineItem(
    id: 'timer',
    label: 'Start your check-in timer',
    hint: 'A regular nudge to scan your state while trading.',
    action: RoutineAction.timer,
  ),
];

const cooldownItems = [
  RoutineItem(
    id: 'log_session',
    label: 'Score today\'s decisions',
    hint: 'Rate the quality of your decisions, not the PnL.',
    action: RoutineAction.logSession,
  ),
  RoutineItem(
    id: 'expand_notes',
    label: 'Expand today\'s quick notes',
    hint: 'Add any new signals you noticed to your maps.',
    action: RoutineAction.expandNotes,
  ),
  RoutineItem(
    id: 'vent',
    label: 'Write out what\'s still on your mind',
    hint: 'Getting it on paper stops it piling up into tomorrow.',
    action: RoutineAction.vent,
  ),
  RoutineItem(
    id: 'improved',
    label: 'Note what went better',
    hint: 'Progress is easy to miss if you only look at mistakes.',
    action: RoutineAction.improved,
  ),
  RoutineItem(
    id: 'hand_history',
    label: 'Big emotions today? Work a hand history',
    hint: 'Start a new one or reread the one that fits.',
    action: RoutineAction.handHistory,
  ),
];

List<RoutineItem> builtInItems(RoutinePhase phase) =>
    phase == RoutinePhase.warmup ? warmupItems : cooldownItems;

/// Whether [item] counts as done: ticked by hand, or completed by doing it.
bool isItemDone(
  RoutineItem item,
  RoutinePhase phase,
  DailyRoutine routine, {
  required bool sessionLogged,
}) {
  final checked = phase == RoutinePhase.warmup
      ? routine.warmupChecked
      : routine.cooldownChecked;
  if (checked.contains(item.id)) return true;
  return switch (item.action) {
    RoutineAction.carryOver => routine.carryOver != null,
    RoutineAction.timer => routine.timerStart != null,
    RoutineAction.logSession => sessionLogged,
    RoutineAction.vent => routine.vent.trim().isNotEmpty,
    RoutineAction.improved => routine.improved.trim().isNotEmpty,
    _ => false,
  };
}

/// Times a check-in is due between [start] and [end], every [every].
List<DateTime> checkInTimes(DateTime start, DateTime end, Duration every) {
  if (every <= Duration.zero) return const [];
  return [
    for (var t = start.add(every); !t.isAfter(end); t = t.add(every)) t,
  ];
}
