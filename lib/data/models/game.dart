import 'doc.dart';

enum GameLevel {
  a('A-game'),
  b('B-game'),
  c('C-game');

  const GameLevel(this.label);
  final String label;
  String get letter => name.toUpperCase();

  /// How a mistake made at this level is classed.
  String get mistakeLabel => switch (this) {
        a => 'Learning mistake',
        b => 'Marginal mistake',
        c => 'Obvious mistake',
      };

  String get mistakeHint => switch (this) {
        a => 'Something you couldn\'t have known yet',
        b => 'A subtle error you\'re still working out',
        c => 'You knew it was wrong right after',
      };

  static GameLevel? tryParse(Object? name) =>
      values.where((l) => l.name == name).firstOrNull;
}

/// What one level of your game looks like, split into the mental side and
/// the tactical side.
class LevelDescription {
  const LevelDescription({this.mental = '', this.tactical = ''});

  final String mental;
  final String tactical;

  bool get isEmpty => mental.trim().isEmpty && tactical.trim().isEmpty;

  Map<String, Object?> toJson() => {'mental': mental, 'tactical': tactical};

  factory LevelDescription.fromJson(Object? json) {
    final m = json is Map ? json : const {};
    return LevelDescription(
      mental: readString(m['mental']),
      tactical: readString(m['tactical']),
    );
  }
}

/// The A- to C-game analysis. Each edit after the lock period is saved as a
/// new document so the history of how the range was defined is kept.
class GameAnalysis implements Doc {
  GameAnalysis({
    required this.id,
    required this.createdAt,
    DateTime? updatedAt,
    this.version = 1,
    Map<GameLevel, LevelDescription>? levels,
    this.alwaysSolid = '',
    this.sideNotes = '',
  })  : updatedAt = updatedAt ?? createdAt,
        levels = levels ?? const {};

  /// Changes within this window make the sample too small to judge whether
  /// the game really changed, so the app nudges towards side notes instead.
  static const lockPeriod = Duration(days: 30);

  @override
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final Map<GameLevel, LevelDescription> levels;

  /// Strengths that show up even at your worst: the floor under your C-game.
  final String alwaysSolid;
  final String sideNotes;

  LevelDescription level(GameLevel l) =>
      levels[l] ?? const LevelDescription();

  DateTime get lockedUntil => createdAt.add(lockPeriod);

  bool isLocked(DateTime now) => now.isBefore(lockedUntil);

  GameAnalysis copyWith({
    DateTime? updatedAt,
    Map<GameLevel, LevelDescription>? levels,
    String? alwaysSolid,
    String? sideNotes,
  }) =>
      GameAnalysis(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        version: version,
        levels: levels ?? this.levels,
        alwaysSolid: alwaysSolid ?? this.alwaysSolid,
        sideNotes: sideNotes ?? this.sideNotes,
      );

  GameAnalysis nextVersion({required String id, required DateTime now}) =>
      GameAnalysis(
        id: id,
        createdAt: now,
        version: version + 1,
        levels: levels,
        alwaysSolid: alwaysSolid,
        sideNotes: '',
      );

  @override
  Map<String, Object?> toJson() => {
        'id': id,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'version': version,
        'levels': {for (final e in levels.entries) e.key.name: e.value.toJson()},
        'alwaysSolid': alwaysSolid,
        'sideNotes': sideNotes,
      };

  factory GameAnalysis.fromJson(Map<String, Object?> json) {
    final rawLevels = json['levels'];
    return GameAnalysis(
      id: readString(json['id']),
      createdAt: readDate(json['createdAt']),
      updatedAt: readDate(json['updatedAt']),
      version: readInt(json['version'], 1),
      levels: {
        if (rawLevels is Map)
          for (final l in GameLevel.values)
            if (rawLevels[l.name] != null)
              l: LevelDescription.fromJson(rawLevels[l.name]),
      },
      alwaysSolid: readString(json['alwaysSolid']),
      sideNotes: readString(json['sideNotes']),
    );
  }
}

/// One trading session, rated for decision quality rather than PnL.
class TradingSession implements Doc {
  TradingSession({
    required this.id,
    required this.date,
    required this.score,
    this.carryOver = 0,
    this.notes = '',
  });

  static const minScore = 1;
  static const maxScore = 100;

  @override
  final String id;
  final DateTime date;

  /// Decision quality, 1 (worst) to 100 (best).
  final int score;

  /// Leftover emotion from previous sessions at the start of this one, 0–100%.
  final int carryOver;
  final String notes;

  TradingSession copyWith({
    DateTime? date,
    int? score,
    int? carryOver,
    String? notes,
  }) =>
      TradingSession(
        id: id,
        date: date ?? this.date,
        score: score ?? this.score,
        carryOver: carryOver ?? this.carryOver,
        notes: notes ?? this.notes,
      );

  @override
  Map<String, Object?> toJson() => {
        'id': id,
        'date': date.millisecondsSinceEpoch,
        'score': score,
        'carryOver': carryOver,
        'notes': notes,
      };

  factory TradingSession.fromJson(Map<String, Object?> json) => TradingSession(
        id: readString(json['id']),
        date: readDate(json['date']),
        score: readInt(json['score'], 50).clamp(minScore, maxScore),
        carryOver: readInt(json['carryOver']).clamp(0, 100),
        notes: readString(json['notes']),
      );
}
