import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/q.dart';
import 'feed_items.dart';
import 'widgets/pixel_icons.dart';

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
              SizedBox(
                width: 56,
                child: Center(
                  child: PixelRosette(
                    achievement: r.achievement,
                    scale: 3,
                    dimmed: !r.isUnlocked,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
      final when = DateFormat.yMMMd().format(r.unlockedAt!);
      final impliedSuffix = r.impliedBy != null
          ? ' (implied by ${r.impliedBy!.label} Q)'
          : '';
      return Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Unlocked $when$impliedSuffix',
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
          PixelRosette(achievement: r.achievement, scale: 4),
          const SizedBox(height: 4),
          Text(
            r.achievement.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
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
          PixelRosette(achievement: r.achievement, scale: 3, dimmed: true),
          const SizedBox(height: 4),
          Text(
            r.achievement.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final levelLabel = q.agilityClass.isPremier ? '' : '${q.level.label} ';
    final divLabel = q.preferred ? 'P' : '';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelQRibbonPair(q: q, scale: 2),
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$levelLabel${q.agilityClass.short}$divLabel',
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

/// A simple textual tip card (encouragement / reminders).
class TipCard extends StatelessWidget {
  const TipCard({
    super.key,
    required this.tip,
    required this.isPinned,
    required this.onTogglePin,
  });

  final TipFeedItem tip;
  final bool isPinned;
  final VoidCallback onTogglePin;

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
