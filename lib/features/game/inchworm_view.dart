import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/app_settings.dart';
import '../../data/models/game.dart';
import '../../data/providers.dart';
import '../../domain/inchworm_stats.dart';
import '../../ui/widgets.dart';

class InchwormView extends ConsumerWidget {
  const InchwormView({super.key});

  static const minSessions = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    return AsyncBody(
      value: sessions,
      builder: (list) {
        if (list.length < minSessions) {
          return EmptyState(
            icon: Icons.timeline,
            title: 'The Inchworm',
            message:
                'Your decisions form a bell curve, from C-game to A-game. You '
                'improve by pushing the front (A-game) forward and pulling the '
                'back (C-game) up. Log at least $minSessions sessions to see '
                'your curve (${list.length} so far).',
          );
        }
        final months = monthlyStats(list, settings);
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            _CurrentRangeCard(months: months),
            const SectionHeader('Your bell curve by month'),
            _ChartCard(
              height: 220,
              child: _DensityChart(months: months, settings: settings),
            ),
            const SectionHeader('Inchworm: back end and front end'),
            _ChartCard(
              height: 220,
              child: _ProgressChart(months: months),
            ),
            const SizedBox(height: 8),
            Text(
              'The back end (10th percentile) is roughly your C-game and the '
              'front end (90th percentile) your A-game. Real progress is both '
              'lines rising while the gap between them shrinks.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: SizedBox(height: height, child: child),
        ),
      );
}

class _CurrentRangeCard extends StatelessWidget {
  const _CurrentRangeCard({required this.months});

  final List<MonthStats> months;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cur = months.last;
    final prev = months.length > 1 ? months[months.length - 2] : null;
    final bands = cur.bandCounts;

    Widget stat(String label, double value, double? previous,
        {bool lowerIsBetter = false}) {
      final delta = previous == null ? null : value - previous;
      final good = delta == null || delta == 0
          ? null
          : (lowerIsBetter ? delta < 0 : delta > 0);
      return Expanded(
        child: Column(
          children: [
            Text(value.toStringAsFixed(0),
                style: theme.textTheme.headlineSmall),
            Text(label, style: theme.textTheme.labelSmall),
            if (delta != null && delta.abs() >= 0.5)
              Builder(builder: (context) {
                final color = good == true
                    ? const Color(0xFF3FAE6A)
                    : const Color(0xFFE0524D);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(delta > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12, color: color),
                    Text(delta.abs().toStringAsFixed(0),
                        style:
                            theme.textTheme.labelSmall?.copyWith(color: color)),
                  ],
                );
              }),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${formatMonth(cur.month)} · ${cur.count} sessions',
                style: theme.textTheme.titleMedium),
            if (prev != null)
              Text('compared with ${formatMonth(prev.month)}',
                  style: theme.textTheme.labelSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                stat('Back end', cur.backend, prev?.backend),
                stat('Average', cur.mean, prev?.mean),
                stat('Front end', cur.frontend, prev?.frontend),
                stat('Range', cur.range, prev?.range, lowerIsBetter: true),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    for (final l in [GameLevel.c, GameLevel.b, GameLevel.a])
                      if (bands[l]! > 0)
                        Expanded(
                          flex: bands[l]!,
                          child: Container(
                              color: bandColor(l, theme.colorScheme)),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'C ${bands[GameLevel.c]} · B ${bands[GameLevel.b]} · A ${bands[GameLevel.a]}',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DensityChart extends StatelessWidget {
  const _DensityChart({required this.months, required this.settings});

  final List<MonthStats> months;
  final AppSettings settings;

  static const maxCurves = 4;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = months.sublist(math.max(0, months.length - maxCurves));
    final curves = [for (final m in shown) m.density()];
    final maxY = curves
        .expand((c) => c.map((p) => p.$2))
        .fold<double>(0, math.max);
    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: maxY * 1.1,
              lineTouchData: const LineTouchData(enabled: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              rangeAnnotations: RangeAnnotations(verticalRangeAnnotations: [
                VerticalRangeAnnotation(
                    x1: 0,
                    x2: settings.cMax.toDouble(),
                    color: bandColor(GameLevel.c, scheme).withValues(alpha: 0.07)),
                VerticalRangeAnnotation(
                    x1: settings.cMax.toDouble(),
                    x2: settings.bMax.toDouble(),
                    color: bandColor(GameLevel.b, scheme).withValues(alpha: 0.07)),
                VerticalRangeAnnotation(
                    x1: settings.bMax.toDouble(),
                    x2: 100,
                    color: bandColor(GameLevel.a, scheme).withValues(alpha: 0.07)),
              ]),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 25,
                    reservedSize: 24,
                    getTitlesWidget: (v, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(v.toInt().toString(),
                            style: const TextStyle(fontSize: 11))),
                  ),
                ),
              ),
              lineBarsData: [
                for (final (i, curve) in curves.indexed)
                  LineChartBarData(
                    spots: [for (final (x, y) in curve) FlSpot(x, y)],
                    isCurved: true,
                    barWidth: i == curves.length - 1 ? 3 : 1.5,
                    color: scheme.primary.withValues(
                        alpha: 0.25 + 0.75 * (i + 1) / curves.length),
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: i == curves.length - 1,
                      color: scheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          children: [
            for (final (i, m) in shown.indexed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 3,
                    color: scheme.primary.withValues(
                        alpha: 0.25 + 0.75 * (i + 1) / shown.length),
                  ),
                  const SizedBox(width: 4),
                  Text(DateFormat.MMM().format(m.month),
                      style: const TextStyle(fontSize: 11)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _ProgressChart extends StatelessWidget {
  const _ProgressChart({required this.months});

  final List<MonthStats> months;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const backColor = Color(0xFFE0524D);
    const frontColor = Color(0xFF3FAE6A);
    LineChartBarData line(double Function(MonthStats) f, Color color,
            {bool dashed = false}) =>
        LineChartBarData(
          spots: [
            for (final (i, m) in months.indexed) FlSpot(i.toDouble(), f(m)),
          ],
          color: color,
          barWidth: dashed ? 1.5 : 3,
          dashArray: dashed ? [4, 4] : null,
          dotData: FlDotData(show: months.length < 12),
        );

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 100,
              minX: 0,
              maxX: math.max(1, months.length - 1).toDouble(),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (_) => FlLine(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                    strokeWidth: 1),
              ),
              lineTouchData: const LineTouchData(enabled: false),
              betweenBarsData: [
                BetweenBarsData(
                    fromIndex: 0,
                    toIndex: 2,
                    color: scheme.primary.withValues(alpha: 0.10)),
              ],
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 25,
                    reservedSize: 30,
                    getTitlesWidget: (v, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(v.toInt().toString(),
                            style: const TextStyle(fontSize: 11))),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 24,
                    getTitlesWidget: (v, meta) {
                      final i = v.round();
                      if (i != v || i < 0 || i >= months.length) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                          meta: meta,
                          child: Text(DateFormat.MMM().format(months[i].month),
                              style: const TextStyle(fontSize: 11)));
                    },
                  ),
                ),
              ),
              lineBarsData: [
                line((m) => m.backend, backColor),
                line((m) => m.mean, scheme.outline, dashed: true),
                line((m) => m.frontend, frontColor),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Wrap(
          spacing: 12,
          children: [
            _Legend(color: backColor, label: 'Back end (C-game)'),
            _Legend(color: Colors.grey, label: 'Average'),
            _Legend(color: frontColor, label: 'Front end (A-game)'),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 14, height: 3, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );
}
