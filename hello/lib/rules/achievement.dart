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
    this.contributingQIds = const [],
  });

  final Achievement achievement;
  final int have;
  final int need;

  /// Computed timestamp at which the achievement was unlocked. Anchored
  /// to the Q that pushed it over.
  final DateTime? unlockedAt;

  /// Id of the Q that unlocked this achievement (the Nth qualifying Q,
  /// or the higher-level Q that implied it).
  final String? unlockedByQId;

  /// If unlocked by implication (a higher-level Q implies all
  /// prior-level titles), this is the human-readable level label of the
  /// implying Q (e.g. "Master", "Detective"). Null if unlocked directly.
  final String? impliedBy;

  /// All Qs that count toward this achievement, in chronological order.
  /// Used by the detail view to surface contributing runs.
  final List<String> contributingQIds;

  bool get isUnlocked => unlockedAt != null;
  bool get hasProgress => have > 0 || isUnlocked;
  double get progress => need <= 0 ? 1.0 : (have / need).clamp(0.0, 1.0);

  AchievementResult.inProgress({
    required this.achievement,
    required this.have,
    required this.need,
    this.contributingQIds = const [],
  })  : unlockedAt = null,
        unlockedByQId = null,
        impliedBy = null;
}

/// Names a chain of titles that build on each other (e.g. NAJ → OAJ →
/// AXJ → MXJ → MJB → MJS → ...). Used by the detail view to surface
/// "prior titles in the chain" and to compute implications.
class TitleProgression {
  TitleProgression({required this.name, required this.titles});

  final String name;
  final List<Achievement> titles;

  Achievement? priorOf(Achievement a) {
    final i = titles.indexOf(a);
    if (i <= 0) return null;
    return titles[i - 1];
  }

  List<Achievement> priorChain(Achievement a) {
    final i = titles.indexOf(a);
    if (i <= 0) return const [];
    return titles.sublist(0, i);
  }
}

abstract class Achievement {
  String get id;
  String get title;
  String get description;
  String get sport;

  /// The class+division this achievement is part of, used to find
  /// related Qs for the detail view. Null for combo titles like MACH.
  AgilityClass? get achievementClass => null;
  AgilityLevel? get achievementLevel => null;
  bool get preferred => false;

  /// Whether a Q at the same class+division+level (or higher) counts
  /// toward this achievement. Used by the detail view to show
  /// "contributing" Qs.
  bool acceptsQ(Q q);

  AchievementResult evaluate(List<Q> qs);
}

/// A title earned by accumulating N Qs of a given class+level+division.
///
/// AKC titling is strictly progressive — to compete at Excellent level
/// you must already hold the Open title, etc. So a Q at a higher level
/// *implies* every lower-level title in the same class+division has
/// already been earned. Implied titles are timestamped from the first
/// higher-level Q.
class LevelQCountTitle extends Achievement {
  LevelQCountTitle({
    required this.id,
    required this.title,
    required this.description,
    required this.agilityClass,
    required this.level,
    required this.qCountNeeded,
    this.preferred = false,
  });

  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  String get sport => 'AKC Agility';

  @override
  final bool preferred;
  final AgilityClass agilityClass;
  final AgilityLevel level;
  final int qCountNeeded;

  @override
  AgilityClass? get achievementClass => agilityClass;
  @override
  AgilityLevel? get achievementLevel => level;

  @override
  bool acceptsQ(Q q) =>
      q.agilityClass == agilityClass &&
      q.preferred == preferred &&
      q.level == level;

  @override
  AchievementResult evaluate(List<Q> qs) {
    final direct = qs
        .where((q) =>
            q.agilityClass == agilityClass &&
            q.preferred == preferred &&
            q.level == level)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final contributing = direct.map((q) => q.id).toList();

    if (direct.length >= qCountNeeded) {
      final unlockingQ = direct[qCountNeeded - 1];
      return AchievementResult(
        achievement: this,
        have: direct.length,
        need: qCountNeeded,
        unlockedAt: unlockingQ.date,
        unlockedByQId: unlockingQ.id,
        contributingQIds: contributing,
      );
    }

    // Implication: any Q at a higher level in the same class+division
    // means this title is already earned (AKC progression rules).
    final higher = qs
        .where((q) =>
            q.agilityClass == agilityClass &&
            q.preferred == preferred &&
            q.level.rank > level.rank)
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
        impliedBy: q.level.label,
        contributingQIds: contributing,
      );
    }

    return AchievementResult.inProgress(
      achievement: this,
      have: direct.length,
      need: qCountNeeded,
      contributingQIds: contributing,
    );
  }
}

