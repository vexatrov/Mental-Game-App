import '../../domain/routine.dart';
import 'doc.dart';
import 'game.dart';

/// What the Strategic Reminder lists: the technical side to protect once
/// emotion has hit your decision-making.
enum ReminderKind {
  commonMistakes('My most common mistakes',
      'e.g. Chasing after a missed entry\nMoving my stop to breakeven too early'),
  decisionProcess('My full decision process',
      'e.g. 1. Higher timeframe trend\n2. Level + confirmation\n3. Size from stop distance'),
  missedFactors('What I stop considering',
      'e.g. Where the higher timeframe level is\nWhether volume confirms');

  const ReminderKind(this.label, this.hint);
  final String label;
  final String hint;

  static ReminderKind parse(Object? name) =>
      values.firstWhere((k) => k.name == name, orElse: () => commonMistakes);
}

/// User preferences, stored as a single document.
class AppSettings implements Doc {
  const AppSettings({
    this.cMax = 40,
    this.bMax = 70,
    this.checkInMinutes = 30,
    this.sessionHours = 4,
    this.customWarmup = const [],
    this.customCooldown = const [],
    this.reminderKind = ReminderKind.commonMistakes,
    this.reminderText = '',
  });

  static const docId = 'settings';
  static const checkInChoices = [15, 30, 60];

  /// Scores up to [cMax] are C-game.
  final int cMax;

  /// Scores above [cMax] and up to [bMax] are B-game; above is A-game.
  final int bMax;

  /// Minutes between check-in reminders.
  final int checkInMinutes;

  /// How long the check-in timer runs once started.
  final int sessionHours;

  final List<RoutineItem> customWarmup;
  final List<RoutineItem> customCooldown;

  /// The Strategic Reminder shown at the end of a reset.
  final ReminderKind reminderKind;
  final String reminderText;

  @override
  String get id => docId;

  GameLevel bandFor(int score) {
    if (score <= cMax) return GameLevel.c;
    if (score <= bMax) return GameLevel.b;
    return GameLevel.a;
  }

  List<RoutineItem> customItems(RoutinePhase phase) =>
      phase == RoutinePhase.warmup ? customWarmup : customCooldown;

  List<RoutineItem> routineItems(RoutinePhase phase) =>
      [...builtInItems(phase), ...customItems(phase)];

  AppSettings copyWith({
    int? cMax,
    int? bMax,
    int? checkInMinutes,
    int? sessionHours,
    List<RoutineItem>? customWarmup,
    List<RoutineItem>? customCooldown,
    ReminderKind? reminderKind,
    String? reminderText,
  }) =>
      AppSettings(
        cMax: cMax ?? this.cMax,
        bMax: bMax ?? this.bMax,
        checkInMinutes: checkInMinutes ?? this.checkInMinutes,
        sessionHours: sessionHours ?? this.sessionHours,
        customWarmup: customWarmup ?? this.customWarmup,
        customCooldown: customCooldown ?? this.customCooldown,
        reminderKind: reminderKind ?? this.reminderKind,
        reminderText: reminderText ?? this.reminderText,
      );

  AppSettings withCustomItems(RoutinePhase phase, List<RoutineItem> items) =>
      phase == RoutinePhase.warmup
          ? copyWith(customWarmup: items)
          : copyWith(customCooldown: items);

  @override
  Map<String, Object?> toJson() => {
        'id': id,
        'cMax': cMax,
        'bMax': bMax,
        'checkInMinutes': checkInMinutes,
        'sessionHours': sessionHours,
        'customWarmup': [for (final i in customWarmup) i.toJson()],
        'customCooldown': [for (final i in customCooldown) i.toJson()],
        'reminderKind': reminderKind.name,
        'reminderText': reminderText,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final cMax = readInt(json['cMax'], 40).clamp(1, 98);
    final bMax = readInt(json['bMax'], 70).clamp(cMax + 1, 99);
    List<RoutineItem> items(Object? raw) => [
          if (raw is List)
            for (final r in raw) ?RoutineItem.fromJson(r),
        ];
    return AppSettings(
      cMax: cMax,
      bMax: bMax,
      checkInMinutes: readInt(json['checkInMinutes'], 30).clamp(5, 120),
      sessionHours: readInt(json['sessionHours'], 4).clamp(1, 24),
      customWarmup: items(json['customWarmup']),
      customCooldown: items(json['customCooldown']),
      reminderKind: ReminderKind.parse(json['reminderKind']),
      reminderText: readString(json['reminderText']),
    );
  }
}
