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

/// Derived analytics — personal bests, top-3 averages, recent-run trends.
/// Only emitted when enough Qs exist to make the stat meaningful.
class AnalyticsFeedItem extends FeedItem {
  AnalyticsFeedItem({
    required this.id,
    required this.dog,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.timestamp,
    this.unit,
    this.trend,
    this.contributingQIds = const [],
  });

  final String id;
  final Dog dog;
  final AnalyticsKind kind;
  final String title;
  final String subtitle;

  /// Formatted display value (e.g. "41.2", "3.85").
  final String value;
  final String? unit;
  final DateTime timestamp;

  /// Optional series for a sparkline (chronological).
  final List<double>? trend;

  /// Which Qs this stat is built from, for drill-down later.
  final List<String> contributingQIds;

  @override
  String get cardId => 'analytics::$id';
  @override
  DateTime get sortTimestamp => timestamp;
}

enum AnalyticsKind { personalBest, topAverage, trend }

class TipFeedItem extends FeedItem {
  TipFeedItem({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.body,
    this.icon,
    this.collectableRibbonDogId,
    this.collectableRibbonAchievementId,
  });
  final String id;
  final DateTime timestamp;
  final String title;
  final String body;
  final String? icon;

  /// If non-null, this tip is a "don't forget your ribbon" reminder and
  /// can be dismissed by marking it collected via Repo.markRibbonCollected.
  final String? collectableRibbonDogId;
  final String? collectableRibbonAchievementId;

  bool get isCollectable =>
      collectableRibbonDogId != null && collectableRibbonAchievementId != null;

  @override
  String get cardId => 'tip::$id';
  @override
  DateTime get sortTimestamp => timestamp;
}
