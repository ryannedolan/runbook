import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/dog.dart';
import '../models/q.dart';
import '../rules/achievement.dart';
import 'feed_items.dart';
import 'widgets/icon_chiclet.dart';

enum CardSize { pinned, feed }

class AchievementCard extends StatelessWidget {
  const AchievementCard({
    super.key,
    required this.item,
    required this.isPinned,
    required this.onTogglePin,
    required this.onOpen,
    required this.onDogTap,
    required this.size,
  });

  final AchievementFeedItem item;
  final bool isPinned;
  final VoidCallback onTogglePin;
  final VoidCallback onOpen;
  final VoidCallback onDogTap;
  final CardSize size;

  @override
  Widget build(BuildContext context) {
    return switch (size) {
      CardSize.pinned => _PinnedAchievementCard(
          item: item, onTogglePin: onTogglePin, onOpen: onOpen),
      CardSize.feed => _feed(context),
    };
  }

  Widget _feed(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = item.result;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TitleChiclet(
                achievement: r.achievement,
                size: 48,
                dimmed: !r.isUnlocked,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          r.achievement.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        if (r.achievement.preferred) ...[
                          const SizedBox(width: 6),
                          const _PreferredBadge(),
                        ],
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: onDogTap,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            child: Text(
                              item.dog.callName,
                              style: TextStyle(
                                color: cs.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                                decorationColor:
                                    cs.primary.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.achievement.description,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _statusLine(context),
                  ],
                ),
              ),
              IconButton(
                tooltip: isPinned ? 'Unpin' : 'Pin',
                icon: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 20,
                  color: isPinned ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
                ),
                onPressed: onTogglePin,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusLine(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = item.result;
    if (r.isUnlocked) {
      final when = r.unlockedAt != null
          ? 'Unlocked ${DateFormat.yMMMd().format(r.unlockedAt!)}'
          : 'Unlocked (count adjusted manually)';
      final impliedSuffix =
          r.impliedBy != null ? ' (implied by ${r.impliedBy} Q)' : '';
      return Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$when$impliedSuffix',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: r.progress,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${r.have} / ${r.need}',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _PinnedAchievementCard extends StatelessWidget {
  const _PinnedAchievementCard({
    required this.item,
    required this.onTogglePin,
    required this.onOpen,
  });
  final AchievementFeedItem item;
  final VoidCallback onTogglePin;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = item.result;
    return GestureDetector(
      onLongPress: onTogglePin,
      onTap: onOpen,
      child: r.isUnlocked
          ? _unlocked(context, cs)
          : _inProgress(context, cs),
    );
  }

  Widget _unlocked(BuildContext context, ColorScheme cs) {
    final r = item.result;
    return Container(
      width: 132,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TitleChiclet(achievement: r.achievement, size: 56),
          const SizedBox(height: 6),
          _TitleAndBadge(
            title: r.achievement.title,
            preferred: r.achievement.preferred,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
          Text(
            item.dog.callName,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _inProgress(BuildContext context, ColorScheme cs) {
    final r = item.result;
    return Container(
      width: 132,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TitleChiclet(achievement: r.achievement, size: 48, dimmed: true),
          const SizedBox(height: 6),
          _TitleAndBadge(
            title: r.achievement.title,
            preferred: r.achievement.preferred,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          Text(
            item.dog.callName,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: r.progress,
              minHeight: 5,
              backgroundColor: cs.surface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${r.have} / ${r.need}',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single Q ribbon — clickable to edit the Q.
class QRibbon extends StatelessWidget {
  const QRibbon({super.key, required this.q, required this.onTap});
  final Q q;
  final VoidCallback onTap;

  String _classLabel() => switch (q.sport) {
        Sport.akcAgility => () {
            final levelLabel =
                q.agilityClass!.isSingleLevel ? '' : '${q.level!.label} ';
            final divLabel = q.preferred ? 'P' : '';
            return '$levelLabel${q.agilityClass!.short}$divLabel';
          }(),
        Sport.fastCAT => 'FastCAT',
        Sport.scentwork => 'SW ${q.scentElement?.short ?? '?'}${q.scentLevel?.short ?? '?'}',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            QRibbonChiclet(q: q, size: 24),
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _classLabel(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    height: 1.1,
                  ),
                ),
                Text(
                  DateFormat.Md().format(q.date),
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of Q ribbons that wraps to multiple lines.
class RibbonRow extends StatelessWidget {
  const RibbonRow({super.key, required this.qs, required this.onTapQ});
  final List<Q> qs;
  final void Function(Q) onTapQ;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final q in qs) QRibbon(q: q, onTap: () => onTapQ(q)),
        ],
      ),
    );
  }
}

/// One trial day for one dog: date header + Q ribbons + optional
/// double-Q badge.
class TrialDayCard extends StatelessWidget {
  const TrialDayCard({
    super.key,
    required this.dog,
    required this.date,
    required this.qs,
    required this.onTapQ,
    this.onOpenDay,
    this.earnedAchievements = const [],
    this.onTapAchievement,
  });
  final Dog dog;
  final DateTime date;
  final List<Q> qs;
  final void Function(Q) onTapQ;

  /// Tapping the date header opens a per-day detail view. Tapping an
  /// individual Q ribbon still goes straight to edit.
  final VoidCallback? onOpenDay;

  /// Achievements unlocked on this day (in any sport). Rendered as a
  /// row of compact "title chips" below the Q ribbons so the feed
  /// doesn't fragment one trial day into a card-per-title.
  final List<AchievementResult> earnedAchievements;
  final void Function(AchievementResult)? onTapAchievement;

  bool get _hasDoubleQ {
    final regularDoubleQ = qs.any((q) =>
            q.level == AgilityLevel.master &&
            !q.preferred &&
            q.agilityClass == AgilityClass.standard) &&
        qs.any((q) =>
            q.level == AgilityLevel.master &&
            !q.preferred &&
            q.agilityClass == AgilityClass.jww);
    final preferredDoubleQ = qs.any((q) =>
            q.level == AgilityLevel.master &&
            q.preferred &&
            q.agilityClass == AgilityClass.standard) &&
        qs.any((q) =>
            q.level == AgilityLevel.master &&
            q.preferred &&
            q.agilityClass == AgilityClass.jww);
    return regularDoubleQ || preferredDoubleQ;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onOpenDay,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(
                      DateFormat('EEE, MMM d').format(date),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${dog.callName} · ${qs.length} Q${qs.length == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    const Spacer(),
                    if (_hasDoubleQ) const _DoubleQBadge(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final q in qs) QRibbon(q: q, onTap: () => onTapQ(q)),
              ],
            ),
            if (earnedAchievements.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in earnedAchievements)
                    _TitleChip(
                      result: a,
                      onTap: onTapAchievement == null
                          ? null
                          : () => onTapAchievement!(a),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact pill rendering an earned title (e.g. "MJP", "MACH3", "PAX2").
/// Used inline within trial-day cards so each new title doesn't get its
/// own feed card.
class _TitleChip extends StatelessWidget {
  const _TitleChip({required this.result, this.onTap});
  final AchievementResult result;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pref = result.achievement.preferred;
    final bg = pref ? const Color(0xFF7B2DB0) : cs.secondaryContainer;
    final fg = pref ? Colors.white : cs.onSecondaryContainer;
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, size: 12, color: fg),
              const SizedBox(width: 4),
              Text(
                result.achievement.title,
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoubleQBadge extends StatelessWidget {
  const _DoubleQBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE6C547),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'DOUBLE-Q',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: Color(0xFF5A3500),
        ),
      ),
    );
  }
}

/// Title text + an optional "PREF" badge laid out in a single row that
/// gracefully shrinks the title with ellipsis instead of overflowing
/// the parent. Pinned cards are width-constrained (~132 px) and titles
/// like "NAC Pref 2027" plus a badge will otherwise blow out the box.
class _TitleAndBadge extends StatelessWidget {
  const _TitleAndBadge({
    required this.title,
    required this.preferred,
    required this.fontSize,
    required this.fontWeight,
    this.letterSpacing,
  });
  final String title;
  final bool preferred;
  final double fontSize;
  final FontWeight fontWeight;
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) {
    final text = Flexible(
      child: Text(
        title,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        text,
        if (preferred) ...[
          const SizedBox(width: 4),
          const _PreferredBadge(),
        ],
      ],
    );
  }
}

/// Small "P" pill marking a Preferred title.
class _PreferredBadge extends StatelessWidget {
  const _PreferredBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF7B2DB0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'PREF',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}


/// A small analytics card — personal best, top-3 average, or trend.
class AnalyticsCard extends StatelessWidget {
  const AnalyticsCard({
    super.key,
    required this.item,
    required this.isPinned,
    required this.onTogglePin,
    required this.onDogTap,
    this.onOpen,
  });

  final AnalyticsFeedItem item;
  final bool isPinned;
  final VoidCallback onTogglePin;
  final VoidCallback onDogTap;
  final VoidCallback? onOpen;

  AnalyticsChicletKind get _chicletKind => switch (item.kind) {
        AnalyticsKind.personalBest => AnalyticsChicletKind.personalBest,
        AnalyticsKind.topAverage => AnalyticsChicletKind.topAverage,
        AnalyticsKind.trend => AnalyticsChicletKind.trend,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: cs.secondaryContainer.withValues(alpha: 0.6),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnalyticsChiclet(kind: _chicletKind, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onDogTap,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          child: Text(
                            item.dog.callName,
                            style: TextStyle(
                              color: cs.primary,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                              decorationColor:
                                  cs.primary.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.value,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                      if (item.unit != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 2, bottom: 2),
                          child: Text(
                            item.unit!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        DateFormat.yMMMd().format(item.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (item.trend != null && item.trend!.length >= 2) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 60,
                      child: _Sparkline(values: item.trend!),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: isPinned ? 'Unpin' : 'Pin',
              icon: Icon(
                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 18,
                color: isPinned ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
              ),
              onPressed: onTogglePin,
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values});
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final spots = <FlSpot>[
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.12;
    return LineChart(
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
            barWidth: 2.0,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                radius: 2.2,
                color: cs.primary,
                strokeWidth: 0,
              ),
            ),
            color: cs.primary,
            belowBarData: BarAreaData(
              show: true,
              color: cs.primary.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple textual tip card (encouragement / reminders).
class TipCard extends StatelessWidget {
  const TipCard({
    super.key,
    required this.tip,
    required this.isPinned,
    required this.onTogglePin,
    this.onMarkCollected,
  });

  final TipFeedItem tip;
  final bool isPinned;
  final VoidCallback onTogglePin;

  /// Called when the user dismisses a ribbon-pickup tip via the "Got it"
  /// button. Only relevant for collectable tips.
  final VoidCallback? onMarkCollected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tip.icon ?? '💡',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tip.body,
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (tip.isCollectable && onMarkCollected != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          minimumSize: const Size(0, 32),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: onMarkCollected,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Got it!'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: isPinned ? 'Unpin' : 'Pin',
              icon: Icon(
                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 18,
              ),
              onPressed: onTogglePin,
            ),
          ],
        ),
      ),
    );
  }
}
