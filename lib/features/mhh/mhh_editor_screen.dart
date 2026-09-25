import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/journal_entry.dart';
import '../../data/models/mental_hand_history.dart';
import '../../data/providers.dart';
import '../../domain/problem_types.dart';
import '../../ui/widgets.dart';

class _Step {
  const _Step(this.number, this.title, this.hint);
  final int number;
  final String title;
  final String hint;
}

const _step1 = _Step(1, 'Describe the problem in detail',
    'Explain it the way you would to a coach. Add its history: when it started, '
    'and what else was going on in your life then.');
const _step2 = _Step(2, 'Why does it make sense that you have this problem?',
    'Your reaction follows some logic, even if the logic is flawed. '
    '"I\'m just irrational" or "the market screwed me" stops the analysis.');
const _step3 = _Step(3, 'Why is that logic flawed?',
    'Name what is inaccurate, incomplete, or biased in step 2. The emotion is '
    'never the flaw. It is the signal.');
const _step4 = _Step(4, 'What is the correction?',
    'A straightforward, logical fix to the flaw. Often it is an idea you already '
    'know, like variance, applied properly.');
const _step5 = _Step(5, 'Why is the correction correct?',
    'Optional. Spelling it out makes the new logic stick.');

class _ReasonControllers {
  _ReasonControllers(MhhReason r)
      : why = TextEditingController(text: r.why),
        flaw = TextEditingController(text: r.flaw),
        correction = TextEditingController(text: r.correction),
        whyCorrect = TextEditingController(text: r.whyCorrect);

  final TextEditingController why;
  final TextEditingController flaw;
  final TextEditingController correction;
  final TextEditingController whyCorrect;

  List<TextEditingController> get all => [why, flaw, correction, whyCorrect];

  MhhReason toReason() => MhhReason(
        why: why.text.trim(),
        flaw: flaw.text.trim(),
        correction: correction.text.trim(),
        whyCorrect: whyCorrect.text.trim(),
      );

  void dispose() {
    for (final c in all) {
      c.dispose();
    }
  }
}

class MhhEditorScreen extends ConsumerStatefulWidget {
  const MhhEditorScreen({super.key, this.id, this.fromEntryId});

  final String? id;
  final String? fromEntryId;

  @override
  ConsumerState<MhhEditorScreen> createState() => _MhhEditorScreenState();
}

class _MhhEditorScreenState extends ConsumerState<MhhEditorScreen> {
  MentalHandHistory? _mhh;
  bool _isNew = true;
  bool _dirty = false;

