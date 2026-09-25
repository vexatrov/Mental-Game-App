import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/journal_entry.dart';
import '../../data/providers.dart';
import '../../domain/problem_types.dart';
import '../../ui/widgets.dart';

/// Opens a bottom sheet for jotting a note mid-session without leaving the
/// current screen. Details can be filled in after the close.
Future<void> showQuickNoteSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _QuickNoteSheet(checkIn: false),
  );
}

/// The prompt shown when a check-in is due: either all clear, or a quick
/// note about what's building.
Future<void> showCheckInSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _QuickNoteSheet(checkIn: true),
  );
}

class _QuickNoteSheet extends ConsumerStatefulWidget {
  const _QuickNoteSheet({required this.checkIn});

  final bool checkIn;

  @override
  ConsumerState<_QuickNoteSheet> createState() => _QuickNoteSheetState();
}

class _QuickNoteSheetState extends ConsumerState<_QuickNoteSheet> {
  final _note = TextEditingController();
  ProblemType? _problem;
  double? _intensity;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_note.text.trim().isEmpty) return;
    final now = ref.read(clockProvider)();
    await ref.read(journalRepoProvider).save(JournalEntry(
          id: newId(),
          createdAt: now,
          problem: _problem,
          note: _note.text.trim(),
          intensity: _intensity?.round(),
        ));
    if (widget.checkIn) {
      await ref.read(routineActionsProvider).recordCheckIn(flagged: true);
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note saved. Expand it after the session.')),
    );
  }

  Future<void> _allClear() async {
    await ref.read(routineActionsProvider).recordCheckIn(flagged: false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.checkIn ? 'Check-in' : 'Quick note',
              style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            widget.checkIn
                ? 'Scan your thoughts, body and urges. Anything from your maps '
                    'showing up? If so, jot it down.'
                : 'Jot what you notice now. Add the details once the session '
                    'is over.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('quickNoteField'),
            controller: _note,
            autofocus: !widget.checkIn,
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. Urge to move my target after two winners',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          ProblemPicker(
            value: _problem,
            onChanged: (p) => setState(() => _problem = p),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Intensity', style: theme.textTheme.labelLarge),
              Expanded(
                child: Slider(
                  value: _intensity ?? 0,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: _intensity == null || _intensity == 0
                      ? 'Not rated'
                      : '${_intensity!.round()}',
                  onChanged: (v) =>
                      setState(() => _intensity = v == 0 ? null : v),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(_intensity == null ? '–' : '${_intensity!.round()}'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('quickNoteSave'),
            onPressed: _note.text.trim().isEmpty ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('Save note'),
          ),
          if (widget.checkIn) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('checkInClear'),
              onPressed: _allClear,
              icon: const Icon(Icons.sentiment_satisfied_alt),
              label: const Text('All clear'),
            ),
          ],
        ],
      ),
    );
  }
}