/// Premier titles — PAD (Premier Standard Dog), PJD (Premier JWW Dog).
/// Earned by accumulating N Qs in a Premier class.
class PremierCountTitle extends Achievement {
  PremierCountTitle({
    required this.id,
    required this.title,
    required this.description,
    required this.agilityClass,
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
  final int qCountNeeded;

  @override
  AgilityClass? get achievementClass => agilityClass;
  @override
  AgilityLevel? get achievementLevel => AgilityLevel.master;

  @override
  bool acceptsQ(Q q) => q.agilityClass == agilityClass;

  @override
  AchievementResult evaluate(List<Q> qs) {
    final direct = qs
        .where((q) => q.agilityClass == agilityClass)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final contributing = direct.map((q) => q.id).toList();
    if (direct.length >= qCountNeeded) {
      final unlockingQ = direct[qCountNeeded - 1];
      return AchievementResult(
        achievement: this,
        have: direct.length,
        need: qCountNeeded,
        unlockedAt: unlockingQ.date,
        unlockedByQId: unlockingQ.id,
        contributingQIds: contributing,
      );
    }
    return AchievementResult.inProgress(
      achievement: this,
      have: direct.length,
      need: qCountNeeded,
      contributingQIds: contributing,
    );
  }
}

/// Champion titles: MACH (regular Master Std+JWW), PACH (preferred
/// Master Std+JWW with points), PAX (preferred Master Std+JWW —
/// double-Qs only, NO points required), and their repeated variants.
///
/// AKC rulebook (Ch. 2 §2, Ch. 8 §7, Ch. 8 §8):
///   MACH = 750 MACH points + 20 2Qs.   MACHn = n × that.
///   PACH = 750 PACH points + 20 2Qs.   PACHn = n × that.
///   PAX  = 20 preferred 2Qs only.       PAXn = n × that.
///
/// `pointsPerLevel: 0` makes the points threshold trivially satisfied
/// (used for PAX).
class ChampionTitle extends Achievement {
  ChampionTitle({
    required this.id,
    required this.title,
    required this.description,
    required this.multiplier,
    required this.preferred,
    this.pointsPerLevel = 750,
    this.doubleQsPerLevel = 20,
  });

  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  String get sport => 'AKC Agility';
  @override
  final bool preferred;

  /// 1 for MACH/PAX, 2 for MACH2/PAX2, ...
  final int multiplier;
  final int pointsPerLevel;
  final int doubleQsPerLevel;
  int get pointsNeeded => pointsPerLevel * multiplier;
  int get doubleQsNeeded => doubleQsPerLevel * multiplier;

  @override
  bool acceptsQ(Q q) =>
      q.level == AgilityLevel.master &&
      q.preferred == preferred &&
      (q.agilityClass == AgilityClass.standard ||
          q.agilityClass == AgilityClass.jww);

  @override
  AchievementResult evaluate(List<Q> qs) {
    final masterQs = qs.where(acceptsQ).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final points = masterQs.fold<int>(0, (s, q) => s + q.machPoints);

    final dayMap = <DateTime, Set<AgilityClass>>{};
    for (final q in masterQs) {
      final d = DateTime(q.date.year, q.date.month, q.date.day);
      dayMap.putIfAbsent(d, () => {}).add(q.agilityClass);
    }
    final doubleQDays = dayMap.entries
        .where((e) =>
            e.value.contains(AgilityClass.standard) &&
            e.value.contains(AgilityClass.jww))
        .map((e) => e.key)
        .toList()
      ..sort();

    final doubleQs = doubleQDays.length;
    final contributing = masterQs.map((q) => q.id).toList();

    if (points >= pointsNeeded && doubleQs >= doubleQsNeeded) {
      final dqUnlockDay = doubleQDays[doubleQsNeeded - 1];
      var running = 0;
      Q? pointUnlocker;
      for (final q in masterQs) {
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
        contributingQIds: contributing,
      );
    }

    final pointFrac = (points / pointsNeeded).clamp(0.0, 1.0);
    final dqFrac = (doubleQs / doubleQsNeeded).clamp(0.0, 1.0);
    final overall = ((pointFrac + dqFrac) / 2 * 100).round();
    return AchievementResult.inProgress(
      achievement: this,
      have: overall,
      need: 100,
      contributingQIds: contributing,
    );
  }

  /// Live progress numbers for the detail view.
  ({int points, int dqs}) liveCounts(List<Q> qs) {
    final masterQs = qs.where(acceptsQ);
    final points = masterQs.fold<int>(0, (s, q) => s + q.machPoints);
    final dayMap = <DateTime, Set<AgilityClass>>{};
    for (final q in masterQs) {
      final d = DateTime(q.date.year, q.date.month, q.date.day);
      dayMap.putIfAbsent(d, () => {}).add(q.agilityClass);
    }
    final dqs = dayMap.values
        .where((s) =>
            s.contains(AgilityClass.standard) &&
            s.contains(AgilityClass.jww))
        .length;
    return (points: points, dqs: dqs);
  }
}

/// A title earned by accumulating a cumulative score across all Qs in
/// a given sport. Used by FastCAT (BCAT/DCAT/FCAT*) where the title
/// threshold is total points, not Q count.
class PointAccumulationTitle extends Achievement {
  PointAccumulationTitle({
    required this.id,
    required this.title,
    required this.description,
    required this.sport,
    required this.sportFilter,
    required this.pointsNeeded,
  });

  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  final String sport;

  /// Sport whose Qs contribute. Q.sport must match.
  final Sport sportFilter;
  final int pointsNeeded;

  @override
  bool acceptsQ(Q q) => q.sport == sportFilter && q.score != null;

  @override
  AchievementResult evaluate(List<Q> qs) {
    final relevant = qs.where(acceptsQ).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final total = relevant.fold<int>(0, (s, q) => s + (q.score ?? 0));
    final contributing = relevant.map((q) => q.id).toList();

    if (total >= pointsNeeded) {
      var running = 0;
      Q? unlocker;
      for (final q in relevant) {
        running += q.score ?? 0;
        if (running >= pointsNeeded) {
          unlocker = q;
          break;
        }
      }
      return AchievementResult(
        achievement: this,
        have: total,
        need: pointsNeeded,
        unlockedAt: unlocker?.date,
        unlockedByQId: unlocker?.id,
        contributingQIds: contributing,
      );
    }
    return AchievementResult.inProgress(
      achievement: this,
      have: total,
      need: pointsNeeded,
      contributingQIds: contributing,
    );
  }
}

/// A scentwork title — N qualifying runs in a given (element, level).
class ScentElementLevelTitle extends Achievement {
  ScentElementLevelTitle({
    required this.id,
    required this.title,
    required this.description,
    required this.element,
    required this.level,
    this.qCountNeeded = 3,
  });

  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  String get sport => 'AKC Scentwork';

  final ScentElement element;
  final ScentLevel level;
  final int qCountNeeded;

  @override
  bool acceptsQ(Q q) =>
      q.sport == Sport.scentwork &&
      q.scentElement == element &&
      q.scentLevel == level;

  @override
  AchievementResult evaluate(List<Q> qs) {
    final direct = qs.where(acceptsQ).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final contributing = direct.map((q) => q.id).toList();

    if (direct.length >= qCountNeeded) {
      final unlocker = direct[qCountNeeded - 1];
      return AchievementResult(
        achievement: this,
        have: direct.length,
        need: qCountNeeded,
        unlockedAt: unlocker.date,
        unlockedByQId: unlocker.id,
        contributingQIds: contributing,
      );
    }

    // Implication: AKC Scentwork classes are progressive (Novice →
    // Advanced → Excellent → Master → Detective). A Q at any higher
    // level in the same element implies every lower-level title at
    // that element has already been earned. Mirrors the agility
    // LevelQCountTitle behavior so handlers don't need to backfill
    // every lower-level Q manually.
    final higher = qs
        .where((q) =>
            q.sport == Sport.scentwork &&
            q.scentElement == element &&
            q.scentLevel != null &&
            q.scentLevel!.rank > level.rank)
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
        impliedBy: q.scentLevel!.label,
        contributingQIds: contributing,
      );
    }

    return AchievementResult.inProgress(
      achievement: this,
      have: direct.length,
      need: qCountNeeded,
      contributingQIds: contributing,
    );
  }
}

