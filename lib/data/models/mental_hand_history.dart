import '../../domain/problem_types.dart';
import 'doc.dart';

enum MhhStatus {
  draft('Draft'),
  solid('Solid');

  const MhhStatus(this.label);
  final String label;
}

/// Steps 2–5 of a Mental Hand History. A problem can have several reasons,
/// and each one gets its own flaw, correction and justification.
class MhhReason {
  const MhhReason({
    this.why = '',
    this.flaw = '',
    this.correction = '',
    this.whyCorrect = '',
  });

  final String why;
  final String flaw;
  final String correction;
  final String whyCorrect;

  bool get isComplete => [why, flaw, correction]
      .every((s) => s.trim().isNotEmpty);

  MhhReason copyWith({
    String? why,
    String? flaw,
    String? correction,
    String? whyCorrect,
  }) =>
      MhhReason(
        why: why ?? this.why,
        flaw: flaw ?? this.flaw,
        correction: correction ?? this.correction,
        whyCorrect: whyCorrect ?? this.whyCorrect,
      );

  Map<String, Object?> toJson() => {
        'why': why,
        'flaw': flaw,
        'correction': correction,
        'whyCorrect': whyCorrect,
      };

  factory MhhReason.fromJson(Map<String, Object?> json) => MhhReason(
        why: readString(json['why']),
        flaw: readString(json['flaw']),
        correction: readString(json['correction']),
        whyCorrect: readString(json['whyCorrect']),
      );
}

class MentalHandHistory implements Doc {
  MentalHandHistory({
    required this.id,
    required this.createdAt,
    DateTime? updatedAt,
    this.problem,
    this.description = '',
    List<MhhReason>? reasons,
    this.status = MhhStatus.draft,
    this.linkedEntryIds = const [],
    this.logicLine = '',
  })  : updatedAt = updatedAt ?? createdAt,
        reasons = reasons ?? const [MhhReason()];

  @override
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProblemType? problem;

  /// Step 1: the problem, described in detail.
  final String description;
  final List<MhhReason> reasons;
  final MhhStatus status;
  final List<String> linkedEntryIds;

  /// A short line distilled from the correction, said to yourself in the
  /// moment a reaction is triggered.
  final String logicLine;

  String get title {
    final firstLine = description.trim().split('\n').first;
    return firstLine.isEmpty ? 'Untitled hand history' : firstLine;
  }

  /// Number of the five steps with content, counting a step as done only
  /// when every reason has it filled in.
  int get stepsDone {
    var done = description.trim().isNotEmpty ? 1 : 0;
    bool all(String Function(MhhReason) f) =>
        reasons.isNotEmpty && reasons.every((r) => f(r).trim().isNotEmpty);
    if (all((r) => r.why)) done++;
    if (all((r) => r.flaw)) done++;
    if (all((r) => r.correction)) done++;
    if (all((r) => r.whyCorrect)) done++;
    return done;
  }

  MentalHandHistory copyWith({
    DateTime? updatedAt,
    ProblemType? problem,
    bool clearProblem = false,
    String? description,
    List<MhhReason>? reasons,
    MhhStatus? status,
    List<String>? linkedEntryIds,
    String? logicLine,
  }) =>
      MentalHandHistory(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        problem: clearProblem ? null : problem ?? this.problem,
        description: description ?? this.description,
        reasons: reasons ?? this.reasons,
        status: status ?? this.status,
        linkedEntryIds: linkedEntryIds ?? this.linkedEntryIds,
        logicLine: logicLine ?? this.logicLine,
      );

  @override
  Map<String, Object?> toJson() => {
        'id': id,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'problem': problem?.name,
        'description': description,
        'reasons': [for (final r in reasons) r.toJson()],
        'status': status.name,
        'linkedEntryIds': linkedEntryIds,
        'logicLine': logicLine,
      };

  factory MentalHandHistory.fromJson(Map<String, Object?> json) {
    final rawReasons = json['reasons'];
    return MentalHandHistory(
      id: readString(json['id']),
      createdAt: readDate(json['createdAt']),
      updatedAt: readDate(json['updatedAt']),
      problem: ProblemType.tryParse(json['problem']),
      description: readString(json['description']),
      reasons: [
        if (rawReasons is List)
          for (final r in rawReasons.whereType<Map>())
            MhhReason.fromJson(r.cast<String, Object?>()),
      ],
      status: json['status'] == MhhStatus.solid.name
          ? MhhStatus.solid
          : MhhStatus.draft,
      linkedEntryIds: readStringList(json['linkedEntryIds']),
      logicLine: readString(json['logicLine']),
    );
  }
}
