import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/app_settings.dart';
import '../../data/models/emotion_map.dart';
import '../../data/models/journal_entry.dart';
import '../../data/models/mental_hand_history.dart';
import '../../data/providers.dart';
import '../../domain/problem_types.dart';
import '../../ui/widgets.dart';

enum _Disrupt {
  breathe('Breathe', Icons.air),
  write('Write', Icons.edit_note),
  stand('Stand up', Icons.directions_walk),
  talk('Talk', Icons.record_voice_over_outlined);

  const _Disrupt(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// The real-time strategy: recognise the pattern, break its momentum,
/// inject your correction, and protect execution with a reminder.
class ResetScreen extends ConsumerStatefulWidget {
  const ResetScreen({super.key, this.initialProblem});

  final String? initialProblem;

  @override
  ConsumerState<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends ConsumerState<ResetScreen> {
  static const _titles = [
    'What\'s building?',
    'Break the momentum',
    'Your correction',
    'Protect your execution',
  ];

  final _pages = PageController();
  final _written = TextEditingController();
  int _step = 0;
  ProblemType? _problem;
  String? _mapId;
  int? _level;
  _Disrupt _disrupt = _Disrupt.breathe;

  @override
  void initState() {
    super.initState();
    _problem = ProblemType.tryParse(widget.initialProblem);
  }

  @override
  void dispose() {
    _pages.dispose();
    _written.dispose();
    super.dispose();
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _pages.animateToPage(step,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  EmotionMap? _selectedMap(List<EmotionMap> maps) {
    final forProblem = maps.where((m) => m.problem == _problem).toList();
    return forProblem.where((m) => m.id == _mapId).firstOrNull ??
        forProblem.firstOrNull;
  }

  Future<void> _finish({required bool stopForToday}) async {
    final now = ref.read(clockProvider)();
    final map = _selectedMap(ref.read(currentMapsProvider).value ?? const []);
    final level = _level;
    final summary = [
      'Reset',
      if (map != null && level != null) '${map.name} at level $level'
      else if (_problem != null) _problem!.label,
    ].join(' · ');
    final note = [
      summary,
      if (_written.text.trim().isNotEmpty) _written.text.trim(),
      if (stopForToday) 'Stopped trading for the day.',
    ].join('\n');
    await ref.read(journalRepoProvider).save(JournalEntry(
          id: newId(),
          createdAt: now,
          problem: _problem,
          subtype: map?.subtype,
          note: note,
          intensity: map != null && level != null
              ? (map.scale.severity(level) * 9).round() + 1
              : null,
        ));
    await ref.read(routineActionsProvider).recordReset();
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(stopForToday
          ? 'Logged. Good call: protect tomorrow.'
          : 'Logged in your journal. Back to it.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(_titles[_step]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_step + 1) / _titles.length),
        ),
      ),
      body: PageView(
        controller: _pages,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _RecognizeStep(
            problem: _problem,
            mapId: _mapId,
            level: _level,
            onProblem: (p) => setState(() {
              _problem = p;
              _mapId = null;
              _level = null;
            }),
            onMap: (id) => setState(() {
              _mapId = id;
              _level = null;
            }),
            onLevel: (l) => setState(() => _level = l),
          ),
          _DisruptStep(
            method: _disrupt,
            written: _written,
            onMethod: (m) => setState(() => _disrupt = m),
          ),
          _CorrectStep(problem: _problem),
          const _ExecuteStep(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_step > 0)
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => _go(_step - 1),
                  icon: const Icon(Icons.arrow_back),
                )
              else
                const SizedBox(width: 8),
              const SizedBox(width: 8),
              Expanded(
                child: _step < _titles.length - 1
                    ? FilledButton.icon(
                        key: const Key('resetNext'),
                        onPressed: _step == 0 && _problem == null
                            ? null
                            : () => _go(_step + 1),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next'),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            key: const Key('resetDone'),
                            onPressed: () => _finish(stopForToday: false),
                            icon: const Icon(Icons.check),
                            label: const Text('Back to trading'),
                          ),
                          TextButton(
                            key: const Key('resetStop'),
                            onPressed: () => _finish(stopForToday: true),
                            child: Text('Call it a day',
                                style:
                                    TextStyle(color: theme.colorScheme.error)),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({required this.lead, required this.children});

  final String lead;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(lead,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

class _RecognizeStep extends ConsumerWidget {
  const _RecognizeStep({
    required this.problem,
    required this.mapId,
    required this.level,
    required this.onProblem,
    required this.onMap,
    required this.onLevel,
  });

  final ProblemType? problem;
  final String? mapId;
  final int? level;
  final ValueChanged<ProblemType?> onProblem;
  final ValueChanged<String> onMap;
  final ValueChanged<int> onLevel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final maps = (ref.watch(currentMapsProvider).value ?? const [])
        .where((m) => m.problem == problem)
        .toList();
    final map = maps.where((m) => m.id == mapId).firstOrNull ?? maps.firstOrNull;
    return _StepBody(
      lead: 'Name it. Spotting the pattern is what gives you the chance to '
          'stop it.',
      children: [
        ProblemPicker(value: problem, onChanged: onProblem),
        if (problem != null && maps.isEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.stacked_bar_chart),
              title: Text('No ${problem!.label.toLowerCase()} map yet'),
              subtitle: const Text(
                  'After this, build one so you can catch it earlier.'),
            ),
          ),
        ],
        if (map != null) ...[
          if (maps.length > 1) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final m in maps)
                  ChoiceChip(
                    label: Text(m.name),
                    selected: m.id == map.id,
                    onSelected: (_) => onMap(m.id),
                  ),
              ],
            ),
          ],
          SectionHeader('Where are you on your ${map.name} map?'),
          if (map.filledEntries.isEmpty)
            const Text('This map has no levels yet.'),
          for (final e in map.filledEntries)
            Card(
              color: level == e.key
                  ? map.scale.color(e.key).withValues(alpha: 0.18)
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: level == e.key
                      ? map.scale.color(e.key)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ListTile(
                key: Key('resetLevel_${e.key}'),
                onTap: () => onLevel(e.key),
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: map.scale.color(e.key),
                  child: Text('${e.key}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text(e.value.mental.isEmpty ? '–' : e.value.mental),
                subtitle: e.value.technical.isEmpty
                    ? null
                    : Text(e.value.technical,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontStyle: FontStyle.italic)),
              ),
            ),
        ],
      ],
    );
  }
}

class _DisruptStep extends StatelessWidget {
  const _DisruptStep({
    required this.method,
    required this.written,
    required this.onMethod,
  });