/// Triple-Q title (TQX / TQXP) — N days where the dog earned a Master
/// Standard + Master JWW + Master FAST Q on the same calendar day.
///
/// Rulebook Ch. 9 §9: TQX = 10 triple-Q days; TQXP = 10 preferred
/// triple-Q days.
class TripleQTitle extends Achievement {
  TripleQTitle({
    required this.id,
    required this.title,
    required this.description,
    required this.preferred,
    this.tripleQsNeeded = 10,
  });

  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  String get sport => 'AKC Agility';
  @override
  final bool preferred;
  final int tripleQsNeeded;

  static const _classes = {
    AgilityClass.standard,
    AgilityClass.jww,
    AgilityClass.fast,
  };

  @override
  bool acceptsQ(Q q) =>
      q.level == AgilityLevel.master &&
      q.preferred == preferred &&
      _classes.contains(q.agilityClass);

  @override
  AchievementResult evaluate(List<Q> qs) {
    final masterQs = qs.where(acceptsQ).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final dayMap = <DateTime, Set<AgilityClass>>{};
    for (final q in masterQs) {
      final d = DateTime(q.date.year, q.date.month, q.date.day);
      dayMap.putIfAbsent(d, () => {}).add(q.agilityClass);
    }
    final tripleDays = dayMap.entries
        .where((e) =>
            e.value.contains(AgilityClass.standard) &&
            e.value.contains(AgilityClass.jww) &&
            e.value.contains(AgilityClass.fast))
        .map((e) => e.key)
        .toList()
      ..sort();
    final contributing = masterQs.map((q) => q.id).toList();

    if (tripleDays.length >= tripleQsNeeded) {
      final unlockDay = tripleDays[tripleQsNeeded - 1];
      // Pick the latest Q on the unlock day as the "unlocker".
      Q? unlocker;
      for (final q in masterQs) {
        final d = DateTime(q.date.year, q.date.month, q.date.day);
        if (d == unlockDay) unlocker = q;
      }
      return AchievementResult(
        achievement: this,
        have: tripleDays.length,
        need: tripleQsNeeded,
        unlockedAt: unlockDay,
        unlockedByQId: unlocker?.id,
        contributingQIds: contributing,
      );
    }
    return AchievementResult.inProgress(
      achievement: this,
      have: tripleDays.length,
      need: tripleQsNeeded,
      contributingQIds: contributing,
    );
  }
}

