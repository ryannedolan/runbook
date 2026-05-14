import '../models/q.dart';
import 'achievement.dart';
import 'engine.dart';

// ---------------------------------------------------------------------------
// AKC agility achievement library, organized as TitleProgression chains
// plus champion titles.
//
// IMPORTANT: AKC's exact Q counts for the bronze/silver/gold/century
// titles vary by source. These numbers reflect the common
// "cumulative-Q" reading; corrections welcome.
// ---------------------------------------------------------------------------

LevelQCountTitle _t({
  required String id,
  required String title,
  required String description,
  required AgilityClass cls,
  required AgilityLevel level,
  required int n,
  bool preferred = false,
}) =>
    LevelQCountTitle(
      id: id,
      title: title,
      description: description,
      agilityClass: cls,
      level: level,
      qCountNeeded: n,
      preferred: preferred,
    );

/// Regular Standard chain: NA → OA → AX → MX → MXB → MXS → MXG → MXC.
final regularStandardChain = TitleProgression(
  name: 'Standard',
  titles: [
    _t(id: 'akc.std.na', title: 'NA', description: 'Novice Agility — 3 Q\'s in Novice Standard',
        cls: AgilityClass.standard, level: AgilityLevel.novice, n: 3),
    _t(id: 'akc.std.oa', title: 'OA', description: 'Open Agility — 3 Q\'s in Open Standard',
        cls: AgilityClass.standard, level: AgilityLevel.open, n: 3),
    _t(id: 'akc.std.ax', title: 'AX', description: 'Agility Excellent — 3 Q\'s in Excellent Standard',
        cls: AgilityClass.standard, level: AgilityLevel.excellent, n: 3),
    _t(id: 'akc.std.mx', title: 'MX', description: 'Master Agility Excellent — 10 Q\'s in Master Standard',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 10),
    _t(id: 'akc.std.mxb', title: 'MXB', description: 'Master Bronze — 25 Master Standard Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 25),
    _t(id: 'akc.std.mxs', title: 'MXS', description: 'Master Silver — 50 Master Standard Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 50),
    _t(id: 'akc.std.mxg', title: 'MXG', description: 'Master Gold — 100 Master Standard Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 100),
    _t(id: 'akc.std.mxc', title: 'MXC', description: 'Master Century — 150 Master Standard Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 150),
  ],
);

/// Regular JWW chain: NAJ → OAJ → AXJ → MXJ → MJB → MJS → MJG → MJC.
final regularJwwChain = TitleProgression(
  name: 'JWW',
  titles: [
    _t(id: 'akc.jww.naj', title: 'NAJ', description: 'Novice JWW — 3 Q\'s in Novice JWW',
        cls: AgilityClass.jww, level: AgilityLevel.novice, n: 3),
    _t(id: 'akc.jww.oaj', title: 'OAJ', description: 'Open JWW — 3 Q\'s in Open JWW',
        cls: AgilityClass.jww, level: AgilityLevel.open, n: 3),
    _t(id: 'akc.jww.axj', title: 'AXJ', description: 'Excellent JWW — 3 Q\'s in Excellent JWW',
        cls: AgilityClass.jww, level: AgilityLevel.excellent, n: 3),
    _t(id: 'akc.jww.mxj', title: 'MXJ', description: 'Master JWW — 10 Q\'s in Master JWW',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 10),
    _t(id: 'akc.jww.mjb', title: 'MJB', description: 'Master JWW Bronze — 25 Master JWW Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 25),
    _t(id: 'akc.jww.mjs', title: 'MJS', description: 'Master JWW Silver — 50 Master JWW Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 50),
    _t(id: 'akc.jww.mjg', title: 'MJG', description: 'Master JWW Gold — 100 Master JWW Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 100),
    _t(id: 'akc.jww.mjc', title: 'MJC', description: 'Master JWW Century — 150 Master JWW Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 150),
  ],
);

/// Preferred Standard chain: NAP → OAP → AXP → MXP → MXP2 → MXP3 → MXP4 → MXP5.
final preferredStandardChain = TitleProgression(
  name: 'Preferred Standard',
  titles: [
    _t(id: 'akc.pstd.nap', title: 'NAP', description: 'Novice Agility Preferred — 3 Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.novice, n: 3, preferred: true),
    _t(id: 'akc.pstd.oap', title: 'OAP', description: 'Open Agility Preferred — 3 Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.open, n: 3, preferred: true),
    _t(id: 'akc.pstd.axp', title: 'AXP', description: 'Excellent Agility Preferred — 3 Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.excellent, n: 3, preferred: true),
    _t(id: 'akc.pstd.mxp', title: 'MXP', description: 'Master Agility Preferred — 10 Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 10, preferred: true),
    _t(id: 'akc.pstd.mxp2', title: 'MXP2', description: 'Master Preferred 2 — 20 Master Preferred Std Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 20, preferred: true),
    _t(id: 'akc.pstd.mxp3', title: 'MXP3', description: 'Master Preferred 3 — 30 Master Preferred Std Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 30, preferred: true),
    _t(id: 'akc.pstd.mxp4', title: 'MXP4', description: 'Master Preferred 4 — 40 Master Preferred Std Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 40, preferred: true),
    _t(id: 'akc.pstd.mxp5', title: 'MXP5', description: 'Master Preferred 5 — 50 Master Preferred Std Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 50, preferred: true),
  ],
);

/// Preferred JWW chain: NJP → OJP → AJP → MJP → MJP2 → ... → MJP5.
final preferredJwwChain = TitleProgression(
  name: 'Preferred JWW',
  titles: [
    _t(id: 'akc.pjww.njp', title: 'NJP', description: 'Novice JWW Preferred — 3 Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.novice, n: 3, preferred: true),
    _t(id: 'akc.pjww.ojp', title: 'OJP', description: 'Open JWW Preferred — 3 Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.open, n: 3, preferred: true),
    _t(id: 'akc.pjww.ajp', title: 'AJP', description: 'Excellent JWW Preferred — 3 Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.excellent, n: 3, preferred: true),
    _t(id: 'akc.pjww.mjp', title: 'MJP', description: 'Master JWW Preferred — 10 Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 10, preferred: true),
    _t(id: 'akc.pjww.mjp2', title: 'MJP2', description: 'Master JWW Preferred 2 — 20 Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 20, preferred: true),
    _t(id: 'akc.pjww.mjp3', title: 'MJP3', description: 'Master JWW Preferred 3 — 30 Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 30, preferred: true),
    _t(id: 'akc.pjww.mjp4', title: 'MJP4', description: 'Master JWW Preferred 4 — 40 Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 40, preferred: true),
    _t(id: 'akc.pjww.mjp5', title: 'MJP5', description: 'Master JWW Preferred 5 — 50 Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 50, preferred: true),
  ],
);

/// Regular FAST chain: NF → OF → XF → MXF.
final regularFastChain = TitleProgression(
  name: 'FAST',
  titles: [
    _t(id: 'akc.fast.nf', title: 'NF', description: 'Novice FAST — 3 Q\'s in Novice FAST',
        cls: AgilityClass.fast, level: AgilityLevel.novice, n: 3),
    _t(id: 'akc.fast.of', title: 'OF', description: 'Open FAST — 3 Q\'s in Open FAST',
        cls: AgilityClass.fast, level: AgilityLevel.open, n: 3),
    _t(id: 'akc.fast.xf', title: 'XF', description: 'Excellent FAST — 3 Q\'s in Excellent FAST',
        cls: AgilityClass.fast, level: AgilityLevel.excellent, n: 3),
    _t(id: 'akc.fast.mxf', title: 'MXF', description: 'Master FAST — 10 Q\'s in Master FAST',
        cls: AgilityClass.fast, level: AgilityLevel.master, n: 10),
  ],
);

/// Preferred FAST chain: NFP → OFP → XFP → MFP.
final preferredFastChain = TitleProgression(
  name: 'FAST Preferred',
  titles: [
    _t(id: 'akc.fast.nfp', title: 'NFP', description: 'Novice FAST Preferred — 3 Q\'s',
        cls: AgilityClass.fast, level: AgilityLevel.novice, n: 3, preferred: true),
    _t(id: 'akc.fast.ofp', title: 'OFP', description: 'Open FAST Preferred — 3 Q\'s',
        cls: AgilityClass.fast, level: AgilityLevel.open, n: 3, preferred: true),
    _t(id: 'akc.fast.xfp', title: 'XFP', description: 'Excellent FAST Preferred — 3 Q\'s',
        cls: AgilityClass.fast, level: AgilityLevel.excellent, n: 3, preferred: true),
    _t(id: 'akc.fast.mfp', title: 'MFP', description: 'Master FAST Preferred — 10 Q\'s',
        cls: AgilityClass.fast, level: AgilityLevel.master, n: 10, preferred: true),
  ],
);

/// Time 2 Beat (Master only): T2B → T2BCH.
final t2bChain = TitleProgression(
  name: 'T2B',
  titles: [
    _t(id: 'akc.t2b.t2b', title: 'T2B', description: 'Time 2 Beat — 15 Master T2B Q\'s',
        cls: AgilityClass.t2b, level: AgilityLevel.master, n: 15),
    _t(id: 'akc.t2b.t2bch', title: 'T2BCH', description: 'Time 2 Beat Champion — 75 Master T2B Q\'s',
        cls: AgilityClass.t2b, level: AgilityLevel.master, n: 75),
  ],
);

/// Time 2 Beat Preferred: T2BP → T2BCHP.
final t2bPreferredChain = TitleProgression(
  name: 'T2B Preferred',
  titles: [
    _t(id: 'akc.t2b.t2bp', title: 'T2BP', description: 'Time 2 Beat Preferred — 15 Master T2B Preferred Q\'s',
        cls: AgilityClass.t2b, level: AgilityLevel.master, n: 15, preferred: true),
    _t(id: 'akc.t2b.t2bchp', title: 'T2BCHP', description: 'Time 2 Beat Preferred Champion — 75 Q\'s',
        cls: AgilityClass.t2b, level: AgilityLevel.master, n: 75, preferred: true),
  ],
);

/// Premier titles — each chain has just one title for now (PAD, PJD).
final premierStandardChain = TitleProgression(
  name: 'Premier Standard',
  titles: [
    PremierCountTitle(
      id: 'akc.premier.pad',
      title: 'PAD',
      description: 'Premier Standard Dog — 5 Premier Standard Q\'s',
      agilityClass: AgilityClass.premierStandard,
      qCountNeeded: 5,
    ),
  ],
);
final premierJwwChain = TitleProgression(
  name: 'Premier JWW',
  titles: [
    PremierCountTitle(
      id: 'akc.premier.pjd',
      title: 'PJD',
      description: 'Premier JWW Dog — 5 Premier JWW Q\'s',
      agilityClass: AgilityClass.premierJww,
      qCountNeeded: 5,
    ),
  ],
);

/// NAC qualification chain — one achievement per recent qualification year.
/// Each achievement evaluates its own window (Sep–Aug). Future years
/// remain in-progress until the dog qualifies; old years stay unlocked.
List<NACQualificationTitle> _nacTitles() {
  final thisYear = DateTime.now().year;
  // Surface the prior year (so we don't lose freshly-finished seasons),
  // this year, and next year.
  return [
    for (var y = thisYear - 1; y <= thisYear + 1; y++)
      NACQualificationTitle(qualificationYear: y),
  ];
}

final nacChain = TitleProgression(name: 'NAC', titles: _nacTitles());

/// MACH chain — MACH, MACH2, MACH3 (regular Master).
final machChain = TitleProgression(
  name: 'MACH',
  titles: [
    for (var n = 1; n <= 3; n++)
      ChampionTitle(
        id: n == 1 ? 'akc.mach' : 'akc.mach$n',
        title: n == 1 ? 'MACH' : 'MACH$n',
        description: n == 1
            ? 'Master Agility Champion — 750 MACH points + 20 double Qs'
            : 'MACH$n — ${n * 750} MACH points + ${n * 20} double Qs',
        multiplier: n,
        preferred: false,
      ),
  ],
);

/// PAX chain — PAX, PAX2, PAX3 (preferred Master).
final paxChain = TitleProgression(
  name: 'PAX',
  titles: [
    for (var n = 1; n <= 3; n++)
      ChampionTitle(
        id: n == 1 ? 'akc.pax' : 'akc.pax$n',
        title: n == 1 ? 'PAX' : 'PAX$n',
        description: n == 1
            ? 'Preferred Agility Excellent — 750 PACH points + 20 PDQs'
            : 'PAX$n — ${n * 750} PACH points + ${n * 20} preferred double Qs',
        multiplier: n,
        preferred: true,
      ),
  ],
);

/// All chains in the order we usually want to walk them.
final allAkcChains = <TitleProgression>[
  regularStandardChain,
  regularJwwChain,
  machChain,
  nacChain,
  regularFastChain,
  t2bChain,
  preferredStandardChain,
  preferredJwwChain,
  paxChain,
  preferredFastChain,
  t2bPreferredChain,
  premierStandardChain,
  premierJwwChain,
];

/// Look up the chain that contains a given achievement, if any.
TitleProgression? chainOf(Achievement a) {
  for (final c in allAkcChains) {
    if (c.titles.contains(a)) return c;
  }
  return null;
}

/// The decision tree, with gates that skip whole sub-trees when no
/// matching Qs exist.
RuleNode akcAgilityTree() => RuleNode.group(
      title: 'AKC Agility',
      children: [
        // Regular Std + JWW — always evaluated (everyone starts here).
        for (final t in regularStandardChain.titles) RuleNode.leaf(t),
        for (final t in regularJwwChain.titles) RuleNode.leaf(t),

        // FAST — only evaluated if there's at least one FAST Q.
        RuleNode.gated(
          gate: (qs) => qs.any((q) => q.agilityClass == AgilityClass.fast),
          child: RuleNode.group(title: 'FAST', children: [
            for (final t in regularFastChain.titles) RuleNode.leaf(t),
            for (final t in preferredFastChain.titles) RuleNode.leaf(t),
          ]),
        ),

        // T2B — only evaluated if there's at least one T2B Q.
        RuleNode.gated(
          gate: (qs) => qs.any((q) => q.agilityClass == AgilityClass.t2b),
          child: RuleNode.group(title: 'T2B', children: [
            for (final t in t2bChain.titles) RuleNode.leaf(t),
            for (final t in t2bPreferredChain.titles) RuleNode.leaf(t),
          ]),
        ),

        // Preferred Std + JWW — only evaluated if there's at least one
        // preferred Q.
        RuleNode.gated(
          gate: (qs) => qs.any((q) => q.preferred),
          child: RuleNode.group(title: 'Preferred', children: [
            for (final t in preferredStandardChain.titles) RuleNode.leaf(t),
            for (final t in preferredJwwChain.titles) RuleNode.leaf(t),
          ]),
        ),

        // Premier — only evaluated if there's at least one Premier Q.
        RuleNode.gated(
          gate: (qs) => qs.any((q) => q.agilityClass.isPremier),
          child: RuleNode.group(title: 'Premier', children: [
            for (final t in premierStandardChain.titles) RuleNode.leaf(t),
            for (final t in premierJwwChain.titles) RuleNode.leaf(t),
          ]),
        ),

        // MACH — needs a regular Master Q to even be worth evaluating.
        RuleNode.gated(
          gate: (qs) => qs.any((q) =>
              q.level == AgilityLevel.master &&
              !q.preferred &&
              (q.agilityClass == AgilityClass.standard ||
                  q.agilityClass == AgilityClass.jww)),
          child: RuleNode.group(
            title: 'MACH',
            children: [
              for (final t in machChain.titles) RuleNode.leaf(t),
              // NAC qualification reuses the same MACH-points + QQ
              // machinery, gated alongside.
              for (final t in nacChain.titles) RuleNode.leaf(t),
            ],
          ),
        ),

        // PAX — needs a preferred Master Q.
        RuleNode.gated(
          gate: (qs) => qs.any((q) =>
              q.level == AgilityLevel.master &&
              q.preferred &&
              (q.agilityClass == AgilityClass.standard ||
                  q.agilityClass == AgilityClass.jww)),
          child: RuleNode.group(
            title: 'PAX',
            children: [for (final t in paxChain.titles) RuleNode.leaf(t)],
          ),
        ),
      ],
    );
