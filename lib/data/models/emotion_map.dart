import 'package:flutter/painting.dart';

import '../../domain/problem_types.dart';
import 'doc.dart';

/// How the 1–10 levels of a map are read.
enum MapScale {
  /// 1 is the first small sign, 10 is out of control (greed, fear, tilt).
  worstAtTen('1 = first sign · 10 = out of control'),

  /// 10 is optimal, 1 is the worst it gets (discipline).
  bestAtTen('10 = optimal · 1 = worst'),

  /// 5 is ideal, 1–4 is too low and 6–10 too high (confidence).
  idealAtFive('5 = ideal · 1–4 too low · 6–10 too high');

  const MapScale(this.label);
  final String label;

  static const _calm = Color(0xFF3FAE6A);
  static const _warn = Color(0xFFF2A516);
  static const _hot = Color(0xFFE0524D);
  static const _low = Color(0xFF6B7FD7);

  static MapScale defaultFor(ProblemType p) => switch (p) {
        ProblemType.confidence => idealAtFive,
        ProblemType.discipline => bestAtTen,
        _ => worstAtTen,
      };

  static MapScale parse(Object? name) =>
      values.firstWhere((s) => s.name == name, orElse: () => worstAtTen);

  /// Levels top to bottom as they should be listed: the ideal or earliest
  /// level where you read first.
  List<int> get displayOrder => switch (this) {
        worstAtTen => [for (var l = 1; l <= 10; l++) l],
        bestAtTen || idealAtFive => [for (var l = 10; l >= 1; l--) l],
      };

  /// Short tag for the notable levels, e.g. "Ideal" on 5 for confidence.
  String? tagFor(int level) => switch ((this, level)) {
        (worstAtTen, 1) => 'First sign',
        (worstAtTen, 10) => 'Out of control',
        (bestAtTen, 10) => 'Optimal',
        (bestAtTen, 1) => 'Worst',
        (idealAtFive, 5) => 'Ideal',
        (idealAtFive, 10) => 'Most overconfident',
        (idealAtFive, 1) => 'Lowest',
        _ => null,
      };

  /// How far a level is from ideal, 0 (ideal) to 1 (worst).
  double severity(int level) => switch (this) {
        worstAtTen => (level - 1) / 9,
        bestAtTen => (10 - level) / 9,
        idealAtFive => (level - 5).abs() / 5,
      };

  Color color(int level) {
    final t = severity(level).clamp(0.0, 1.0);
    if (this == idealAtFive && level < 5) return Color.lerp(_calm, _low, t)!;
    return t < 0.5
        ? Color.lerp(_calm, _warn, t * 2)!
        : Color.lerp(_warn, _hot, (t - 0.5) * 2)!;
  }
}

/// One row of an emotion map: what the level looks like mentally and
/// emotionally, side by side with how decision-making degrades.
class MapLevel {
  const MapLevel({this.mental = '', this.technical = ''});

  final String mental;
  final String technical;

  bool get isEmpty => mental.trim().isEmpty && technical.trim().isEmpty;

  Map<String, Object?> toJson() => {'mental': mental, 'technical': technical};

  factory MapLevel.fromJson(Map<String, Object?> json) => MapLevel(
        mental: readString(json['mental']),
        technical: readString(json['technical']),
      );
}

/// A 1–10 severity map for one problem. Revisions are stored as separate
/// documents sharing a [seriesId], so earlier versions stay readable.
class EmotionMap implements Doc {
  EmotionMap({
    required this.id,
    required this.seriesId,
    required this.createdAt,
    DateTime? updatedAt,
    required this.problem,
    this.subtype,
    this.version = 1,
    this.scale = MapScale.worstAtTen,
    this.ideal = '',
    Map<int, MapLevel>? levels,
  })  : updatedAt = updatedAt ?? createdAt,
        levels = levels ?? const {};

  static const minLevels = 3;
  static const maxLevel = 10;

  @override
  final String id;
  final String seriesId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProblemType problem;
  final String? subtype;
  final int version;
  final MapScale scale;

  /// What this area looks like when it's at its best.
  final String ideal;
  final Map<int, MapLevel> levels;

  String get name => subtype ?? problem.label;

  int get filledLevels => levels.values.where((l) => !l.isEmpty).length;

  /// Filled levels in the scale's reading order.
  List<MapEntry<int, MapLevel>> get filledEntries => [
        for (final level in scale.displayOrder)
          if (levels[level] case final l? when !l.isEmpty) MapEntry(level, l),
      ];

  EmotionMap copyWith({
    DateTime? updatedAt,
    String? subtype,
    MapScale? scale,
    String? ideal,
    Map<int, MapLevel>? levels,
  }) =>
      EmotionMap(
        id: id,
        seriesId: seriesId,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        problem: problem,
        subtype: subtype ?? this.subtype,
        version: version,
        scale: scale ?? this.scale,
        ideal: ideal ?? this.ideal,
        levels: levels ?? this.levels,
      );

  /// A new version in the same series, starting from this one's content.
  EmotionMap nextVersion({required String id, required DateTime now}) =>
      EmotionMap(
        id: id,
        seriesId: seriesId,
        createdAt: now,
        problem: problem,
        subtype: subtype,
        version: version + 1,
        scale: scale,
        ideal: ideal,
        levels: levels,
      );

  @override
  Map<String, Object?> toJson() => {
        'id': id,
        'seriesId': seriesId,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'problem': problem.name,
        'subtype': subtype,
        'version': version,
        'scale': scale.name,
        'ideal': ideal,
        'levels': {
          for (final e in levels.entries)
            if (!e.value.isEmpty) '${e.key}': e.value.toJson(),
        },
      };

  factory EmotionMap.fromJson(Map<String, Object?> json) {
    final rawLevels = json['levels'];
    return EmotionMap(
      id: readString(json['id']),
      seriesId: readString(json['seriesId']),
      createdAt: readDate(json['createdAt']),
      updatedAt: readDate(json['updatedAt']),
      problem: ProblemType.tryParse(json['problem']) ?? ProblemType.greed,
      subtype: readNullableString(json['subtype']),
      version: readInt(json['version'], 1),
      // Maps from before scales existed were all read 1 = first sign.
      scale: MapScale.parse(json['scale']),
      ideal: readString(json['ideal']),
      levels: {
        if (rawLevels is Map)
          for (final e in rawLevels.entries)
            if (int.tryParse('${e.key}') case final level?
                when level >= 1 && level <= maxLevel && e.value is Map)
              level: MapLevel.fromJson((e.value as Map).cast()),
      },
    );
  }
}
