import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/daily_routine.dart';
import '../../data/providers.dart';
import '../../domain/routine.dart';
import '../journal/quick_note_sheet.dart';

/// While the check-in timer runs, prompts in the app each time a check-in is
/// due, and opens the check-in sheet whenever one is triggered (in-app or
/// from a tapped notification).
class CheckInTicker extends ConsumerStatefulWidget {
  const CheckInTicker({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CheckInTicker> createState() => _CheckInTickerState();
}

class _CheckInTickerState extends ConsumerState<CheckInTicker> {
  Timer? _timer;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(todayRoutineProvider, (_, next) => _reschedule(next.value),
        fireImmediately: true);
    ref.listenManual(checkInPromptProvider, (_, _) => _prompt());
    // A tapped reminder that launched the app fires before this listens.
    if (ref.read(checkInPromptProvider) > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prompt());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reschedule(DailyRoutine? routine) {
    _timer?.cancel();
    _timer = null;
    if (routine == null) return;
    final now = ref.read(clockProvider)();
    if (!routine.timerRunning(now)) return;
    final next = checkInTimes(routine.timerStart!, routine.timerEnd!,
            Duration(minutes: routine.timerMinutes))
        .where((t) => t.isAfter(now))
        .firstOrNull;
    if (next == null) return;
    _timer = Timer(next.difference(now), () {
      ref.read(checkInPromptProvider.notifier).trigger();
      _reschedule(ref.read(todayRoutineProvider).value);
    });
  }

  Future<void> _prompt() async {
    if (_sheetOpen || !mounted) return;
    _sheetOpen = true;
    await showCheckInSheet(context);
    _sheetOpen = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
