import 'doc.dart';
import 'game.dart';

/// User preferences, stored as a single document.
class AppSettings implements Doc {
  const AppSettings({this.cMax = 40, this.bMax = 70});

  static const docId = 'settings';

  /// Scores up to [cMax] are C-game.
  final int cMax;

  /// Scores above [cMax] and up to [bMax] are B-game; above is A-game.
  final int bMax;

  @override
  String get id => docId;

  GameLevel bandFor(int score) {
    if (score <= cMax) return GameLevel.c;
    if (score <= bMax) return GameLevel.b;
    return GameLevel.a;
  }

  AppSettings copyWith({int? cMax, int? bMax}) =>
      AppSettings(cMax: cMax ?? this.cMax, bMax: bMax ?? this.bMax);

  @override
  Map<String, Object?> toJson() => {'id': id, 'cMax': cMax, 'bMax': bMax};

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final cMax = readInt(json['cMax'], 40).clamp(1, 98);
    final bMax = readInt(json['bMax'], 70).clamp(cMax + 1, 99);
    return AppSettings(cMax: cMax, bMax: bMax);
  }
}
