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
/// Lifetime tier counts (Ch. 2 §3): each tier is the prior tier + 25.
final regularStandardChain = TitleProgression(
  name: 'Standard',
  titles: [
    _t(id: 'akc.std.na', title: 'NA', description: 'Novice Agility — 3 Q\'s in Novice Standard',
        cls: AgilityClass.standard, level: AgilityLevel.novice, n: 3),
    _t(id: 'akc.std.oa', title: 'OA', description: 'Open Agility — 3 Q\'s in Open Standard',
        cls: AgilityClass.standard, level: AgilityLevel.open, n: 3),
    _t(id: 'akc.std.ax', title: 'AX', description: 'Agility Excellent — 3 Q\'s in Excellent Standard',
        cls: AgilityClass.standard, level: AgilityLevel.excellent, n: 3),
    _t(id: 'akc.std.mx', title: 'MX', description: 'Master Agility Excellent — 10 Master Standard Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 10),
    _t(id: 'akc.std.mxb', title: 'MXB', description: 'Master Bronze — 25 Master Standard Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 25),
    _t(id: 'akc.std.mxs', title: 'MXS', description: 'Master Silver — MXB + 25 (50 total)',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 50),
    _t(id: 'akc.std.mxg', title: 'MXG', description: 'Master Gold — MXS + 25 (75 total)',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 75),
    _t(id: 'akc.std.mxc', title: 'MXC', description: 'Master Century — MXG + 25 (100 total)',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 100),
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
    _t(id: 'akc.jww.mxj', title: 'MXJ', description: 'Master Excellent Jumper — 10 Master JWW Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 10),
    _t(id: 'akc.jww.mjb', title: 'MJB', description: 'Master JWW Bronze — 25 Master JWW Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 25),
    _t(id: 'akc.jww.mjs', title: 'MJS', description: 'Master JWW Silver — MJB + 25 (50 total)',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 50),
    _t(id: 'akc.jww.mjg', title: 'MJG', description: 'Master JWW Gold — MJS + 25 (75 total)',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 75),
    _t(id: 'akc.jww.mjc', title: 'MJC', description: 'Master JWW Century — MJG + 25 (100 total)',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 100),
  ],
);

/// Preferred Standard chain: NAP → OAP → AXP → MXP → MXP2..5 → MXPB
/// (lifetime tier) → MXPS → MXPG → MXPC.
///
/// Two parallel sub-chains progress on the same Q stream:
///   • MXP/MXP2/MXP3/... — every +10 Master Std Pref Qs.
///   • MXPB/MXPS/MXPG/MXPC — lifetime tiers at 25/50/75/100.
final preferredStandardChain = TitleProgression(
  name: 'Preferred Standard',
  titles: [
    _t(id: 'akc.pstd.nap', title: 'NAP', description: 'Novice Agility Preferred — 3 Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.novice, n: 3, preferred: true),
    _t(id: 'akc.pstd.oap', title: 'OAP', description: 'Open Agility Preferred — 3 Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.open, n: 3, preferred: true),
    _t(id: 'akc.pstd.axp', title: 'AXP', description: 'Excellent Agility Preferred — 3 Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.excellent, n: 3, preferred: true),
    _t(id: 'akc.pstd.mxp', title: 'MXP', description: 'Master Agility Excellent Preferred — 10 Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 10, preferred: true),
    _t(id: 'akc.pstd.mxp2', title: 'MXP2', description: 'Master Preferred 2 — 20 Master Std Pref Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 20, preferred: true),
    _t(id: 'akc.pstd.mxp3', title: 'MXP3', description: 'Master Preferred 3 — 30 Master Std Pref Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 30, preferred: true),
    _t(id: 'akc.pstd.mxp4', title: 'MXP4', description: 'Master Preferred 4 — 40 Master Std Pref Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 40, preferred: true),
    _t(id: 'akc.pstd.mxp5', title: 'MXP5', description: 'Master Preferred 5 — 50 Master Std Pref Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 50, preferred: true),
    _t(id: 'akc.pstd.mxpb', title: 'MXPB', description: 'Master Bronze Agility Preferred — 25 Master Std Pref Q\'s',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 25, preferred: true),
    _t(id: 'akc.pstd.mxps', title: 'MXPS', description: 'Master Silver Agility Preferred — MXPB + 25 (50 total)',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 50, preferred: true),
    _t(id: 'akc.pstd.mxpg', title: 'MXPG', description: 'Master Gold Agility Preferred — MXPS + 25 (75 total)',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 75, preferred: true),
    _t(id: 'akc.pstd.mxpc', title: 'MXPC', description: 'Master Century Agility Preferred — MXPG + 25 (100 total)',
        cls: AgilityClass.standard, level: AgilityLevel.master, n: 100, preferred: true),
  ],
);

/// Preferred JWW chain: NJP → OJP → AJP → MJP → MJP2..5 → MJPB
/// (lifetime tier) → MJPS → MJPG → MJPC.
final preferredJwwChain = TitleProgression(
  name: 'Preferred JWW',
  titles: [
    _t(id: 'akc.pjww.njp', title: 'NJP', description: 'Novice JWW Preferred — 3 Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.novice, n: 3, preferred: true),
    _t(id: 'akc.pjww.ojp', title: 'OJP', description: 'Open JWW Preferred — 3 Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.open, n: 3, preferred: true),
    _t(id: 'akc.pjww.ajp', title: 'AJP', description: 'Excellent JWW Preferred — 3 Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.excellent, n: 3, preferred: true),
    _t(id: 'akc.pjww.mjp', title: 'MJP', description: 'Master Excellent Jumper Preferred — 10 Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 10, preferred: true),
    _t(id: 'akc.pjww.mjp2', title: 'MJP2', description: 'Master JWW Preferred 2 — 20 Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 20, preferred: true),
    _t(id: 'akc.pjww.mjp3', title: 'MJP3', description: 'Master JWW Preferred 3 — 30 Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 30, preferred: true),
    _t(id: 'akc.pjww.mjp4', title: 'MJP4', description: 'Master JWW Preferred 4 — 40 Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 40, preferred: true),
    _t(id: 'akc.pjww.mjp5', title: 'MJP5', description: 'Master JWW Preferred 5 — 50 Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 50, preferred: true),
    _t(id: 'akc.pjww.mjpb', title: 'MJPB', description: 'Master Bronze JWW Preferred — 25 Q\'s',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 25, preferred: true),
    _t(id: 'akc.pjww.mjps', title: 'MJPS', description: 'Master Silver JWW Preferred — MJPB + 25 (50 total)',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 50, preferred: true),
    _t(id: 'akc.pjww.mjpg', title: 'MJPG', description: 'Master Gold JWW Preferred — MJPS + 25 (75 total)',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 75, preferred: true),
    _t(id: 'akc.pjww.mjpc', title: 'MJPC', description: 'Master Century JWW Preferred — MJPG + 25 (100 total)',
        cls: AgilityClass.jww, level: AgilityLevel.master, n: 100, preferred: true),
  ],
);

/// Regular FAST chain: NF → OF → XF → MXF → MFB → MFS → MFG → MFC.
/// Lifetime tiers (Ch. 2 §3) are 25/50/75/100 Master FAST Qs.
final regularFastChain = TitleProgression(
  name: 'FAST',
  titles: [
    _t(id: 'akc.fast.nf', title: 'NF', description: 'Agility FAST Novice — 3 Novice FAST Q\'s (50+ pts)',
        cls: AgilityClass.fast, level: AgilityLevel.novice, n: 3),
    _t(id: 'akc.fast.of', title: 'OF', description: 'Agility FAST Open — 3 Open FAST Q\'s (55+ pts)',
        cls: AgilityClass.fast, level: AgilityLevel.open, n: 3),
    _t(id: 'akc.fast.xf', title: 'XF', description: 'Agility FAST Excellent — 3 Excellent FAST Q\'s (60+ pts)',
        cls: AgilityClass.fast, level: AgilityLevel.excellent, n: 3),
    _t(id: 'akc.fast.mxf', title: 'MXF', description: 'Agility Master FAST Excellent — 10 Master FAST Q\'s',
        cls: AgilityClass.fast, level: AgilityLevel.master, n: 10),
    _t(id: 'akc.fast.mfb', title: 'MFB', description: 'Master Bronze FAST — 25 Master FAST Q\'s',
        cls: AgilityClass.fast, level: AgilityLevel.master, n: 25),
    _t(id: 'akc.fast.mfs', title: 'MFS', description: 'Master Silver FAST — MFB + 25 (50 total)',
        cls: AgilityClass.fast, level: AgilityLevel.master, n: 50),
    _t(id: 'akc.fast.mfg', title: 'MFG', description: 'Master Gold FAST — MFS + 25 (75 total)',
        cls: AgilityClass.fast, level: AgilityLevel.master, n: 75),
    _t(id: 'akc.fast.mfc', title: 'MFC', description: 'Master Century FAST — MFG + 25 (100 total)',
        cls: AgilityClass.fast, level: AgilityLevel.master, n: 100),
  ],
);

/// Preferred FAST chain: NFP → OFP → XFP → MFP → MFPB → MFPS → MFPG → MFPC.
final preferredFastChain = TitleProgression(
  name: 'FAST Preferred',
  titles: [
    _t(id: 'akc.fast.nfp', title: 'NFP', description: 'Agility FAST Novice Preferred — 3 Q\'s',
        cls: AgilityClass.fast, level: AgilityLevel.novice, n: 3, preferred: true),
    _t(id: 'akc.fast.ofp', title: 'OFP', description: 'Agility FAST Open Preferred — 3 Q\'s',
        cls: AgilityClass.fast, level: AgilityLevel.open, n: 3, preferred: true),
    _t(id: 'akc.fast.xfp', title: 'XFP', description: 'Agility FAST Excellent Preferred — 3 Q\'s',
        cls: AgilityClass.fast, level: AgilityLevel.excellent, n: 3, preferred: true),
    _t(id: 'akc.fast.mfp', title: 'MFP', description: 'Agility Master FAST Excellent Preferred — 10 Q\'s',
        cls: AgilityClass.fast, level: AgilityLevel.master, n: 10, preferred: true),
    _t(id: 'akc.fast.mfpb', title: 'MFPB', description: 'Master Bronze FAST Preferred — 25 Q\'s',
        cls: AgilityClass.fast, level: AgilityLevel.master, n: 25, preferred: true),
    _t(id: 'akc.fast.mfps', title: 'MFPS', description: 'Master Silver FAST Preferred — MFPB + 25 (50 total)',
        cls: AgilityClass.fast, level: AgilityLevel.master, n: 50, preferred: true),
    _t(id: 'akc.fast.mfpg', title: 'MFPG', description: 'Master Gold FAST Preferred — MFPS + 25 (75 total)',
        cls: AgilityClass.fast, level: AgilityLevel.master, n: 75, preferred: true),
    _t(id: 'akc.fast.mfpc', title: 'MFPC', description: 'Master Century FAST Preferred — MFPG + 25 (100 total)',
        cls: AgilityClass.fast, level: AgilityLevel.master, n: 100, preferred: true),
  ],
);

/// Time 2 Beat: T2B → T2B2 → T2B3 → ... Each cycle adds 15 fresh
/// qualifying scores. (Rulebook also requires 100 points per cycle —
/// not enforced today; tracked via Q.score is a TODO.)
final t2bChain = TitleProgression(
  name: 'T2B',
  titles: [
    for (var n = 1; n <= 5; n++)
      _t(
          id: n == 1 ? 'akc.t2b.t2b' : 'akc.t2b.t2b$n',
          title: n == 1 ? 'T2B' : 'T2B$n',
          description: n == 1
              ? 'Time 2 Beat — 15 T2B Q\'s + 100 points'
              : 'T2B$n — ${15 * n} T2B Q\'s + ${100 * n} points',
          cls: AgilityClass.t2b,
          level: AgilityLevel.master,
          n: 15 * n),
  ],
);

/// Time 2 Beat Preferred: T2BP → T2BP2 → ...
final t2bPreferredChain = TitleProgression(
  name: 'T2B Preferred',
  titles: [
    for (var n = 1; n <= 5; n++)
      _t(
          id: n == 1 ? 'akc.t2b.t2bp' : 'akc.t2b.t2bp$n',
          title: n == 1 ? 'T2BP' : 'T2BP$n',
          description: n == 1
              ? 'Time 2 Beat Preferred — 15 T2B Pref Q\'s + 100 points'
              : 'T2BP$n — ${15 * n} T2B Pref Q\'s + ${100 * n} points',
          cls: AgilityClass.t2b,
          level: AgilityLevel.master,
          n: 15 * n,
          preferred: true),
  ],
);

/// Triple Q: TQX (regular) and TQXP (preferred). 10 days where the dog
/// earned a Master Std + Master JWW + Master FAST Q on the same day.
final tqxChain = TitleProgression(
  name: 'TQX',
  titles: [
    TripleQTitle(
      id: 'akc.tqx',
      title: 'TQX',
      description: 'Triple Q Excellent — 10 Master Std + JWW + FAST same-day Q\'s',
      preferred: false,
    ),
  ],
);
final tqxPreferredChain = TitleProgression(
  name: 'TQX Preferred',
  titles: [
    TripleQTitle(
      id: 'akc.tqxp',
      title: 'TQXP',
      description: 'Triple Q Excellent Preferred — 10 Master Std + JWW + FAST Pref same-day Q\'s',
      preferred: true,
    ),
  ],
);

/// Premier titles (Ch. 11 §6): PAD/PJD = 25 Q's including 5 from
/// placing in the top 25% of the dogs in the dog's jump height.
///
/// We only enforce the count today; the "5 in top 25%" gate requires
/// per-Q top-quarter info that the model doesn't yet capture (TODO).
final premierStandardChain = TitleProgression(
  name: 'Premier Standard',
  titles: [
    PremierCountTitle(
      id: 'akc.premier.pad',
      title: 'PAD',
      description: 'Premier Agility Dog — 25 Premier Std Q\'s (5 in top 25%)',
      agilityClass: AgilityClass.premierStandard,
      qCountNeeded: 25,
    ),
  ],
);
final premierJwwChain = TitleProgression(
  name: 'Premier JWW',
  titles: [
    PremierCountTitle(
      id: 'akc.premier.pjd',
      title: 'PJD',
      description: 'Premier Jumpers Dog — 25 Premier JWW Q\'s (5 in top 25%)',
      agilityClass: AgilityClass.premierJww,
      qCountNeeded: 25,
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

/// PAX chain (Ch. 8 §7) — Preferred Agility Excellent. 20 preferred 2Qs
/// per level. NO points required (this is the distinguishing
/// characteristic vs. PACH).
final paxChain = TitleProgression(
  name: 'PAX',
  titles: [
    for (var n = 1; n <= 3; n++)
      ChampionTitle(
        id: n == 1 ? 'akc.pax' : 'akc.pax$n',
        title: n == 1 ? 'PAX' : 'PAX$n',
        description: n == 1
            ? 'Preferred Agility Excellent — 20 preferred double Qs (no points required)'
            : 'PAX$n — ${n * 20} preferred double Qs',
        multiplier: n,
        preferred: true,
        pointsPerLevel: 0,
      ),
  ],
);

/// PACH chain (Ch. 8 §8) — Preferred Agility Champion. 750 PACH points
/// + 20 preferred 2Qs per level. Mirrors MACH for the Preferred division.
final pachChain = TitleProgression(
  name: 'PACH',
  titles: [
    for (var n = 1; n <= 3; n++)
      ChampionTitle(
        id: n == 1 ? 'akc.pach' : 'akc.pach$n',
        title: n == 1 ? 'PACH' : 'PACH$n',
        description: n == 1
            ? 'Preferred Agility Champion — 750 PACH points + 20 preferred double Qs'
            : 'PACH$n — ${n * 750} PACH points + ${n * 20} preferred double Qs',
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
  tqxChain,
  t2bChain,
  preferredStandardChain,
  preferredJwwChain,
  paxChain,
  pachChain,
  preferredFastChain,
  tqxPreferredChain,
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

        // PAX + PACH — need a preferred Master Std/JWW Q. PAX is 2Qs
        // only; PACH is points + 2Qs.
        RuleNode.gated(
          gate: (qs) => qs.any((q) =>
              q.level == AgilityLevel.master &&
              q.preferred &&
              (q.agilityClass == AgilityClass.standard ||
                  q.agilityClass == AgilityClass.jww)),
          child: RuleNode.group(
            title: 'PAX/PACH',
            children: [
              for (final t in paxChain.titles) RuleNode.leaf(t),
              for (final t in pachChain.titles) RuleNode.leaf(t),
            ],
          ),
        ),

        // TQX / TQXP — gated on having a Master FAST Q (regular or
        // preferred), since the Std + JWW components are usually
        // present once a dog is doing Master FAST.
        RuleNode.gated(
          gate: (qs) => qs.any((q) =>
              q.level == AgilityLevel.master &&
              q.agilityClass == AgilityClass.fast),
          child: RuleNode.group(title: 'TQX', children: [
            for (final t in tqxChain.titles) RuleNode.leaf(t),
            for (final t in tqxPreferredChain.titles) RuleNode.leaf(t),
          ]),
        ),
      ],
    );
