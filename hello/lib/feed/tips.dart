import '../models/dog.dart';
import '../models/q.dart';
import '../rules/achievement.dart';
import 'feed_items.dart';

/// Produces feed tips ("Don't forget to pick up your ribbon!",
/// encouragements at close-to-unlock progress, etc) for a dog given
/// their Qs and current achievement results.
List<TipFeedItem> buildTipsForDog({
  required Dog dog,
  required List<Q> qs,
  required List<AchievementResult> results,
}) {
  final out = <TipFeedItem>[];

  // Pickup reminders — one per recently-unlocked title.
  for (final r in results) {
    if (!r.isUnlocked) continue;
    if (r.impliedBy != null) continue; // implied titles don't have ribbons
    out.add(TipFeedItem(
      id: '${dog.id}.pickup.${r.achievement.id}',
      // Place pickup tip slightly after unlock so it sorts immediately
      // above the achievement card in newest-first order.
      timestamp: r.unlockedAt!.add(const Duration(minutes: 1)),
      title: "Don't forget your ${r.achievement.title} ribbon!",
      body:
          'Pick it up at your next trial. ${dog.callName} earned ${r.achievement.title} on ${_md(r.unlockedAt!)}.',
      icon: '🎖️',
    ));
  }

  // Encouragements: in-progress with N-1 of N (one Q away).
  for (final r in results) {
    if (r.isUnlocked) continue;
    if (r.need - r.have != 1) continue;
    if (r.need <= 0) continue;
    final now = DateTime.now();
    out.add(TipFeedItem(
      id: '${dog.id}.almost.${r.achievement.id}',
      timestamp: now,
      title: 'One more Q until ${r.achievement.title}!',
      body:
          '${dog.callName} is ${r.have} of ${r.need}. Next ${r.achievement.title} Q seals it.',
      icon: '🔥',
    ));
  }

  return out;
}

String _md(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}';
}
