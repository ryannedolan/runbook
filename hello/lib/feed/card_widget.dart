import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/dog.dart';
import '../models/q.dart';
import '../rules/achievement.dart';

/// A feed item — one achievement evaluated for one dog. The [cardId] is
/// stable across runs, used for pin state.
class FeedItem {
  FeedItem({
    required this.dog,
    required this.result,
  });

  final Dog dog;
  final AchievementResult result;

  String get cardId => '${dog.id}::${result.achievement.id}';

  /// Timestamp for ordering: unlock date if unlocked, else "now" (newest
  /// progress floats to top until earned).
  DateTime get sortTimestamp => result.unlockedAt ?? DateTime.now();
}

/// Renders an achievement card. Three sizes: pinned (compact chip),
/// feed (medium card), expanded (full screen — not yet wired).
enum CardSize { pinned, feed }

class AchievementCard extends StatelessWidget {
  const AchievementCard({
    super.key,
    required this.item,
    required this.isPinned,
    required this.onTogglePin,
    required this.size,
  });

  final FeedItem item;
  final bool isPinned;
  final VoidCallback onTogglePin;
  final CardSize size;

  @override
  Widget build(BuildContext context) {
    return switch (size) {
      CardSize.pinned => _pinned(context),
      CardSize.feed => _feed(context),
    };
  }

  Widget _pinned(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = item.result;
    final color = r.isUnlocked ? cs.primary : cs.surfaceContainerHighest;
    final fg = r.isUnlocked ? cs.onPrimary : cs.onSurface;
    return GestureDetector(
      onLongPress: onTogglePin,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              r.isUnlocked ? Icons.emoji_events : Icons.hourglass_bottom,
              size: 18,
              color: fg,
            ),
            const SizedBox(width: 6),
            Text(
              r.achievement.title,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Text(
              item.dog.callName,
              style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feed(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = item.result;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: InkWell(
        onTap: () => _showExpanded(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: r.isUnlocked
                      ? cs.primary
                      : cs.surfaceContainerHighest,
                ),
                child: Icon(
                  r.isUnlocked
                      ? Icons.emoji_events
                      : Icons.hourglass_bottom,
                  color: r.isUnlocked ? cs.onPrimary : cs.onSurface,
                  size: 22,
                ),
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
                        const SizedBox(width: 8),
                        Text(
                          item.dog.callName,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
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
                  color:
                      isPinned ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
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

  void _showExpanded(BuildContext context) {
    final r = item.result;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.achievement.title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.dog.callName} • ${r.achievement.sport}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(r.achievement.description),
              const SizedBox(height: 16),
              if (r.isUnlocked)
                _kv(
                  'Unlocked',
                  '${DateFormat.yMMMd().format(r.unlockedAt!)}'
                      '${r.impliedBy != null ? '\n(implied by a ${r.impliedBy!.label} Q)' : ''}',
                )
              else
                _kv('Progress', '${r.have} of ${r.need}'),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    onTogglePin();
                    Navigator.pop(ctx);
                  },
                  icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                  label: Text(isPinned ? 'Unpin' : 'Pin to top'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(v),
        ],
      ),
    );
  }
}

/// A "Recent Q" feed item — shown alongside achievement cards for
/// historical context.
class RecentQItem {
  RecentQItem({required this.dog, required this.q});
  final Dog dog;
  final Q q;
  String get cardId => 'q::${q.id}';
  DateTime get sortTimestamp => q.date;
}

class RecentQCard extends StatelessWidget {
  const RecentQCard({
    super.key,
    required this.item,
    required this.onDelete,
  });

  final RecentQItem item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = item.q;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.flag_outlined, color: cs.onSurfaceVariant, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${q.level.label} ${q.agilityClass.short} Q • ${item.dog.callName}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    DateFormat.yMMMd().format(q.date),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