/// Qualification for the AKC National Agility Championship for a given
/// year. Window is Sep 1 (year-1) through Aug 31 (year), inclusive.
/// Composite criterion: enough MACH points AND enough double-Qs (where
/// a Premier Q counts as half a double-Q for simplicity).
///
/// AKC's exact formula varies year to year; these are reasonable
/// defaults you can tweak per chain.
class NACQualificationTitle extends Achievement {
  NACQualificationTitle({
    required this.qualificationYear,
    this.pointsNeeded = 400,
    this.qqsNeeded = 4,
  });

  final int qualificationYear;
  final int pointsNeeded;
  final int qqsNeeded;

  DateTime get windowStart => DateTime(qualificationYear - 1, 9, 1);
  DateTime get windowEnd =>
      DateTime(qualificationYear, 8, 31, 23, 59, 59);

  @override
  String get id => 'akc.nac.$qualificationYear';
  @override
  String get title => 'NAC $qualificationYear';
  @override
  String get description =>
      'Qualified for the AKC National Agility Championship $qualificationYear';
  @override
  String get sport => 'AKC Agility';
  @override
  bool get preferred => false;

  bool _inWindow(Q q) =>
      !q.date.isBefore(windowStart) && !q.date.isAfter(windowEnd);

  @override
  bool acceptsQ(Q q) {
    if (!_inWindow(q)) return false;
    if (q.preferred) return false;
    if (q.level != AgilityLevel.master) return false;
    return q.agilityClass == AgilityClass.standard ||
        q.agilityClass == AgilityClass.jww ||
        q.agilityClass == AgilityClass.premierStandard ||
        q.agilityClass == AgilityClass.premierJww;
  }

