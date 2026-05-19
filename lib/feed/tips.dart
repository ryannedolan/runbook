import '../models/dog.dart';
import '../models/q.dart';
import '../repo/repo.dart';
import '../rules/achievement.dart';
import 'feed_items.dart';

/// Produces feed tips ("Don't forget to pick up your ribbon!",
/// encouragements at close-to-unlock progress, etc) for a dog given
/// their Qs and current achievement results.
List<TipFeedItem> buildTipsForDog({
  required Dog dog,
  required List<Q> qs,
  required List<AchievementResult> results,
  Repo? repo,
}) {
  final out = <TipFeedItem>[];
  final now = DateTime.now();

  // Pickup reminders — one per recently-unlocked title, gated to the
  // last 30 days. Older titles are assumed to already be in hand (or
  // permanently lost) and a reminder for a months-old ribbon is noise.
  //
  // Copy varies with recency: titles earned in the last 3 days assume
  // the trial may still be running ("before you leave the trial!");
  // older but still-fresh titles use the "at your next trial" copy.
  for (final r in results) {
    if (!r.isUnlocked) continue;
    // Phantom unlocks (count adjusted manually, no recorded date) have
    // no specific event to remind about — skip ribbon pickup tips.
    if (r.unlockedAt == null) continue;
    if (r.impliedBy != null) continue; // implied titles don't have ribbons
    final age = now.difference(r.unlockedAt!).inDays;
    if (age > 30) continue;
    if (repo != null && repo.isRibbonCollected(dog.id, r.achievement.id)) {
      continue;
    }
    final atTrial = age <= 3;
    final body = atTrial
        ? 'Pick it up before you leave the trial! '
            '${dog.callName} earned ${r.achievement.title} on ${_md(r.unlockedAt!)}.'
        : 'Pick it up at your next trial. '
            '${dog.callName} earned ${r.achievement.title} on ${_md(r.unlockedAt!)}.';
    out.add(TipFeedItem(
      id: '${dog.id}.pickup.${r.achievement.id}',
      // Place pickup tip slightly after unlock so it sorts immediately
      // above the achievement card in newest-first order.
      timestamp: r.unlockedAt!.add(const Duration(minutes: 1)),
      title: "Don't forget your ${r.achievement.title} ribbon!",
      body: body,
      icon: '🎖️',
      collectableRibbonDogId: dog.id,
      collectableRibbonAchievementId: r.achievement.id,
    ));
  }

  // Encouragements: in-progress with N-1 of N (one Q away). Pick from
  // a pool of variants seeded by the achievement id so the chosen
  // wording is stable across renders but varies across achievements —
  // a feed full of "one more Q" tips reads as a single chorus, not the
  // same line on repeat.
  for (final r in results) {
    if (r.isUnlocked) continue;
    if (r.need - r.have != 1) continue;
    if (r.need <= 0) continue;
    final v = _almostVariantFor(r.achievement.id, dog.callName, r.achievement.title, r.have, r.need);
    out.add(TipFeedItem(
      id: '${dog.id}.almost.${r.achievement.id}',
      timestamp: now,
      title: v.title,
      body: v.body,
      icon: '🔥',
    ));
  }

  return out;
}

/// A title+body pair for the "one more Q" tip.
class _AlmostVariant {
  const _AlmostVariant(this.title, this.body);
  final String title;
  final String body;
}

/// Stable-but-varied picker. Hashes the achievement id (not the dog or
/// the date) so the same title always reads the same way — but two
/// achievements one Q away pick from different lines.
_AlmostVariant _almostVariantFor(
    String achievementId, String dogName, String title, int have, int need) {
  final variants = <_AlmostVariant>[
    _AlmostVariant(
      'One more Q until $title!',
      '$dogName is $have of $need. Next $title Q seals it.',
    ),
    _AlmostVariant(
      '$dogName is one Q from $title.',
      'Stuck at $have of $need — the next qualifying run finishes the title.',
    ),
    _AlmostVariant(
      '$title is within reach.',
      'Just one more Q. $dogName is $have / $need.',
    ),
    _AlmostVariant(
      'Almost there — one Q to go for $title.',
      "$dogName's $have of $need. One clean run away.",
    ),
    _AlmostVariant(
      "Next clean run = $title for $dogName.",
      '$have of $need. The next qualifying run locks it in.',
    ),
    _AlmostVariant(
      'Tantalizingly close to $title.',
      '$dogName is sitting at $have of $need. One more Q does it.',
    ),
  ];
  // Simple stable hash of the id — deterministic per achievement.
  var h = 0;
  for (final code in achievementId.codeUnits) {
    h = (h * 31 + code) & 0x7fffffff;
  }
  return variants[h % variants.length];
}

String _md(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}';
}