  final _Disrupt method;
  final TextEditingController written;
  final ValueChanged<_Disrupt> onMethod;

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      lead: 'Put a gap between the reaction and your next click. Pick '
          'whatever works right now.',
      children: [
        SegmentedButton<_Disrupt>(
          showSelectedIcon: false,
          segments: [
            for (final d in _Disrupt.values)
              ButtonSegment(
                  value: d, icon: Icon(d.icon), label: Text(d.label)),
          ],
          selected: {method},
          onSelectionChanged: (s) => onMethod(s.first),
        ),
        const SizedBox(height: 24),
        switch (method) {
          _Disrupt.breathe => const _BreathGuide(),
          _Disrupt.write => TextField(
              key: const Key('resetWrite'),
              controller: written,
              autofocus: true,
              minLines: 4,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'What\'s happening right now? What do you feel, '
                    'what do you want to do?',
              ),
            ),
          _Disrupt.stand => const _StandUpTimer(),
          _Disrupt.talk => const _Prompt(
              icon: Icons.record_voice_over_outlined,
              text: 'Say it out loud, or message a trading friend: what are '
                  'you feeling, and what is it pushing you to do?',
            ),
        },
      ],
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ],
      );
}

/// A slow breathing pace: in for four seconds, out for six.
class _BreathGuide extends StatefulWidget {
  const _BreathGuide();

  @override
  State<_BreathGuide> createState() => _BreathGuideState();
}

class _BreathGuideState extends State<_BreathGuide>
    with SingleTickerProviderStateMixin {
  static const _inFraction = 0.4;

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );
  int _breaths = 0;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() => _breaths++);
        _controller.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final breathingIn = t < _inFraction;
            final size = breathingIn
                ? 110 + 90 * Curves.easeInOut.transform(t / _inFraction)
                : 200 -
                    90 *
                        Curves.easeInOut.transform(
                            (t - _inFraction) / (1 - _inFraction));
            return SizedBox(
              height: 220,
              child: Center(
                child: Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primaryContainer,
                    border: Border.all(color: scheme.primary, width: 2),
                  ),
                  child: Text(
                    !_controller.isAnimating
                        ? 'Ready'
                        : breathingIn
                            ? 'Breathe in'
                            : 'Breathe out',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        if (!_controller.isAnimating)
          FilledButton.tonalIcon(
            key: const Key('startBreathing'),
            onPressed: () => setState(() => _controller.forward(from: 0)),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start'),
          )
        else
          Text(
            'Breathe into your belly. Keep your attention on the breath. '
            '$_breaths done.',
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

class _StandUpTimer extends StatefulWidget {
  const _StandUpTimer();

  @override
  State<_StandUpTimer> createState() => _StandUpTimerState();
}

class _StandUpTimerState extends State<_StandUpTimer> {
  static const _seconds = 60;
  Timer? _timer;
  int _left = _seconds;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() => _left = _seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) t.cancel();
      setState(() => _left--);
    });
  }

  @override
  Widget build(BuildContext context) {
    final running = _timer?.isActive ?? false;
    return Column(
      children: [
        const _Prompt(
          icon: Icons.directions_walk,
          text: 'Stand up and step away from the screen. Come back when your '
              'head is clearer.',
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 90,
          height: 90,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: running ? _left / _seconds : 1,
                strokeWidth: 6,
              ),
              Center(
                child: Text(running || _left < _seconds ? '$_left' : '60s',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!running)
          TextButton(
            onPressed: _start,
            child: Text(_left < _seconds ? 'Again' : 'Start a minute'),
          ),
      ],
    );
  }
}

