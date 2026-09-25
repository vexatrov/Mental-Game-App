import '../../domain/problem_types.dart';
import 'doc.dart';
import 'game.dart';

/// A note captured while trading, optionally expanded later into a full map
/// of the pattern around a mistake.
class JournalEntry implements Doc {
  JournalEntry({
    required this.id,
    required this.createdAt,
    DateTime? updatedAt,
    this.problem,
    this.subtype,
    this.note = '',
    this.intensity,
    this.mistakeType,
    Map<PatternField, String>? fields,
  })  : updatedAt = updatedAt ?? createdAt,
        fields = fields ?? const {};

  @override
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProblemType? problem;
  final String? subtype;
  final String note;

  /// How intense the emotion was, 1–10. Null when not rated.
  final int? intensity;

  /// Which level of your game the mistake came from, if classified.
  final GameLevel? mistakeType;
  final Map<PatternField, String> fields;

  /// A quick note that hasn't been expanded with any pattern details yet.
  bool get isQuick => fields.values.every((v) => v.trim().isEmpty);

  String get title {
    final firstLine = note.trim().split('\n').first;
    if (firstLine.isNotEmpty) return firstLine;
    final mistake = fields[PatternField.mistake]?.trim() ?? '';
    if (mistake.isNotEmpty) return mistake;
    return problem?.label ?? 'Untitled note';
  }

  JournalEntry copyWith({
    DateTime? updatedAt,
    ProblemType? problem,
    bool clearProblem = false,
    String? subtype,
    bool clearSubtype = false,
    String? note,
    int? intensity,
    bool clearIntensity = false,
    GameLevel? mistakeType,
    bool clearMistakeType = false,
    Map<PatternField, String>? fields,
  }) =>
      JournalEntry(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        problem: clearProblem ? null : problem ?? this.problem,
        subtype: clearSubtype ? null : subtype ?? this.subtype,
        note: note ?? this.note,
        intensity: clearIntensity ? null : intensity ?? this.intensity,
        mistakeType:
            clearMistakeType ? null : mistakeType ?? this.mistakeType,
        fields: fields ?? this.fields,
      );

  @override
  Map<String, Object?> toJson() => {
        'id': id,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'problem': problem?.name,
        'subtype': subtype,
        'note': note,
        'intensity': intensity,
        'mistakeType': mistakeType?.name,
        'fields': {
          for (final e in fields.entries)
            if (e.value.trim().isNotEmpty) e.key.name: e.value,
        },
      };

  factory JournalEntry.fromJson(Map<String, Object?> json) {
    final rawFields = json['fields'];
    return JournalEntry(
      id: readString(json['id']),
      createdAt: readDate(json['createdAt']),
      updatedAt: readDate(json['updatedAt']),
      problem: ProblemType.tryParse(json['problem']),
      subtype: readNullableString(json['subtype']),
      note: readString(json['note']),
      intensity: json['intensity'] is num ? readInt(json['intensity']) : null,
      mistakeType: GameLevel.tryParse(json['mistakeType']),
      fields: {
        if (rawFields is Map)
          for (final e in rawFields.entries)
            ?PatternField.tryParse(e.key): readString(e.value),
      },
    );
  }
}
