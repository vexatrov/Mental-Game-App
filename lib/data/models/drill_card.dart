import 'doc.dart';

/// Recall practice for one hand history's correction line, scheduled with
/// a simple Leitner box: remembered lines come back less often.
class DrillCard implements Doc {
  const DrillCard({
    required this.id,
    this.box = 1,
    this.lastReviewed,
    this.attempts = 0,
    this.nailed = 0,
  });

  static const maxBox = 5;

  /// Days to wait before a card in each box is due again.
  static const _intervals = {1: 0, 2: 1, 3: 3, 4: 7, 5: 14};

  /// The hand history this card drills.
  @override
  final String id;
  final int box;
  final DateTime? lastReviewed;
  final int attempts;
  final int nailed;

  bool isDue(DateTime now) {
    final last = lastReviewed;
    if (last == null) return true;
    final lastDay = DateTime(last.year, last.month, last.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(lastDay).inDays >= _intervals[box]!;
  }

  DrillCard graded(DrillGrade grade, DateTime now) => DrillCard(
        id: id,
        box: switch (grade) {
          DrillGrade.nailed => (box + 1).clamp(1, maxBox),
          DrillGrade.close => box,
          DrillGrade.missed => 1,
        },
        lastReviewed: now,
        attempts: attempts + 1,
        nailed: nailed + (grade == DrillGrade.nailed ? 1 : 0),
      );

  @override
  Map<String, Object?> toJson() => {
        'id': id,
        'box': box,
        'lastReviewed': lastReviewed?.millisecondsSinceEpoch,
        'attempts': attempts,
        'nailed': nailed,
      };

  factory DrillCard.fromJson(Map<String, Object?> json) => DrillCard(
        id: readString(json['id']),
        box: readInt(json['box'], 1).clamp(1, maxBox),
        lastReviewed:
            json['lastReviewed'] is num ? readDate(json['lastReviewed']) : null,
        attempts: readInt(json['attempts']),
        nailed: readInt(json['nailed']),
      );
}

enum DrillGrade {
  missed('Missed'),
  close('Close'),
  nailed('Nailed it');

  const DrillGrade(this.label);
  final String label;
}
