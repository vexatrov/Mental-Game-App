import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/app_settings.dart';
import '../../data/models/daily_routine.dart';
import '../../data/models/game.dart';
import '../../data/providers.dart';
import '../../ui/widgets.dart';

class SessionEditorScreen extends ConsumerStatefulWidget {
  const SessionEditorScreen({super.key, this.id});

  final String? id;

  @override
  ConsumerState<SessionEditorScreen> createState() =>
      _SessionEditorScreenState();
}

class _SessionEditorScreenState extends ConsumerState<SessionEditorScreen> {
  TradingSession? _session;
  bool _isNew = true;
  bool _dirty = false;
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final existing = widget.id == null
        ? null
        : await ref.read(sessionRepoProvider).get(widget.id!);
    final now = ref.read(clockProvider)();
    // A new session starts from the carry-over rated in today's warm-up.
    final warmup = existing == null
        ? await ref.read(routineRepoProvider).get(dayKey(now))
        : null;
    final session = existing ??
        TradingSession(
          id: newId(),
          date: DateTime(now.year, now.month, now.day),
          score: 50,
          carryOver: warmup?.carryOver ?? 0,
        );
    _notes.text = session.notes;
    _notes.addListener(() {
      if (!_dirty) setState(() => _dirty = true);
    });
    if (!mounted) return;
    setState(() {
      _session = session;
      _isNew = existing == null;
    });
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _update(TradingSession s) => setState(() {
        _session = s;
        _dirty = true;
      });

  Future<void> _save() async {
    final s = _session!.copyWith(notes: _notes.text.trim());
    await ref.read(sessionRepoProvider).save(s);
    setState(() {
      _session = s;
      _isNew = false;
      _dirty = false;
    });
  }

  Future<void> _saveAndClose() async {
    await _save();
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final ok = await confirm(context,
        title: 'Delete session?', message: 'This cannot be undone.');
    if (!ok) return;
    await ref.read(sessionRepoProvider).delete(_session!.id);
    if (mounted) context.pop();
  }

  Future<void> _pickDate() async {
    final now = ref.read(clockProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: _session!.date,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) _update(_session!.copyWith(date: picked));
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final analysis = ref.watch(currentAnalysisProvider).value;
    final band = settings.bandFor(session.score);
    final description = analysis?.level(band);
    return UnsavedChangesGuard(
      dirty: _dirty,
      onSave: _save,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'Log session' : 'Session'),
          actions: [
            if (!_isNew)
              IconButton(
                tooltip: 'Delete',
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
              ),
            IconButton(
              key: const Key('saveSession'),
              tooltip: 'Save',
              onPressed: _saveAndClose,
              icon: const Icon(Icons.check),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(formatDay(session.date)),
              trailing: TextButton(
                  onPressed: _pickDate, child: const Text('Change')),
            ),
            const SectionHeader('Decision quality'),
            Wrap(
              spacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                BandBadge(band, large: true),
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '${session.score}',
                      style: theme.textTheme.displaySmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  TextSpan(text: ' / 100', style: theme.textTheme.titleMedium),
                ])),
              ],
            ),
            Slider(
              key: const Key('scoreSlider'),
              value: session.score.toDouble(),
              min: TradingSession.minScore.toDouble(),
              max: TradingSession.maxScore.toDouble(),
              divisions: TradingSession.maxScore - TradingSession.minScore,
              label: '${session.score}',
              onChanged: (v) => _update(session.copyWith(score: v.round())),
            ),
            Text(
              'Rate how well you made decisions, not how much you made. '
              'C: ≤${settings.cMax} · B: ${settings.cMax + 1}–${settings.bMax} · '
              'A: >${settings.bMax}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (description != null && !description.isEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your ${band.label}',
                          style: theme.textTheme.titleSmall),
                      if (description.mental.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('Mental: ${description.mental}'),
                      ],
                      if (description.tactical.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('Tactical: ${description.tactical}'),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SectionHeader('Carried-over emotion'),
            Text(
              'How much emotion from earlier sessions did you start with?',
              style: theme.textTheme.bodySmall,
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: session.carryOver.toDouble(),
                    max: 100,
                    divisions: 20,
                    label: '${session.carryOver}%',
                    onChanged: (v) =>
                        _update(session.copyWith(carryOver: v.round())),
                  ),
                ),
                SizedBox(width: 48, child: Text('${session.carryOver}%')),
              ],
            ),
            const SectionHeader('Notes'),
            NoteField(
              controller: _notes,
              label: 'What pulled you down, and what worked?',
              minLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
