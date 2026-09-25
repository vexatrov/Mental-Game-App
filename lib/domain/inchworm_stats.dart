import 'dart:math' as math;

import '../data/models/app_settings.dart';
import '../data/models/game.dart';

/// Summary of one month's decision-quality scores: the snapshot of the bell
/// curve at that point in time.
class MonthStats {
  MonthStats({
    required this.month,
    required this.scores,
    required this.settings,
  }) : assert(scores.isNotEmpty) {
    scores.sort();
  }

  /// First day of the month.
  final DateTime month;
  final List<int> scores;
  final AppSettings settings;

  int get count => scores.length;

  double get mean => scores.reduce((a, b) => a + b) / count;

  double get stdDev {
    if (count < 2) return 0;
    final m = mean;
    final sq = scores.fold<double>(0, (s, x) => s + (x - m) * (x - m));
    return math.sqrt(sq / (count - 1));
  }

  /// The back end of the inchworm: roughly where your C-game sits.
  double get backend => percentile(0.10);

  /// The front end of the inchworm: roughly where your A-game peaks.
  double get frontend => percentile(0.90);

  double get range => frontend - backend;

  double percentile(double p) {
    if (count == 1) return scores.first.toDouble();
    final pos = p * (count - 1);
    final lo = pos.floor();
    final hi = pos.ceil();
    return scores[lo] + (scores[hi] - scores[lo]) * (pos - lo);
  }

  Map<GameLevel, int> get bandCounts {
    final counts = {for (final l in GameLevel.values) l: 0};
    for (final s in scores) {
      final band = settings.bandFor(s);
      counts[band] = counts[band]! + 1;
    }
    return counts;
  }

  /// Gaussian kernel density estimate over 0–100, sampled every [step].
  /// Values are scaled so the curve integrates to 1.
  List<(double x, double y)> density({double step = 2}) {
    final sd = stdDev;
    // Silverman's rule of thumb, with a floor so tiny samples still plot.
    final h = math.max(4.0, 1.06 * (sd == 0 ? 10 : sd) * math.pow(count, -0.2));
    final norm = 1 / (count * h * math.sqrt(2 * math.pi));
    return [
      for (var x = 0.0; x <= 100; x += step)
        (
          x,
          norm *
              scores.fold<double>(0, (s, xi) {
                final u = (x - xi) / h;
                return s + math.exp(-0.5 * u * u);
              }),
        ),
    ];
  }
}

/// Groups sessions by calendar month, oldest first.
List<MonthStats> monthlyStats(
  List<TradingSession> sessions,
  AppSettings settings,
) {
  final byMonth = <DateTime, List<int>>{};
  for (final s in sessions) {
    final key = DateTime(s.date.year, s.date.month);
    (byMonth[key] ??= []).add(s.score);
  }
  final months = byMonth.keys.toList()..sort();
  return [
    for (final m in months)
      MonthStats(month: m, scores: byMonth[m]!, settings: settings),
  ];
}
