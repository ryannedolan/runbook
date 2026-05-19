import '../models/q.dart';
import 'achievement.dart';
import 'engine.dart';

/// AKC FastCAT title chain — BCAT → DCAT → FCAT → FCAT2 → FCAT3 → …
///
/// Titles are awarded for cumulative points (50/100 yard dash speed
/// converted to MPH × breed handicap = points per run, summed over the
/// dog's career). The first three tiers have one-off thresholds
/// (150 / 500 / 1000); past FCAT every additional 1000 points unlocks
/// the next FCATn. There's no real cap, so we emit only as many
/// FCATn tiers as the dog has earned + one in-progress.

PointAccumulationTitle _bcat() => PointAccumulationTitle(
      id: 'akc.fastcat.bcat',
      title: 'BCAT',
      description: '150 FastCAT points.',
      sport: 'AKC FastCAT',
      sportFilter: Sport.fastCAT,
      pointsNeeded: 150,
    );

PointAccumulationTitle _dcat() => PointAccumulationTitle(
      id: 'akc.fastcat.dcat',
      title: 'DCAT',
      description: '500 FastCAT points.',
      sport: 'AKC FastCAT',
      sportFilter: Sport.fastCAT,
      pointsNeeded: 500,
    );

/// FastCAT tier n: n==1 is FCAT (1000 pts), n>=2 is FCAT$n (n*1000 pts).
PointAccumulationTitle fastCATTier(int n) => PointAccumulationTitle(
      id: n == 1 ? 'akc.fastcat.fcat' : 'akc.fastcat.fcat$n',
      title: n == 1 ? 'FCAT' : 'FCAT$n',
      description: n == 1
          ? '1000 FastCAT points.'
          : '${n * 1000} cumulative FastCAT points.',
      sport: 'AKC FastCAT',
      sportFilter: Sport.fastCAT,
      pointsNeeded: n * 1000,
    );

/// Emit BCAT, DCAT, FCAT, then FCAT2..FCAT(unlocked+1) as warranted.
List<AchievementResult> emitFastCATTiers(List<Q> qs,
    [Map<String, int> overrides = const {}]) {
  final relevant =
      qs.where((q) => q.sport == Sport.fastCAT && q.score != null);
  if (relevant.isEmpty) return const [];

  final totalPoints = relevant.fold<int>(0, (s, q) => s + q.score!);
  final fcatTiersUnlocked = totalPoints ~/ 1000; // FCAT=1 (1000pts)

  final out = <AchievementResult>[
    _bcat().evaluate(qs, overrides: overrides),
    _dcat().evaluate(qs, overrides: overrides),
    fastCATTier(1).evaluate(qs, overrides: overrides),
  ];
  for (var n = 2; n <= fcatTiersUnlocked + 1; n++) {
    out.add(fastCATTier(n).evaluate(qs, overrides: overrides));
  }
  return out;
}

/// FastCAT chain — sized to cover tiers 1..max(opened+1, unlocked+1)
/// plus the BCAT/DCAT entry tiers.
TitleProgression fastCATChainFor(PointAccumulationTitle opened, {List<Q>? qs}) {
  // Map opened.pointsNeeded back to a tier: BCAT=0, DCAT=0, FCAT=1, FCATn=n.
  int openedTier;
  if (opened.id == 'akc.fastcat.bcat' || opened.id == 'akc.fastcat.dcat') {
    openedTier = 0;
  } else {
    openedTier = opened.pointsNeeded ~/ 1000;
  }
  var maxTier = openedTier + 1;
  if (qs != null) {
    final emitted = emitFastCATTiers(qs);
    // Count only FCATn entries (skip BCAT/DCAT) by checking ids.
    final unlockedFcatTiers = emitted
        .where((r) =>
            r.isUnlocked &&
            r.achievement.id.startsWith('akc.fastcat.fcat'))
        .length;
    if (unlockedFcatTiers + 1 > maxTier) maxTier = unlockedFcatTiers + 1;
  }
  return TitleProgression(
    name: 'FastCAT',
    titles: [
      _bcat(),
      _dcat(),
      for (var n = 1; n <= maxTier; n++) fastCATTier(n),
    ],
  );
}

RuleNode akcFastCATTree() => RuleNode.gated(
      gate: (qs) => qs.any((q) => q.sport == Sport.fastCAT),
      child: RuleNode.group(
        title: 'FastCAT',
        children: [
          RuleNode.dynamic(emit: (qs, ov) => emitFastCATTiers(qs, ov)),
        ],
      ),
    );
