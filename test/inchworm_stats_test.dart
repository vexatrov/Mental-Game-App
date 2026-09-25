import 'package:flutter_test/flutter_test.dart';
import 'package:mental_game/data/models/app_settings.dart';
import 'package:mental_game/data/models/game.dart';
import 'package:mental_game/domain/inchworm_stats.dart';

void main() {
  const settings = AppSettings(cMax: 40, bMax: 70);
  var n = 0;
  TradingSession s(int month, int day, int score) => TradingSession(
      id: '${n++}', date: DateTime(2026, month, day), score: score);

  test('groups sessions by month, oldest first', () {
    final months = monthlyStats(
        [s(2, 3, 60), s(1, 5, 30), s(2, 1, 80), s(1, 9, 50)], settings);
    expect(months.map((m) => m.month), [DateTime(2026, 1), DateTime(2026, 2)]);
    expect(months.first.scores, [30, 50]);
    expect(months.last.mean, 70);
  });

  test('percentiles interpolate and describe the range', () {
    final m = MonthStats(
      month: DateTime(2026, 1),
      scores: [for (var i = 1; i <= 11; i++) i * 5], // 5..55
      settings: settings,
    );
    expect(m.backend, 10);
    expect(m.frontend, 50);
    expect(m.range, 40);
    expect(m.percentile(0.5), 30);
  });

  test('a single session has zero spread', () {
    final m = MonthStats(
        month: DateTime(2026, 1), scores: [42], settings: settings);
    expect(m.stdDev, 0);
    expect(m.backend, 42);
    expect(m.frontend, 42);
  });

  test('band counts use the settings thresholds', () {
    final m = MonthStats(
        month: DateTime(2026, 1),
        scores: [10, 40, 41, 70, 71, 99],
        settings: settings);
    expect(m.bandCounts, {GameLevel.a: 2, GameLevel.b: 2, GameLevel.c: 2});
  });

  test('density integrates to about 1 and peaks near the scores', () {
    final m = MonthStats(
        month: DateTime(2026, 1),
        scores: [48, 50, 50, 52, 55],
        settings: settings);
    final curve = m.density(step: 1);
    final area = curve.fold<double>(0, (a, p) => a + p.$2);
    expect(area, closeTo(1, 0.02));
    final peak = curve.reduce((a, b) => a.$2 >= b.$2 ? a : b);
    expect(peak.$1, inInclusiveRange(46, 56));
  });
}