  @override
  AchievementResult evaluate(List<Q> qs) {
    final inWindow = qs.where(acceptsQ).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final points = inWindow.fold<int>(0, (s, q) => s + q.machPoints);

    // Double-Qs: a calendar day with at least one Master Std AND one
    // Master JWW Q. A Premier Q on its own counts as a half double-Q.
    final dayMap = <DateTime, Set<AgilityClass>>{};
    for (final q in inWindow) {
      final d = DateTime(q.date.year, q.date.month, q.date.day);
      dayMap.putIfAbsent(d, () => {}).add(q.agilityClass);
    }
    var doubleQs = 0;
    var premierHalves = 0;
    for (final classes in dayMap.values) {
      if (classes.contains(AgilityClass.standard) &&
          classes.contains(AgilityClass.jww)) {
        doubleQs++;
      }
      if (classes.contains(AgilityClass.premierStandard) ||
          classes.contains(AgilityClass.premierJww)) {
        premierHalves++;
      }
    }
    final effectiveQQs = doubleQs + (premierHalves / 2).floor();
    final contributing = inWindow.map((q) => q.id).toList();

    if (points >= pointsNeeded && effectiveQQs >= qqsNeeded) {
      // Walk in chronological order to find when both thresholds were
      // simultaneously satisfied.
      var runningPoints = 0;
      final dayClasses = <DateTime, Set<AgilityClass>>{};
      Q? unlocker;
      for (final q in inWindow) {
        runningPoints += q.machPoints;
        final d = DateTime(q.date.year, q.date.month, q.date.day);
        dayClasses.putIfAbsent(d, () => {}).add(q.agilityClass);
        var dqs = 0;
        var halves = 0;
        for (final cs in dayClasses.values) {
          if (cs.contains(AgilityClass.standard) &&
              cs.contains(AgilityClass.jww)) {
            dqs++;
          }
          if (cs.contains(AgilityClass.premierStandard) ||
              cs.contains(AgilityClass.premierJww)) {
            halves++;
          }
        }
        final eff = dqs + (halves / 2).floor();
        if (runningPoints >= pointsNeeded && eff >= qqsNeeded) {
          unlocker = q;
          break;
        }
      }
      return AchievementResult(
        achievement: this,
        have: 100,
        need: 100,
        unlockedAt: unlocker?.date ?? windowEnd,
        unlockedByQId: unlocker?.id,
        contributingQIds: contributing,
      );
    }

    if (contributing.isEmpty) {
      // No Qs in window — don't surface; engine filters out 0-progress.
      return AchievementResult.inProgress(
        achievement: this,
        have: 0,
        need: 100,
        contributingQIds: contributing,
      );
    }
    final pointFrac = (points / pointsNeeded).clamp(0.0, 1.0);
    final qqFrac = (effectiveQQs / qqsNeeded).clamp(0.0, 1.0);
    final overall = ((pointFrac + qqFrac) / 2 * 100).round();
    return AchievementResult.inProgress(
      achievement: this,
      have: overall,
      need: 100,
      contributingQIds: contributing,
    );
  }

  /// Live counts for the detail view.
  ({int points, int qqs}) liveCounts(List<Q> qs) {
    final inWindow = qs.where(acceptsQ);
    final points = inWindow.fold<int>(0, (s, q) => s + q.machPoints);
    final dayMap = <DateTime, Set<AgilityClass>>{};
    for (final q in inWindow) {
      final d = DateTime(q.date.year, q.date.month, q.date.day);
      dayMap.putIfAbsent(d, () => {}).add(q.agilityClass);
    }
    var dqs = 0;
    var halves = 0;
    for (final classes in dayMap.values) {
      if (classes.contains(AgilityClass.standard) &&
          classes.contains(AgilityClass.jww)) {
        dqs++;
      }
      if (classes.contains(AgilityClass.premierStandard) ||
          classes.contains(AgilityClass.premierJww)) {
        halves++;
      }
    }
    return (points: points, qqs: dqs + (halves / 2).floor());
  }
}
