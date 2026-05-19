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

  /// True when the dog has met the bar. Almost always anchored to an
  /// [unlockedAt] date, but for titles whose Q-count was filled in
  /// from an AKC report (and not yet from real Qs), `have >= need`
  /// can be true while `unlockedAt` is null — a "phantom unlock".
  bool get isUnlocked => unlockedAt != null || have >= need;
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

/// A reservoir of numbers (Q counts, points, double-Qs, triple-Qs)
/// that contributes to a title and that the user can manually adjust
/// via the +/- adjuster. Multiple titles in a chain (MX/MXB/MXS;
/// MACH/MACH2/...) reference the same pool by [key] so adjustments
/// propagate naturally.
///
/// [realFor] computes the recorded value from a dog's Qs; the engine
/// takes `max(realFor(qs), override)` when evaluating the achievement.
class Pool {
  const Pool({
    required this.key,
    required this.label,
    required this.realFor,
  });

  /// Storage key (e.g. `agility::std::master::reg`, `points::mach`,
  /// `dq::reg`, `tq::pref`). Persisted in Repo's override map under
  /// `${dogId}::${key}` — must stay stable.
  final String key;

  /// User-facing display name shown in the +/- adjuster header and in
  /// the missing-Qs report (e.g. "Qs", "MACH points", "QQs", "Triple
  /// Qs").
  final String label;

  /// Real (recorded) value derivable from the dog's Qs. Used to
  /// compute the override-vs-real gap and to size the floor of the
  /// "−" button on the adjuster.
  final int Function(List<Q> qs) realFor;
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

  /// Evaluate this achievement against [qs], optionally taking
  /// user-recorded [overrides] into account. The overrides map is
  /// keyed by [Pool.key]; each pool the achievement consults is
  /// `max(realFor(qs), overrides[key] ?? 0)`. Crossing a threshold by
  /// override alone yields a phantom unlock (`unlockedAt: null`).
  AchievementResult evaluate(List<Q> qs, {Map<String, int> overrides = const {}});

  /// All pools this achievement reads from. Q-count titles return one
  /// entry; champion / triple-Q titles return multiple (points + QQs,
  /// or QQQs only). Empty when the title isn't adjustable (e.g. NAC,
  /// which uses windowed totals).
  List<Pool> get pools => const [];

  /// Threshold this achievement requires for a given pool. The
  /// +/- adjuster uses this to cap the "+" button. Null when not
  /// applicable.
  int? needForPool(String poolKey) => null;
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

  String get _poolKey =>
      'agility::${agilityClass.name}::${level.name}::${preferred ? "pref" : "reg"}';

  @override
  List<Pool> get pools => [
        Pool(
          key: _poolKey,
          label: 'Qs',
          realFor: (qs) => qs.where(acceptsQ).length,
        ),
      ];

  @override
  int? needForPool(String poolKey) =>
      poolKey == _poolKey ? qCountNeeded : null;