  final _description = TextEditingController();
  final List<_ReasonControllers> _reasons = [];
  ProblemType? _problem;
  MhhStatus _status = MhhStatus.draft;
  List<String> _linked = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final existing = widget.id == null
        ? null
        : await ref.read(mhhRepoProvider).get(widget.id!);
    var mhh = existing ??
        MentalHandHistory(id: newId(), createdAt: ref.read(clockProvider)());
    if (existing == null && widget.fromEntryId != null) {
      final entry = await ref.read(journalRepoProvider).get(widget.fromEntryId!);
      if (entry != null) {
        mhh = mhh.copyWith(
          problem: entry.problem,
          description: _describe(entry),
          linkedEntryIds: [entry.id],
        );
      }
    }
    _description.text = mhh.description;
    _description.addListener(_markDirty);
    for (final r in mhh.reasons) {
      _addReasonControllers(r);
    }
    if (!mounted) return;
    setState(() {
      _mhh = mhh;
      _isNew = existing == null;
      _dirty = existing == null && widget.fromEntryId != null;
      _problem = mhh.problem;
      _status = mhh.status;
      _linked = [...mhh.linkedEntryIds];
    });
  }

  String _describe(JournalEntry e) {
    final parts = [
      e.note,
      for (final f in [PatternField.trigger, PatternField.mistake])
        if ((e.fields[f] ?? '').trim().isNotEmpty) '${f.label}: ${e.fields[f]}',
    ];
    return parts.where((p) => p.trim().isNotEmpty).join('\n');
  }

  void _addReasonControllers(MhhReason r) {
    final c = _ReasonControllers(r);
    for (final t in c.all) {
      t.addListener(_markDirty);
    }
    _reasons.add(c);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _description.dispose();
    for (final r in _reasons) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final mhh = _mhh!.copyWith(
      updatedAt: ref.read(clockProvider)(),
      problem: _problem,
      clearProblem: _problem == null,
      description: _description.text.trim(),
      reasons: [for (final r in _reasons) r.toReason()],
      status: _status,
      linkedEntryIds: _linked,
    );
    await ref.read(mhhRepoProvider).save(mhh);
    setState(() {
      _mhh = mhh;
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
        title: 'Delete hand history?', message: 'This cannot be undone.');
    if (!ok) return;
    await ref.read(mhhRepoProvider).delete(_mhh!.id);
    if (mounted) context.pop();
  }

  Future<void> _linkEntry(List<JournalEntry> entries) async {
    final candidates = entries.where((e) => !_linked.contains(e.id)).toList();
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => candidates.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No other journal entries to link.'),
            )
          : ListView(
              children: [
                for (final e in candidates)
                  ListTile(
                    leading: Icon(e.problem?.icon ?? Icons.notes,
                        color: e.problem?.color),
                    title: Text(e.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(formatDateTime(e.createdAt)),
                    onTap: () => Navigator.pop(context, e.id),
                  ),
              ],
            ),
    );
    if (picked != null) {
      setState(() {
        _linked = [..._linked, picked];
        _dirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mhh == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final entries = ref.watch(journalProvider).value ?? const [];
    final byId = {for (final e in entries) e.id: e};
    return UnsavedChangesGuard(
      dirty: _dirty,
      onSave: _save,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'New hand history' : 'Hand history'),
          actions: [
            if (!_isNew)
              IconButton(
                tooltip: 'Delete',
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
              ),
            IconButton(
              key: const Key('saveMhh'),
              tooltip: 'Save',
              onPressed: _saveAndClose,
              icon: const Icon(Icons.check),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            SegmentedButton<MhhStatus>(
              segments: [
                for (final s in MhhStatus.values)
                  ButtonSegment(value: s, label: Text(s.label)),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() {
                _status = s.first;
                _dirty = true;
              }),
            ),
            const SizedBox(height: 12),
            ProblemPicker(
              value: _problem,
              onChanged: (p) => setState(() {
                _problem = p;
                _dirty = true;
              }),
            ),
            const SizedBox(height: 12),
            _StepCard(
              step: _step1,
              child: TextField(
                key: const Key('mhhStep1'),
                controller: _description,
                minLines: 3,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    hintText: 'e.g. I can\'t accept big losses'),
              ),
            ),
            for (final (i, r) in _reasons.indexed)
              _ReasonCard(
                index: i,
                controllers: r,
                showHeader: _reasons.length > 1,
                onRemove: _reasons.length > 1
                    ? () {
                        final removed = _reasons.removeAt(i);
                        setState(() => _dirty = true);
                        // The text fields still hold these until the rebuild.
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => removed.dispose());
                      }
                    : null,
              ),
            TextButton.icon(
              onPressed: () => setState(() {
                _addReasonControllers(const MhhReason());
                _dirty = true;
              }),
              icon: const Icon(Icons.add),
              label: const Text('Add another reason (steps 2–5)'),
            ),
            SectionHeader('Linked journal entries',
                trailing: TextButton.icon(
                  onPressed: () => _linkEntry(entries),
                  icon: const Icon(Icons.link),
                  label: const Text('Link'),
                )),
            if (_linked.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('Link the journal notes that show this problem.'),
              ),
            for (final id in _linked)
              Card(
                child: ListTile(
                  leading: Icon(byId[id]?.problem?.icon ?? Icons.notes,
                      color: byId[id]?.problem?.color),
                  title: Text(byId[id]?.title ?? 'Deleted entry',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: byId[id] == null
                      ? null
                      : Text(formatDateTime(byId[id]!.createdAt)),
                  onTap: byId[id] == null
                      ? null
                      : () => context.push('/journal/edit?id=$id'),
                  trailing: IconButton(
                    tooltip: 'Unlink',
                    icon: const Icon(Icons.link_off),
                    onPressed: () => setState(() {
                      _linked = [..._linked]..remove(id);
                      _dirty = true;
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.child});

  final _Step step;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text('${step.number}',
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(step.hint,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ReasonCard extends StatelessWidget {
  const _ReasonCard({
    required this.index,
    required this.controllers,
    required this.showHeader,
    this.onRemove,
  });

  final int index;
  final _ReasonControllers controllers;
  final bool showHeader;
  final VoidCallback? onRemove;

  Widget _field(TextEditingController c, String key) => TextField(
        key: Key('mhh${key}_$index'),
        controller: c,
        minLines: 2,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
      );

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        _StepCard(step: _step2, child: _field(controllers.why, 'Why')),
        _StepCard(step: _step3, child: _field(controllers.flaw, 'Flaw')),
        _StepCard(
            step: _step4, child: _field(controllers.correction, 'Correction')),
        _StepCard(
            step: _step5, child: _field(controllers.whyCorrect, 'WhyCorrect')),
      ],
    );
    if (!showHeader) return content;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Column(
          children: [
            Row(
              children: [
                Text('Reason ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove reason',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            content,
          ],
        ),
      ),
    );
  }
}
