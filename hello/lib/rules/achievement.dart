import '../models/q.dart';

/// Result of evaluating an achievement against a dog's Qs.
class AchievementResult {
  AchievementResult({
    required this.achievement,
    required this.have,
    required this.need,
    this.unlockedAt,
    this.unlockedByQId,
    this.impliedBy,
  });

  final Achievement achievement;
  final int have;
  final int need;

  /// Computed timestamp at which the achievement was unlocked. Anchored to
  /// the Q that pushed it over.
  final DateTime? unlockedAt;

  /// Id of the Q that unlocked this achievement (the Nth qualifying Q, or
  /// the higher-level Q that implied it).
  final String? unlockedByQId;

  /// If unlocked by implication (a higher-level Q implies all prior-level
  /// titles), this is the level of the implying Q. Null if unlocked
  /// directly.
  final AgilityLevel? impliedBy;

  bool get isUnlocked => unlockedAt != null;
  bool get hasProgress => have > 0 || isUnlocked;
  double get progress => need <= 0 ? 1.0 : (have / need).clamp(0.0, 1.0);

  AchievementResult.inProgress({
    required this.achievement,
    required this.have,
    required this.need,
  })  : unlockedAt = null,
        unlockedByQId = null,
        impliedBy = null;
}

abstract class Achievement {
  String get id;
  String get title;
  String get description;
  String get sport;
  AchievementResult evaluate(List<Q> qs);
}

/// A title earned by accumulating N Qs of a given class+level.
///
/// AKC titling is strictly progressive — to compete at Excellent level you
/// must already hold the Open title, etc. So a Q at a higher level
/// *implies* every lower-level title in the same class has already been
/// earned, even if we don't have those Qs stored. In that case we
/// timestamp the implied title from the first higher-level Q.
class LevelQCountTitle extends Achievement {
  LevelQCountTitle({
    required this.id,
    required this.title,
    required this.description,
    required this.agilityClass,
    required this.level,
    required this.qCountNeeded,
  });

  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  String get sport => 'AKC Agility';

  final AgilityClass agilityClass;
  final AgilityLevel level;
  final int qCountNeeded;

  @override
  AchievementResult evaluate(List<Q> qs) {
    final direct = qs
        .where((q) => q.agilityClass == agilityClass && q.level == level)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (direct.length >= qCountNeeded) {
      final unlockingQ = direct[qCountNeeded - 1];
      return AchievementResult(
        achievement: this,
        have: direct.length,
        need: qCountNeeded,
        unlockedAt: unlockingQ.date,
        unlockedByQId: unlockingQ.id,
      );
    }

    // Implication: any Q at a higher level in the same class means this
    // title is already earned (AKC progression rules).
    final higher = qs
        .where((q) =>
            q.agilityClass == agilityClass && q.level.rank > level.rank)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (higher.isNotEmpty) {
      final q = higher.first;
      return AchievementResult(
        achievement: this,
        have: direct.length,
        need: qCountNeeded,
        unlockedAt: q.date,
        unlockedByQId: q.id,
        impliedBy: q.level,
      );
    }

    return AchievementResult.inProgress(
      achievement: this,
      have: direct.length,
      need: qCountNeeded,
    );
  }
}

/// MACH — Master Agility Champion.
/// Requires 750 championship MACH points + 20 double Qs (Master Standard
/// + Master JWW on the same day).
class MachTitle extends Achievement {
  @override
  String get id => 'akc.agility.mach';
  @override
  String get title => 'MACH';
  @override
  String get description =>
      '750 championship points + 20 double Qs (Master Std + Master JWW same day)';
  @override
  String get sport => 'AKC Agility';

  static const pointsNeeded = 750;
  static const doubleQsNeeded = 20;

  @override
  AchievementResult evaluate(List<Q> qs) {
    final masterQs =
        qs.where((q) => q.level == AgilityLevel.master).toList();

    final points = masterQs.fold<int>(0, (s, q) => s + q.machPoints);

    final dayMap = <DateTime, Set<AgilityClass>>{};
    for (final q in masterQs) {
      final d = DateTime(q.date.year, q.date.month, q.date.day);
      dayMap.putIfAbsent(d, () => {}).add(q.agilityClass);
    }
    // Sort double-Q days chronologically and count.
    final doubleQDays = dayMap.entries
        .where((e) =>
            e.value.contains(AgilityClass.standard) &&
            e.value.contains(AgilityClass.jww))
        .map((e) => e.key)
        .toList()
      ..sort();

    final doubleQs = doubleQDays.length;

    // Need both criteria. Report progress as the min of the two ratios.
    final pointProgress = points / pointsNeeded;
    final dqProgress = doubleQs / doubleQsNeeded;
    final overallHave =
        ((pointProgress.clamp(0.0, 1.0) + dqProgress.clamp(0.0, 1.0)) /
                2 *
                100)
            .round();

    if (points >= pointsNeeded && doubleQs >= doubleQsNeeded) {
      // Unlocked on the later of (Nth double-Q day) or (the Q that pushed
      // points past the threshold).
      final dqUnlockDay = doubleQDays[doubleQsNeeded - 1];

      final sortedMaster = [...masterQs]
        ..sort((a, b) => a.date.compareTo(b.date));
      var running = 0;
      Q? pointUnlocker;
      for (final q in sortedMaster) {
        running += q.machPoints;
        if (running >= pointsNeeded) {
          pointUnlocker = q;
          break;
        }
      }
      final pointUnlockDay = pointUnlocker?.date ?? dqUnlockDay;
      final unlockDay = pointUnlockDay.isAfter(dqUnlockDay)
          ? pointUnlockDay
          : dqUnlockDay;

      return AchievementResult(
        achievement: this,
        have: 100,
        need: 100,
        unlockedAt: unlockDay,
        unlockedByQId: pointUnlocker?.id,
      );
    }

    return AchievementResult.inProgress(
      achievement: this,
      have: overallHave,
      need: 100,
    );
  }
}
