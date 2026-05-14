import '../models/q.dart';
import 'achievement.dart';
import 'engine.dart';

/// AKC FastCAT title chain — BCAT → DCAT → FCAT → FCAT2 → FCAT3 → …
/// Titles are awarded for cumulative points (50/100 yard dash speed
/// converted to MPH × breed handicap = points per run, summed over the
/// dog's career).
final fastCATChain = TitleProgression(
  name: 'FastCAT',
  titles: [
    PointAccumulationTitle(
      id: 'akc.fastcat.bcat',
      title: 'BCAT',
      description: 'Beginner Coursing Ability Test — 150 FastCAT points.',
      sport: 'AKC FastCAT',
      sportFilter: Sport.fastCAT,
      pointsNeeded: 150,
    ),
    PointAccumulationTitle(
      id: 'akc.fastcat.dcat',
      title: 'DCAT',
      description: 'Direct Coursing Ability Test — 500 FastCAT points.',
      sport: 'AKC FastCAT',
      sportFilter: Sport.fastCAT,
      pointsNeeded: 500,
    ),
    PointAccumulationTitle(
      id: 'akc.fastcat.fcat',
      title: 'FCAT',
      description: 'FastCAT — 1000 FastCAT points.',
      sport: 'AKC FastCAT',
      sportFilter: Sport.fastCAT,
      pointsNeeded: 1000,
    ),
    for (var n = 2; n <= 5; n++)
      PointAccumulationTitle(
        id: 'akc.fastcat.fcat$n',
        title: 'FCAT$n',
        description: 'FastCAT $n — ${n * 1000} cumulative points.',
        sport: 'AKC FastCAT',
        sportFilter: Sport.fastCAT,
        pointsNeeded: n * 1000,
      ),
  ],
);

RuleNode akcFastCATTree() => RuleNode.gated(
      gate: (qs) => qs.any((q) => q.sport == Sport.fastCAT),
      child: RuleNode.group(
        title: 'FastCAT',
        children: [for (final t in fastCATChain.titles) RuleNode.leaf(t)],
      ),
    );
