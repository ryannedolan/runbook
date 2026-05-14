import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/q.dart';
import '../rules/achievement.dart';
import 'feed_items.dart';

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
              _trophy(context, r),
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

  Widget _trophy(BuildContext context, AchievementResult r) {
    final cs = Theme.of(context).colorScheme;
    if (r.isUnlocked) {
      return Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFD86A), Color(0xFFE3A100)],
          ),
        ),
        child: const Icon(Icons.emoji_events, color: Colors.white, size: 24),
      );
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.surfaceContainerHighest,
      ),
      child: Icon(Icons.hourglass_bottom, color: cs.onSurface, size: 22),
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
    // Strong gold visual once earned.
    return Container(
      width: 116,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE9A8), Color(0xFFFFC861)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE3A100).withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.emoji_events, size: 18, color: Color(0xFF7B4D00)),
              Text(
                item.dog.callName,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF7B4D00),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            r.achievement.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF5A3500),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inProgress(BuildContext context, ColorScheme cs) {
    final r = item.result;
    return Container(
      width: 130,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_bottom, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.dog.callName,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            r.achievement.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF8EC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFB7DFB9)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎀', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              '$levelLabel${q.agilityClass.short}$divLabel',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              DateFormat.Md().format(q.date),
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
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
