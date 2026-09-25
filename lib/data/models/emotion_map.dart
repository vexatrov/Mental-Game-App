import '../../domain/problem_types.dart';
import 'doc.dart';

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
  final Map<int, MapLevel> levels;

  String get name => subtype ?? problem.label;

  int get filledLevels => levels.values.where((l) => !l.isEmpty).length;

  /// Filled levels in ascending order.
  List<MapEntry<int, MapLevel>> get filledEntries =>
      levels.entries.where((e) => !e.value.isEmpty).toList()
        ..sort((a, b) => a.key.compareTo(b.key));

  EmotionMap copyWith({
    DateTime? updatedAt,
    String? subtype,
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
