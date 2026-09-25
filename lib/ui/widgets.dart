import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/models/game.dart';
import '../domain/problem_types.dart';

String formatDay(DateTime d) => DateFormat.yMMMEd().format(d);
String formatDateTime(DateTime d) => DateFormat.MMMd().add_jm().format(d);
String formatMonth(DateTime d) => DateFormat.yMMM().format(d);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

Color bandColor(GameLevel level, ColorScheme scheme) => switch (level) {
      GameLevel.a => const Color(0xFF3FAE6A),
      GameLevel.b => const Color(0xFFF2A516),
      GameLevel.c => const Color(0xFFE0524D),
    };

/// Renders an [AsyncValue] with shared loading and error states.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.builder});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) => switch (value) {
        AsyncData(:final value) => builder(value),
        AsyncError(:final error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Something went wrong: $error'),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      };
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title,
                style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class ProblemBadge extends StatelessWidget {
  const ProblemBadge(this.problem, {super.key, this.subtype});

  final ProblemType problem;
  final String? subtype;

  @override
  Widget build(BuildContext context) {
    final text = subtype == null ? problem.label : subtype!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: problem.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(problem.icon, size: 14, color: problem.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class BandBadge extends StatelessWidget {
  const BandBadge(this.level, {super.key, this.large = false, this.small = false});

  final GameLevel level;
  final bool large;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final color = bandColor(level, Theme.of(context).colorScheme);
    final size = large ? 44.0 : small ? 22.0 : 30.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        level.letter,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: large ? 20 : small ? 11 : 14,
          color: color,
        ),
      ),
    );
  }
}

/// Choice chips for picking a problem type, with an optional "none" option.
class ProblemPicker extends StatelessWidget {
  const ProblemPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.allowNone = true,
  });

  final ProblemType? value;
  final ValueChanged<ProblemType?> onChanged;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final p in ProblemType.values)
          ChoiceChip(
            avatar: Icon(p.icon, size: 18, color: p.color),
            showCheckmark: false,
            selectedColor: p.color.withValues(alpha: 0.22),
            side: value == p ? BorderSide(color: p.color) : null,
            label: Text(p.label),
            selected: value == p,
            onSelected: (sel) =>
                onChanged(sel ? p : (allowNone ? null : value)),
          ),
      ],
    );
  }
}

class SubtypeDropdown extends StatelessWidget {
  const SubtypeDropdown({
    super.key,
    required this.problem,
    required this.value,
    required this.onChanged,
  });

  final ProblemType problem;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (problem.subtypes.isEmpty) return const SizedBox.shrink();
    final current = problem.subtypes.contains(value) ? value : null;
    return DropdownButtonFormField<String?>(
      key: ValueKey(problem),
      initialValue: current,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Type (optional)'),
      items: [
        const DropdownMenuItem(value: null, child: Text('General')),
        for (final s in problem.subtypes)
          DropdownMenuItem(value: s, child: Text(s)),
      ],
      onChanged: onChanged,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel)),
      ],
    ),
  );
  return result ?? false;
}

/// Asks before leaving an editor with unsaved changes.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.dirty,
    required this.onSave,
    required this.child,
  });

  final bool dirty;
  final Future<void> Function() onSave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final choice = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Save changes?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Discard')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save')),
            ],
          ),
        );
        if (choice == null || !context.mounted) return;
        if (choice) await onSave();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: child,
    );
  }
}

/// A multi-line text field that grows with its content.
class NoteField extends StatelessWidget {
  const NoteField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.minLines = 2,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int minLines;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        minLines: minLines,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}
