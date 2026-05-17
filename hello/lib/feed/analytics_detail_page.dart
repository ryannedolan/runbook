import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../convo/add_q.dart';
import '../models/q.dart';
import '../repo/repo.dart';
import 'feed_items.dart';
import 'widgets/icon_chiclet.dart';

/// Drill-in view for an analytics card. Shows the headline stat at the
/// top (matching what the feed card displays), the optional sparkline,
/// and a list of contributing Qs below — tap any Q to edit.
class AnalyticsDetailPage extends StatelessWidget {
  const AnalyticsDetailPage({
    super.key,
    required this.repo,
    required this.item,
  });

  final Repo repo;
  final AnalyticsFeedItem item;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final allQs = repo.qsForDog(item.dog.id);
        // Preserve the original contributing-Q order from the analytic
        // (e.g. top-3 fastest renders in fastest-first order).
        final byId = {for (final q in allQs) q.id: q};
        final contributing = <Q>[
          for (final id in item.contributingQIds)
            if (byId[id] != null) byId[id]!,
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(item.title),
            backgroundColor: cs.secondaryContainer.withValues(alpha: 0.6),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _header(context),
              const SizedBox(height: 24),
              if (item.trend != null && item.trend!.length >= 2) ...[
                _sparkline(context),
                const SizedBox(height: 24),
              ],
              _qsHeader(context, contributing.length),
              const SizedBox(height: 8),
              if (contributing.isEmpty)
                Text(
                  'No contributing Qs found.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                )
              else
                for (final q in contributing) _qTile(context, q),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chicletKind = switch (item.kind) {
      AnalyticsKind.personalBest => AnalyticsChicletKind.personalBest,
      AnalyticsKind.topAverage => AnalyticsChicletKind.topAverage,
      AnalyticsKind.trend => AnalyticsChicletKind.trend,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnalyticsChiclet(kind: chicletKind, size: 80),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style:
                        TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.value,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                      if (item.unit != null)
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 4, bottom: 4),
                          child: Text(
                            item.unit!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'as of ${DateFormat.yMMMd().format(item.timestamp)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sparkline(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final values = item.trend!;
    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trend (${values.length} runs, oldest → newest)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              minY: minY - pad,
              maxY: maxY + pad,
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.2,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  color: cs.primary,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                      radius: 3,
                      color: cs.primary,
                      strokeWidth: 0,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: cs.primary.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _qsHeader(BuildContext context, int count) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      'Contributing Qs ($count)',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant,
      ),
    );
  }

  Widget _qTile(BuildContext context, Q q) {
    final cs = Theme.of(context).colorScheme;
    final timeStr =
        q.timeSeconds != null ? '${q.timeSeconds!.toStringAsFixed(2)}s' : null;
    final ypsStr = q.yps != null ? '${q.yps!.toStringAsFixed(2)} YPS' : null;
    final extras = [
      ?timeStr,
      ?ypsStr,
      if (q.machPoints > 0) '${q.machPoints} pts',
    ].join(' • ');
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddQPage(repo: repo, editing: q),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              QRibbonChiclet(q: q, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.yMMMd().format(q.date),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (extras.isNotEmpty)
                      Text(
                        extras,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
