import 'doc.dart';

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// One day's warm-up, cool-down and check-in timer, keyed by date.
class DailyRoutine implements Doc {
  DailyRoutine({
    required this.day,
    this.warmupChecked = const {},
    this.cooldownChecked = const {},
    this.carryOver,
    this.vent = '',
    this.improved = '',
    this.checkIns = 0,
    this.flaggedCheckIns = 0,
    this.timerStart,
    this.timerEnd,
    this.timerMinutes = 30,
  });

  factory DailyRoutine.empty(DateTime now) =>
      DailyRoutine(day: DateTime(now.year, now.month, now.day));

  final DateTime day;
  final Set<String> warmupChecked;
  final Set<String> cooldownChecked;

  /// Leftover emotion from earlier sessions, 0–100%, rated before the open.
  final int? carryOver;

  /// Post-session writing to get the day out of your head.
  final String vent;

  /// What went better today.
  final String improved;

  final int checkIns;

  /// Check-ins where something was building and a note was saved.
  final int flaggedCheckIns;

  final DateTime? timerStart;
  final DateTime? timerEnd;
  final int timerMinutes;

  @override
  String get id => dayKey(day);

  bool timerRunning(DateTime now) =>
      timerStart != null && timerEnd != null && now.isBefore(timerEnd!);

  DailyRoutine copyWith({
    Set<String>? warmupChecked,
    Set<String>? cooldownChecked,
    int? carryOver,
    String? vent,
    String? improved,
    int? checkIns,
    int? flaggedCheckIns,
    DateTime? timerStart,
    DateTime? timerEnd,
    int? timerMinutes,
  }) =>
      DailyRoutine(
        day: day,
        warmupChecked: warmupChecked ?? this.warmupChecked,
        cooldownChecked: cooldownChecked ?? this.cooldownChecked,
        carryOver: carryOver ?? this.carryOver,
        vent: vent ?? this.vent,
        improved: improved ?? this.improved,
        checkIns: checkIns ?? this.checkIns,
        flaggedCheckIns: flaggedCheckIns ?? this.flaggedCheckIns,
        timerStart: timerStart ?? this.timerStart,
        timerEnd: timerEnd ?? this.timerEnd,
        timerMinutes: timerMinutes ?? this.timerMinutes,
      );

  @override
  Map<String, Object?> toJson() => {
        'id': id,
        'day': day.millisecondsSinceEpoch,
        'warmupChecked': warmupChecked.toList(),
        'cooldownChecked': cooldownChecked.toList(),
        'carryOver': carryOver,
        'vent': vent,
        'improved': improved,
        'checkIns': checkIns,
        'flaggedCheckIns': flaggedCheckIns,
        'timerStart': timerStart?.millisecondsSinceEpoch,
        'timerEnd': timerEnd?.millisecondsSinceEpoch,
        'timerMinutes': timerMinutes,
      };

  factory DailyRoutine.fromJson(Map<String, Object?> json) => DailyRoutine(
        day: readDate(json['day']),
        warmupChecked: readStringList(json['warmupChecked']).toSet(),
        cooldownChecked: readStringList(json['cooldownChecked']).toSet(),
        carryOver: json['carryOver'] is num
            ? readInt(json['carryOver']).clamp(0, 100)
            : null,
        vent: readString(json['vent']),
        improved: readString(json['improved']),
        checkIns: readInt(json['checkIns']),
        flaggedCheckIns: readInt(json['flaggedCheckIns']),
        timerStart: json['timerStart'] is num ? readDate(json['timerStart']) : null,
        timerEnd: json['timerEnd'] is num ? readDate(json['timerEnd']) : null,
        timerMinutes: readInt(json['timerMinutes'], 30),
      );
}