class _CorrectStep extends ConsumerWidget {
  const _CorrectStep({required this.problem});

  final ProblemType? problem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final all = (ref.watch(mhhListProvider).value ?? const [])
        .where((m) => m.logicLine.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => (b.status == MhhStatus.solid ? 1 : 0)
          .compareTo(a.status == MhhStatus.solid ? 1 : 0));
    final matching = all.where((m) => m.problem == problem).toList();
    final others = all.where((m) => m.problem != problem).toList();

    Widget lineCard(MentalHandHistory m, {bool large = true}) => Card(
          color: large ? theme.colorScheme.primaryContainer : null,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.logicLine,
                  style: (large
                          ? theme.textTheme.headlineSmall
                          : theme.textTheme.titleMedium)
                      ?.copyWith(height: 1.3),
                ),
                const SizedBox(height: 10),
                Text('From: ${m.title}',
                    style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        );

    if (all.isEmpty) {
      return _StepBody(
        lead: 'Your correction line is the logic that answers this reaction.',
        children: [
          const Text(
              'You don\'t have one yet. Work through a Mental Hand History, '
              'then boil the correction down to one line you can say to '
              'yourself.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.push('/mhh/edit'),
            icon: const Icon(Icons.psychology),
            label: const Text('Start a hand history'),
          ),
        ],
      );
    }
    return _StepBody(
      lead: 'Read it slowly, and mean it. This is the logic you worked out '
          'when you were thinking clearly.',
      children: [
        for (final m in matching) lineCard(m),
        if (others.isNotEmpty) ...[
          SectionHeader(matching.isEmpty
              ? 'Your correction lines'
              : 'Other correction lines'),
          for (final m in others) lineCard(m, large: matching.isEmpty),
        ],
      ],
    );
  }
}

class _ExecuteStep extends ConsumerWidget {
  const _ExecuteStep();

  Future<void> _edit(
      BuildContext context, WidgetRef ref, AppSettings settings) async {
    final result = await showDialog<(ReminderKind, String)>(
      context: context,
      builder: (_) => StrategicReminderDialog(settings: settings),
    );
    if (result == null) return;
    await ref.read(settingsRepoProvider).save(settings.copyWith(
        reminderKind: result.$1, reminderText: result.$2.trim()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final empty = settings.reminderText.trim().isEmpty;
    return _StepBody(
      lead: 'Emotion knocks out parts of your process. Check the technical '
          'side before the next trade.',
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 8, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(settings.reminderKind.label,
                          style: theme.textTheme.titleMedium),
                    ),
                    IconButton(
                      key: const Key('editReminder'),
                      tooltip: 'Edit',
                      onPressed: () => _edit(context, ref, settings),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  empty
                      ? 'Write your Strategic Reminder: the mistakes you tend '
                          'to make, your decision process, or the factors you '
                          'stop considering when emotional.'
                      : settings.reminderText,
                  style: empty
                      ? theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)
                      : theme.textTheme.titleMedium?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class StrategicReminderDialog extends StatefulWidget {
  const StrategicReminderDialog({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<StrategicReminderDialog> createState() =>
      _StrategicReminderDialogState();
}

class _StrategicReminderDialogState extends State<StrategicReminderDialog> {
  late ReminderKind _kind = widget.settings.reminderKind;
  late final _text = TextEditingController(text: widget.settings.reminderText);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Strategic Reminder'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<ReminderKind>(
              initialValue: _kind,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final k in ReminderKind.values)
                  DropdownMenuItem(value: k, child: Text(k.label)),
              ],
              onChanged: (k) => setState(() => _kind = k!),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('reminderText'),
              controller: _text,
              minLines: 4,
              maxLines: 10,
              decoration: InputDecoration(hintText: _kind.hint),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, (_kind, _text.text)),
            child: const Text('Save')),
      ],
    );
  }
}
