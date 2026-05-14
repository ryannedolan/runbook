import '../models/dog.dart';
import '../models/q.dart';
import '../rules/achievement.dart';

/// One thing in the feed. Achievements, Q ribbons, and (future) tips
/// all share this interface so the timeline can sort and group them.
sealed class FeedItem {
  String get cardId;
  DateTime get sortTimestamp;
}

class AchievementFeedItem extends FeedItem {
  AchievementFeedItem({required this.dog, required this.result, required this.allQs});
  final Dog dog;
  final AchievementResult result;

  /// Snapshot of the dog's Qs, used to look up the unlocking Q.
  final List<Q> allQs;

  @override
  String get cardId => '${dog.id}::${result.achievement.id}';

  @override
  DateTime get sortTimestamp {
    if (result.unlockedAt != null) return result.unlockedAt!;
    // Use the latest contributing Q for in-progress sort order.
    if (result.contributingQIds.isEmpty) return DateTime.now();
    DateTime latest = DateTime(1900);
    for (final id in result.contributingQIds) {
      for (final q in allQs) {
        if (q.id == id && q.date.isAfter(latest)) latest = q.date;
      }
    }
    return latest == DateTime(1900) ? DateTime.now() : latest;
  }
}

class QFeedItem extends FeedItem {
  QFeedItem({required this.dog, required this.q});
  final Dog dog;
  final Q q;

  @override
  String get cardId => 'q::${q.id}';
  @override
  DateTime get sortTimestamp => q.date;
}

class TipFeedItem extends FeedItem {
  TipFeedItem({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.body,
    this.icon,
  });
  final String id;
  final DateTime timestamp;
  final String title;
  final String body;
  final String? icon;
  @override
  String get cardId => 'tip::$id';
  @override
  DateTime get sortTimestamp => timestamp;
}