  @override
  AchievementResult evaluate(List<Q> qs,
      {Map<String, int> overrides = const {}}) {
    final direct = qs
        .where((q) =>
            q.agilityClass == agilityClass &&
            q.preferred == preferred &&
            q.level == level)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final contributing = direct.map((q) => q.id).toList();
    final realCount = direct.length;
    final override = overrides[_poolKey] ?? 0;
    final effective = realCount > override ? realCount : override;

    if (realCount >= qCountNeeded) {
      final unlockingQ = direct[qCountNeeded - 1];
      return AchievementResult(
        achievement: this,
        have: effective,
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
            q.level != null &&
            q.level!.rank > level.rank)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (higher.isNotEmpty) {
      final q = higher.first;
      return AchievementResult(
        achievement: this,
        have: effective,
        need: qCountNeeded,
        unlockedAt: q.date,
        unlockedByQId: q.id,
        impliedBy: q.level!.label,
        contributingQIds: contributing,
      );
    }

    if (effective >= qCountNeeded) {
      // Phantom unlock: override pushed past need but no real Q crossed
      // the line.
      return AchievementResult(
        achievement: this,
        have: effective,
        need: qCountNeeded,
        contributingQIds: contributing,
      );
    }

    return AchievementResult.inProgress(
      achievement: this,
      have: effective,
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

  String get _poolKey => 'agility::${agilityClass.name}::master::reg';

  @override
  List<Pool> get pools => [
        Pool(
          key: _poolKey,
          label: 'Qs',
          realFor: (qs) => qs.where(acceptsQ).length,
        ),
      ];

  @override
  int? needForPool(String poolKey) =>
      poolKey == _poolKey ? qCountNeeded : null;

  @override
  AchievementResult evaluate(List<Q> qs,
      {Map<String, int> overrides = const {}}) {
    final direct = qs
        .where((q) => q.agilityClass == agilityClass)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final contributing = direct.map((q) => q.id).toList();
    final realCount = direct.length;
    final override = overrides[_poolKey] ?? 0;
    final effective = realCount > override ? realCount : override;
    if (realCount >= qCountNeeded) {
      final unlockingQ = direct[qCountNeeded - 1];
      return AchievementResult(
        achievement: this,
        have: effective,
        need: qCountNeeded,
        unlockedAt: unlockingQ.date,
        unlockedByQId: unlockingQ.id,
        contributingQIds: contributing,
      );
    }
    if (effective >= qCountNeeded) {
      return AchievementResult(
        achievement: this,
        have: effective,
        need: qCountNeeded,
        contributingQIds: contributing,
      );
    }
    return AchievementResult.inProgress(
      achievement: this,
      have: effective,
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

  /// Storage keys for the pools that contribute to this title. Shared
  /// across all tiers in the family (MACH/MACH2/.../MACH22 all use
  /// `points::mach` + `dq::reg`).
  String get _pointsPoolKey => preferred ? 'points::pach' : 'points::mach';
  String get _dqPoolKey => preferred ? 'dq::pref' : 'dq::reg';

  @override
  List<Pool> get pools {
    final family = preferred
        ? (pointsPerLevel == 0 ? 'PAX' : 'PACH')
        : 'MACH';
    return [
      // Points pool is omitted for PAX (pointsPerLevel == 0) — that
      // family is QQs-only.
      if (pointsPerLevel != 0)
        Pool(
          key: _pointsPoolKey,
          label: '$family points',
          realFor: _realPoints,
        ),
      Pool(
        key: _dqPoolKey,
        label: 'QQs',
        realFor: _realDoubleQs,
      ),
    ];
  }

  @override
  int? needForPool(String poolKey) {
    if (poolKey == _pointsPoolKey && pointsPerLevel != 0) return pointsNeeded;
    if (poolKey == _dqPoolKey) return doubleQsNeeded;
    return null;
  }

  int _realPoints(List<Q> qs) =>
      qs.where(acceptsQ).fold<int>(0, (s, q) => s + q.machPoints);

  int _realDoubleQs(List<Q> qs) {
    final dayMap = <DateTime, Set<AgilityClass>>{};
    for (final q in qs.where(acceptsQ)) {
      final d = DateTime(q.date.year, q.date.month, q.date.day);
      dayMap.putIfAbsent(d, () => {}).add(q.agilityClass!);
    }
    return dayMap.values
        .where((s) =>
            s.contains(AgilityClass.standard) &&
            s.contains(AgilityClass.jww))
        .length;
  }

  @override
  AchievementResult evaluate(List<Q> qs,
      {Map<String, int> overrides = const {}}) {
    final masterQs = qs.where(acceptsQ).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final realPoints = masterQs.fold<int>(0, (s, q) => s + q.machPoints);

    final dayMap = <DateTime, Set<AgilityClass>>{};
    for (final q in masterQs) {
      final d = DateTime(q.date.year, q.date.month, q.date.day);
      dayMap.putIfAbsent(d, () => {}).add(q.agilityClass!);
    }
    final doubleQDays = dayMap.entries
        .where((e) =>
            e.value.contains(AgilityClass.standard) &&
            e.value.contains(AgilityClass.jww))
        .map((e) => e.key)
        .toList()
      ..sort();

    final realDqs = doubleQDays.length;
    final contributing = masterQs.map((q) => q.id).toList();

    // Apply pool overrides — bump effective values up to whatever the
    // user has recorded from AKC's report. Title unlocks when both
    // effective points AND effective QQs meet their thresholds.
    final pointsOverride =
        pointsPerLevel == 0 ? 0 : (overrides[_pointsPoolKey] ?? 0);
    final dqOverride = overrides[_dqPoolKey] ?? 0;
    final points = realPoints > pointsOverride ? realPoints : pointsOverride;
    final doubleQs = realDqs > dqOverride ? realDqs : dqOverride;

    if (points >= pointsNeeded && doubleQs >= doubleQsNeeded) {
      // Anchor the unlock date to the real Q that closed the gap —
      // only possible when reality (not an override) crossed both
      // thresholds. Otherwise leave it null (phantom unlock).
      DateTime? unlockDay;
      Q? unlocker;
      if (realPoints >= pointsNeeded && realDqs >= doubleQsNeeded) {
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
        unlockDay = pointUnlockDay.isAfter(dqUnlockDay)
            ? pointUnlockDay
            : dqUnlockDay;
        unlocker = pointUnlocker;
      }
      return AchievementResult(
        achievement: this,
        have: 100,
        need: 100,
        unlockedAt: unlockDay,
        unlockedByQId: unlocker?.id,
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

  /// Live progress numbers for the detail view. With overrides
  /// applied, returns the effective (max of real + override) counts.
  ({int points, int dqs}) liveCounts(
    List<Q> qs, {
    Map<String, int> overrides = const {},
  }) {
    final realPoints = _realPoints(qs);
    final realDqs = _realDoubleQs(qs);
    final pointsOverride =
        pointsPerLevel == 0 ? 0 : (overrides[_pointsPoolKey] ?? 0);
    final dqOverride = overrides[_dqPoolKey] ?? 0;
    final points = realPoints > pointsOverride ? realPoints : pointsOverride;
    final dqs = realDqs > dqOverride ? realDqs : dqOverride;
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
  AchievementResult evaluate(List<Q> qs,
      {Map<String, int> overrides = const {}}) {
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

  String get _poolKey => 'scent::${element.name}::${level.name}';

  @override
  List<Pool> get pools => [
        Pool(
          key: _poolKey,
          label: 'Qs',
          realFor: (qs) => qs.where(acceptsQ).length,
        ),
      ];

  @override
  int? needForPool(String poolKey) =>
      poolKey == _poolKey ? qCountNeeded : null;

  @override
  AchievementResult evaluate(List<Q> qs,
      {Map<String, int> overrides = const {}}) {
    final direct = qs.where(acceptsQ).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final contributing = direct.map((q) => q.id).toList();
    final realCount = direct.length;
    final override = overrides[_poolKey] ?? 0;
    final effective = realCount > override ? realCount : override;

    if (realCount >= qCountNeeded) {
      final unlocker = direct[qCountNeeded - 1];
      return AchievementResult(
        achievement: this,
        have: effective,
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
        have: effective,
        need: qCountNeeded,
        unlockedAt: q.date,
        unlockedByQId: q.id,
        impliedBy: q.scentLevel!.label,
        contributingQIds: contributing,
      );
    }

    if (effective >= qCountNeeded) {
      return AchievementResult(
        achievement: this,
        have: effective,
        need: qCountNeeded,
        contributingQIds: contributing,
      );
    }

    return AchievementResult.inProgress(
      achievement: this,
      have: effective,
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

  String get _poolKey => preferred ? 'tq::pref' : 'tq::reg';

  int _realTripleQs(List<Q> qs) {
    final dayMap = <DateTime, Set<AgilityClass>>{};
    for (final q in qs.where(acceptsQ)) {
      final d = DateTime(q.date.year, q.date.month, q.date.day);
      dayMap.putIfAbsent(d, () => {}).add(q.agilityClass!);
    }
    return dayMap.values
        .where((s) =>
            s.contains(AgilityClass.standard) &&
            s.contains(AgilityClass.jww) &&
            s.contains(AgilityClass.fast))
        .length;
  }

  @override
  List<Pool> get pools => [
        Pool(
          key: _poolKey,
          label: 'Triple Qs',
          realFor: _realTripleQs,
        ),
      ];

  @override
  int? needForPool(String poolKey) =>
      poolKey == _poolKey ? tripleQsNeeded : null;

  @override
  AchievementResult evaluate(List<Q> qs,
      {Map<String, int> overrides = const {}}) {
    final masterQs = qs.where(acceptsQ).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final dayMap = <DateTime, Set<AgilityClass>>{};
    for (final q in masterQs) {
      final d = DateTime(q.date.year, q.date.month, q.date.day);
      dayMap.putIfAbsent(d, () => {}).add(q.agilityClass!);
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
    final realCount = tripleDays.length;
    final override = overrides[_poolKey] ?? 0;
    final effective = realCount > override ? realCount : override;

    if (realCount >= tripleQsNeeded) {
      final unlockDay = tripleDays[tripleQsNeeded - 1];
      // Pick the latest Q on the unlock day as the "unlocker".
      Q? unlocker;
      for (final q in masterQs) {
        final d = DateTime(q.date.year, q.date.month, q.date.day);
        if (d == unlockDay) unlocker = q;
      }
      return AchievementResult(
        achievement: this,
        have: effective,
        need: tripleQsNeeded,
        unlockedAt: unlockDay,
        unlockedByQId: unlocker?.id,
        contributingQIds: contributing,
      );
    }
    if (effective >= tripleQsNeeded) {
      // Phantom-unlocked via override only.
      return AchievementResult(
        achievement: this,
        have: effective,
        need: tripleQsNeeded,
        contributingQIds: contributing,
      );
    }
    return AchievementResult.inProgress(
      achievement: this,
      have: effective,
      need: tripleQsNeeded,
      contributingQIds: contributing,
    );
  }
}

/// Qualification for the AKC National Agility Championship for a given
/// year. Rules vary slightly year-to-year; defaults here track the 2027
/// rules published at akccompanionevents.com.
///
/// 2027 (Tulsa, March 11–14):
///   * Window: Dec 1 (year-2) through Nov 30 (year-1).
///   * 7 double-Q's from Master Std + Master JWW on the same day.
///   * 550 total MACH/PACH + Premier points
///     (every Premier leg in the window adds 15 NAC points).
///   * Up to 2 DQ's may be substituted by Premier pairs — each pair of
///     (1 Premier STD + 1 Premier JWW, not necessarily same trial)
///     replaces one DQ. The PSTD/PJWW legs can come from any trial in
///     the window.
///   * Preferred has its own parallel qualification (same numbers,
///     evaluated against the Preferred divisions independently).
class NACQualificationTitle extends Achievement {
  NACQualificationTitle({
    required this.qualificationYear,
    this.preferred = false,
    this.pointsNeeded = 550,
    this.qqsNeeded = 7,
    this.premierPointValue = 15,
    this.maxPremierDqSubstitutes = 2,
  });

  final int qualificationYear;
  final int pointsNeeded;
  final int qqsNeeded;
  final int premierPointValue;
  final int maxPremierDqSubstitutes;

  @override
  final bool preferred;

  /// Dec 1 of (year-2) — e.g. window for NAC 2027 starts Dec 1, 2025.
  DateTime get windowStart => DateTime(qualificationYear - 2, 12, 1);

  /// Nov 30 of (year-1) — e.g. window for NAC 2027 ends Nov 30, 2026.
  DateTime get windowEnd =>
      DateTime(qualificationYear - 1, 11, 30, 23, 59, 59);

  @override
  String get id =>
      'akc.nac${preferred ? ".preferred" : ""}.$qualificationYear';
  @override
  String get title =>
      preferred ? 'NAC Pref $qualificationYear' : 'NAC $qualificationYear';
  @override
  String get description => preferred
      ? 'Qualified for the AKC National Agility Championship $qualificationYear (Preferred)'
      : 'Qualified for the AKC National Agility Championship $qualificationYear';
  @override
  String get sport => 'AKC Agility';

  bool _inWindow(Q q) =>
      !q.date.isBefore(windowStart) && !q.date.isAfter(windowEnd);

  bool _isMasterStdOrJww(Q q) =>
      q.level == AgilityLevel.master &&
      (q.agilityClass == AgilityClass.standard ||
          q.agilityClass == AgilityClass.jww);

  bool _isPremierStdOrJww(Q q) =>
      q.agilityClass == AgilityClass.premierStandard ||
      q.agilityClass == AgilityClass.premierJww;

  @override
  bool acceptsQ(Q q) {
    if (!_inWindow(q)) return false;
    if (q.preferred != preferred) return false;
    return _isMasterStdOrJww(q) || _isPremierStdOrJww(q);
  }

  @override
  AchievementResult evaluate(List<Q> qs,
      {Map<String, int> overrides = const {}}) {
    // NAC counts points + QQs within a narrow rolling window; a
    // lifetime "MACH points" override can't be safely projected onto
    // it, so overrides are ignored here.
    final inWindow = qs.where(acceptsQ).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Points: MACH/PACH points on master std/jww Q's, plus 15 per
    // Premier leg (regardless of class — both PSTD and PJWW pay 15).
    var totalPoints = 0;
    for (final q in inWindow) {
      if (_isMasterStdOrJww(q)) totalPoints += q.machPoints;
      if (_isPremierStdOrJww(q)) totalPoints += premierPointValue;
    }

    // Double-Q days: a calendar day with at least one Master Std AND
    // one Master JWW Q.
    final dayMap = <DateTime, Set<AgilityClass>>{};
    for (final q in inWindow.where(_isMasterStdOrJww)) {
      final d = DateTime(q.date.year, q.date.month, q.date.day);
      dayMap.putIfAbsent(d, () => {}).add(q.agilityClass!);
    }
    final doubleQs = dayMap.values
        .where((cs) =>
            cs.contains(AgilityClass.standard) &&
            cs.contains(AgilityClass.jww))
        .length;

    // Premier DQ substitution. Each pair of (1 PSTD + 1 PJWW) in the
    // window swaps in for 1 DQ, capped at maxPremierDqSubstitutes.
    final premierStd = inWindow
        .where((q) => q.agilityClass == AgilityClass.premierStandard)
        .length;
    final premierJww = inWindow
        .where((q) => q.agilityClass == AgilityClass.premierJww)
        .length;
    final premierPairs = premierStd < premierJww ? premierStd : premierJww;
    final premierSubs = premierPairs < maxPremierDqSubstitutes
        ? premierPairs
        : maxPremierDqSubstitutes;
    final effectiveQQs = doubleQs + premierSubs;

    final contributing = inWindow.map((q) => q.id).toList();

    if (totalPoints >= pointsNeeded && effectiveQQs >= qqsNeeded) {
      // Walk chronologically to find the first Q that simultaneously
      // crossed both thresholds.
      var runningPoints = 0;
      var runningPstd = 0;
      var runningPjww = 0;
      final runningDayMap = <DateTime, Set<AgilityClass>>{};
      Q? unlocker;
      for (final q in inWindow) {
        if (_isMasterStdOrJww(q)) runningPoints += q.machPoints;
        if (_isPremierStdOrJww(q)) runningPoints += premierPointValue;
        if (q.agilityClass == AgilityClass.premierStandard) runningPstd++;
        if (q.agilityClass == AgilityClass.premierJww) runningPjww++;
        if (_isMasterStdOrJww(q)) {
          final d = DateTime(q.date.year, q.date.month, q.date.day);
          runningDayMap.putIfAbsent(d, () => {}).add(q.agilityClass!);
        }
        final runningDqs = runningDayMap.values
            .where((cs) =>
                cs.contains(AgilityClass.standard) &&
                cs.contains(AgilityClass.jww))
            .length;
        final runningPairs =
            runningPstd < runningPjww ? runningPstd : runningPjww;
        final runningSubs = runningPairs < maxPremierDqSubstitutes
            ? runningPairs
            : maxPremierDqSubstitutes;
        final runningEffQQs = runningDqs + runningSubs;
        if (runningPoints >= pointsNeeded && runningEffQQs >= qqsNeeded) {
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
    final pointFrac = (totalPoints / pointsNeeded).clamp(0.0, 1.0);
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
    final inWindow = qs.where(acceptsQ).toList();
    var points = 0;
    for (final q in inWindow) {
      if (_isMasterStdOrJww(q)) points += q.machPoints;
      if (_isPremierStdOrJww(q)) points += premierPointValue;
    }
    final dayMap = <DateTime, Set<AgilityClass>>{};
    for (final q in inWindow.where(_isMasterStdOrJww)) {
      final d = DateTime(q.date.year, q.date.month, q.date.day);
      dayMap.putIfAbsent(d, () => {}).add(q.agilityClass!);
    }
    final dqs = dayMap.values
        .where((cs) =>
            cs.contains(AgilityClass.standard) &&
            cs.contains(AgilityClass.jww))
        .length;
    final premierStd = inWindow
        .where((q) => q.agilityClass == AgilityClass.premierStandard)
        .length;
    final premierJww = inWindow
        .where((q) => q.agilityClass == AgilityClass.premierJww)
        .length;
    final premierPairs = premierStd < premierJww ? premierStd : premierJww;
    final subs = premierPairs < maxPremierDqSubstitutes
        ? premierPairs
        : maxPremierDqSubstitutes;
    return (points: points, qqs: dqs + subs);
  }
}
