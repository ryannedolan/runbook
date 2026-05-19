import '../models/q.dart';
import 'achievement.dart';
import 'engine.dart';

/// AKC Scentwork title chains. Each (element, level) combination is
/// earned with 3 Qs.
///
/// One chain per element (Container → Interior → Exterior → Buried),
/// each containing 5 level titles (Novice → Detective).

const _elementChainNames = {
  ScentElement.container: 'Container',
  ScentElement.interior: 'Interior',
  ScentElement.exterior: 'Exterior',
  ScentElement.buried: 'Buried',
};

const _levelShortByLevel = {
  ScentLevel.novice: 'N',
  ScentLevel.advanced: 'A',
  ScentLevel.excellent: 'E',
  ScentLevel.master: 'M',
  ScentLevel.detective: 'D',
};

String _titleFor(ScentElement el, ScentLevel lvl) =>
    'S${el.short}${_levelShortByLevel[lvl]!}';

ScentElementLevelTitle _t(ScentElement el, ScentLevel lvl) =>
    ScentElementLevelTitle(
      id: 'akc.sw.${el.name}.${lvl.name}',
      title: _titleFor(el, lvl),
      description:
          'Scentwork ${el.label} ${lvl.label} — 3 Q\'s at this element + level.',
      element: el,
      level: lvl,
    );

TitleProgression _chainFor(ScentElement el) => TitleProgression(
      name: 'Scentwork ${_elementChainNames[el]!}',
      titles: [for (final lvl in ScentLevel.values) _t(el, lvl)],
    );

final scentContainerChain = _chainFor(ScentElement.container);
final scentInteriorChain = _chainFor(ScentElement.interior);
final scentExteriorChain = _chainFor(ScentElement.exterior);
final scentBuriedChain = _chainFor(ScentElement.buried);

final allScentChains = <TitleProgression>[
  scentContainerChain,
  scentInteriorChain,
  scentExteriorChain,
  scentBuriedChain,
];

RuleNode akcScentworkTree() => RuleNode.gated(
      gate: (qs) => qs.any((q) => q.sport == Sport.scentwork),
      child: RuleNode.group(
        title: 'Scentwork',
        children: [
          for (final chain in allScentChains)
            RuleNode.group(
              title: chain.name,
              children: [for (final t in chain.titles) RuleNode.leaf(t)],
            ),
        ],
      ),
    );
