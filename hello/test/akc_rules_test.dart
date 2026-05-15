// Rulebook-traceable tests. Numbers and title names follow AKC's
// "Regulations for Agility Trials" (REAGIL). Section/Chapter references
// in test names come from the rulebook so we can audit drift.
//
// Citations: https://images.akc.org/pdf/rulebooks/REAGIL.pdf
//   Ch. 2 §2  — Regular titles + MACH
//   Ch. 2 §3  — Lifetime achievement (Bronze/Silver/Gold/Century)
//   Ch. 8     — Preferred classes, Preferred lifetime tiers, PAX, PACH
//   Ch. 9 §9  — FAST title table + TQX
//   Ch. 10 §8 — T2B / T2BP titles (15 Qs + 100 points per cycle)
//   Ch. 11 §6 — Premier titles (PAD/PJD)
//   Ch. 12 §1 — National Agility Champion (NAC)

import 'package:flutter_test/flutter_test.dart';
import 'package:runbook/models/q.dart';
import 'package:runbook/rules/achievement.dart';
import 'package:runbook/rules/engine.dart';

void main() {
  // Helper: build a generic Q.
  Q q({
    required AgilityClass cls,
    required AgilityLevel level,
    DateTime? date,
    bool preferred = false,
    int machPoints = 0,
    int? score,
  }) =>
      Q.create(
        dogId: 'dog1',
        date: date ?? DateTime(2026, 1, 1),
        agilityClass: cls,
        level: level,
        preferred: preferred,
        machPoints: machPoints,
        score: score,
      );

  // Build N consecutive-day Qs.
  List<Q> manyQs(
    int n, {
    required AgilityClass cls,
    required AgilityLevel level,
    bool preferred = false,
    int machPoints = 0,
  }) =>
      [
        for (var i = 0; i < n; i++)
          q(
            cls: cls,
            level: level,
            date: DateTime(2026, 1, 1).add(Duration(days: i)),
            preferred: preferred,
            machPoints: machPoints,
          ),
      ];

  AchievementResult? maybeFind(List<AchievementResult> rs, String id) {
    for (final r in rs) {
      if (r.achievement.id == id) return r;
    }
    return null;
  }

  AchievementResult find(List<AchievementResult> rs, String id) {
    final r = maybeFind(rs, id);
    expect(r, isNotNull, reason: 'Achievement $id not found');
    return r!;
  }

  // ============================================================
  // Ch. 2 §2 — Regular Standard chain
  // ============================================================

  group('Regular Standard chain (Ch. 2 §2)', () {
    test('NA: 3 Novice Standard Qs', () {
      final rs = RulesEngine().evaluate(
          manyQs(3, cls: AgilityClass.standard, level: AgilityLevel.novice));
      expect(find(rs, 'akc.std.na').isUnlocked, isTrue);
    });

    test('OA: 3 Open Standard Qs', () {
      final rs = RulesEngine().evaluate(
          manyQs(3, cls: AgilityClass.standard, level: AgilityLevel.open));
      expect(find(rs, 'akc.std.oa').isUnlocked, isTrue);
    });

    test('AX: 3 Excellent Standard Qs', () {
      final rs = RulesEngine().evaluate(
          manyQs(3, cls: AgilityClass.standard, level: AgilityLevel.excellent));
      expect(find(rs, 'akc.std.ax').isUnlocked, isTrue);
    });

    test('MX: 10 Master Standard Qs', () {
      final rs = RulesEngine().evaluate(
          manyQs(10, cls: AgilityClass.standard, level: AgilityLevel.master));
      expect(find(rs, 'akc.std.mx').isUnlocked, isTrue);
    });

    test('MXB: 25 Master Standard Qs', () {
      final rs = RulesEngine().evaluate(
          manyQs(25, cls: AgilityClass.standard, level: AgilityLevel.master));
      expect(find(rs, 'akc.std.mxb').isUnlocked, isTrue);
    });

    test('MXS: 50 Master Standard Qs', () {
      final rs = RulesEngine().evaluate(
          manyQs(50, cls: AgilityClass.standard, level: AgilityLevel.master));
      expect(find(rs, 'akc.std.mxs').isUnlocked, isTrue);
    });

    test('MXG: 75 Master Standard Qs (rulebook: MXS + 25)', () {
      final rs = RulesEngine().evaluate(
          manyQs(75, cls: AgilityClass.standard, level: AgilityLevel.master));
      expect(find(rs, 'akc.std.mxg').isUnlocked, isTrue);
    });

    test('MXG: NOT unlocked at 74 Qs', () {
      final rs = RulesEngine().evaluate(
          manyQs(74, cls: AgilityClass.standard, level: AgilityLevel.master));
      expect(find(rs, 'akc.std.mxg').isUnlocked, isFalse);
    });

    test('MXC: 100 Master Standard Qs (rulebook: MXG + 25)', () {
      final rs = RulesEngine().evaluate(
          manyQs(100, cls: AgilityClass.standard, level: AgilityLevel.master));
      expect(find(rs, 'akc.std.mxc').isUnlocked, isTrue);
    });
  });

  // ============================================================
  // Ch. 2 §2 — Regular JWW chain (mirrors Standard)
  // ============================================================

  group('Regular JWW chain (Ch. 2 §2)', () {
    test('NAJ: 3 Novice JWW Qs', () {
      final rs = RulesEngine().evaluate(
          manyQs(3, cls: AgilityClass.jww, level: AgilityLevel.novice));
      expect(find(rs, 'akc.jww.naj').isUnlocked, isTrue);
    });

    test('MXJ: 10 Master JWW Qs', () {
      final rs = RulesEngine().evaluate(
          manyQs(10, cls: AgilityClass.jww, level: AgilityLevel.master));
      expect(find(rs, 'akc.jww.mxj').isUnlocked, isTrue);
    });

    test('MJB: 25 Master JWW Qs', () {
      final rs = RulesEngine().evaluate(
          manyQs(25, cls: AgilityClass.jww, level: AgilityLevel.master));
      expect(find(rs, 'akc.jww.mjb').isUnlocked, isTrue);
    });

    test('MJG: 75 Master JWW Qs', () {
      final rs = RulesEngine().evaluate(
          manyQs(75, cls: AgilityClass.jww, level: AgilityLevel.master));
      expect(find(rs, 'akc.jww.mjg').isUnlocked, isTrue);
    });

    test('MJC: 100 Master JWW Qs', () {
      final rs = RulesEngine().evaluate(
          manyQs(100, cls: AgilityClass.jww, level: AgilityLevel.master));
      expect(find(rs, 'akc.jww.mjc').isUnlocked, isTrue);
    });
  });

  // ============================================================
  // Ch. 8 — Preferred chains
  // ============================================================

  group('Preferred Standard chain (Ch. 8)', () {
    test('NAP: 3 Novice Std Pref Qs', () {
      final rs = RulesEngine().evaluate(manyQs(3,
          cls: AgilityClass.standard,
          level: AgilityLevel.novice,
          preferred: true));
      expect(find(rs, 'akc.pstd.nap').isUnlocked, isTrue);
    });

    test('MXP: 10 Master Std Pref Qs', () {
      final rs = RulesEngine().evaluate(manyQs(10,
          cls: AgilityClass.standard,
          level: AgilityLevel.master,
          preferred: true));
      expect(find(rs, 'akc.pstd.mxp').isUnlocked, isTrue);
    });

    test('MXP2..MXP5: each step is +10 Master Std Pref Qs', () {
      for (final entry in [(20, 'mxp2'), (30, 'mxp3'), (40, 'mxp4'), (50, 'mxp5')]) {
        final n = entry.$1;
        final id = 'akc.pstd.${entry.$2}';
        final rs = RulesEngine().evaluate(manyQs(n,
            cls: AgilityClass.standard,
            level: AgilityLevel.master,
            preferred: true));
        expect(find(rs, id).isUnlocked, isTrue,
            reason: '$id should unlock at $n Qs');
      }
    });

    test('MXPB: 25 Master Std Pref Qs (lifetime tier)', () {
      final rs = RulesEngine().evaluate(manyQs(25,
          cls: AgilityClass.standard,
          level: AgilityLevel.master,
          preferred: true));
      expect(find(rs, 'akc.pstd.mxpb').isUnlocked, isTrue);
    });

    test('MXPC: 100 Master Std Pref Qs (lifetime tier)', () {
      final rs = RulesEngine().evaluate(manyQs(100,
          cls: AgilityClass.standard,
          level: AgilityLevel.master,
          preferred: true));
      expect(find(rs, 'akc.pstd.mxpc').isUnlocked, isTrue);
    });
  });

  group('Preferred JWW chain (Ch. 8)', () {
    test('MJPB: 25 Master JWW Pref Qs', () {
      final rs = RulesEngine().evaluate(manyQs(25,
          cls: AgilityClass.jww,
          level: AgilityLevel.master,
          preferred: true));
      expect(find(rs, 'akc.pjww.mjpb').isUnlocked, isTrue);
    });

    test('MJPC: 100 Master JWW Pref Qs', () {
      final rs = RulesEngine().evaluate(manyQs(100,
          cls: AgilityClass.jww,
          level: AgilityLevel.master,
          preferred: true));
      expect(find(rs, 'akc.pjww.mjpc').isUnlocked, isTrue);
    });
  });

  // ============================================================
  // Ch. 9 — FAST chain
  // ============================================================

  group('FAST chain (Ch. 9 §9)', () {
    test('NF: 3 Novice FAST Qs', () {
      final rs = RulesEngine().evaluate(
          manyQs(3, cls: AgilityClass.fast, level: AgilityLevel.novice));
      expect(find(rs, 'akc.fast.nf').isUnlocked, isTrue);
    });

    test('MXF: 10 Master FAST Qs', () {
      final rs = RulesEngine().evaluate(
          manyQs(10, cls: AgilityClass.fast, level: AgilityLevel.master));
      expect(find(rs, 'akc.fast.mxf').isUnlocked, isTrue);
    });

    test('MFB: 25 Master FAST Qs (lifetime tier)', () {
      final rs = RulesEngine().evaluate(
          manyQs(25, cls: AgilityClass.fast, level: AgilityLevel.master));
      expect(find(rs, 'akc.fast.mfb').isUnlocked, isTrue);
    });

    test('MFC: 100 Master FAST Qs (lifetime tier)', () {
      final rs = RulesEngine().evaluate(
          manyQs(100, cls: AgilityClass.fast, level: AgilityLevel.master));
      expect(find(rs, 'akc.fast.mfc').isUnlocked, isTrue);
    });

    test('MFP: 10 Master FAST Pref Qs', () {
      final rs = RulesEngine().evaluate(manyQs(10,
          cls: AgilityClass.fast,
          level: AgilityLevel.master,
          preferred: true));
      expect(find(rs, 'akc.fast.mfp').isUnlocked, isTrue);
    });

    test('MFPB: 25 Master FAST Pref Qs (lifetime tier)', () {
      final rs = RulesEngine().evaluate(manyQs(25,
          cls: AgilityClass.fast,
          level: AgilityLevel.master,
          preferred: true));
      expect(find(rs, 'akc.fast.mfpb').isUnlocked, isTrue);
    });
  });

  // ============================================================
  // Ch. 9 §9 — TQX (Triple Q)
  // ============================================================

  group('TQX (Ch. 9 §9)', () {
    test('TQX: 10 days with Master Std + JWW + FAST Qs', () {
      final qs = <Q>[];
      for (var i = 0; i < 10; i++) {
        final d = DateTime(2026, 1, 1).add(Duration(days: i));
        qs.add(q(cls: AgilityClass.standard, level: AgilityLevel.master, date: d));
        qs.add(q(cls: AgilityClass.jww, level: AgilityLevel.master, date: d));
        qs.add(q(cls: AgilityClass.fast, level: AgilityLevel.master, date: d));
      }
      final rs = RulesEngine().evaluate(qs);
      expect(find(rs, 'akc.tqx').isUnlocked, isTrue);
    });

    test('TQX: NOT unlocked when only 9 triple days', () {
      final qs = <Q>[];
      for (var i = 0; i < 9; i++) {
        final d = DateTime(2026, 1, 1).add(Duration(days: i));
        qs.add(q(cls: AgilityClass.standard, level: AgilityLevel.master, date: d));
        qs.add(q(cls: AgilityClass.jww, level: AgilityLevel.master, date: d));
        qs.add(q(cls: AgilityClass.fast, level: AgilityLevel.master, date: d));
      }
      final rs = RulesEngine().evaluate(qs);
      expect(maybeFind(rs, 'akc.tqx')?.isUnlocked ?? false, isFalse);
    });

    test('TQXP: 10 days with Master Std/JWW/FAST Pref Qs', () {
      final qs = <Q>[];
      for (var i = 0; i < 10; i++) {
        final d = DateTime(2026, 1, 1).add(Duration(days: i));
        qs.add(q(cls: AgilityClass.standard, level: AgilityLevel.master, date: d, preferred: true));
        qs.add(q(cls: AgilityClass.jww, level: AgilityLevel.master, date: d, preferred: true));
        qs.add(q(cls: AgilityClass.fast, level: AgilityLevel.master, date: d, preferred: true));
      }
      final rs = RulesEngine().evaluate(qs);
      expect(find(rs, 'akc.tqxp').isUnlocked, isTrue);
    });
  });

  // ============================================================
  // Ch. 10 §8 — T2B / T2BP
  // ============================================================

  group('T2B chain (Ch. 10 §8)', () {
    test('T2B: 15 T2B Qs', () {
      final rs = RulesEngine().evaluate(
          manyQs(15, cls: AgilityClass.t2b, level: AgilityLevel.master));
      expect(find(rs, 'akc.t2b.t2b').isUnlocked, isTrue);
    });

    test('T2B2: 30 T2B Qs (15 + 15)', () {
      final rs = RulesEngine().evaluate(
          manyQs(30, cls: AgilityClass.t2b, level: AgilityLevel.master));
      expect(find(rs, 'akc.t2b.t2b2').isUnlocked, isTrue);
    });

    test('T2BP: 15 T2B Preferred Qs', () {
      final rs = RulesEngine().evaluate(manyQs(15,
          cls: AgilityClass.t2b,
          level: AgilityLevel.master,
          preferred: true));
      expect(find(rs, 'akc.t2b.t2bp').isUnlocked, isTrue);
    });

    test('T2BCH does not exist (rulebook never defines it)', () {
      final rs = RulesEngine().evaluate(
          manyQs(75, cls: AgilityClass.t2b, level: AgilityLevel.master));
      expect(maybeFind(rs, 'akc.t2b.t2bch'), isNull);
    });
  });

  // ============================================================
  // Ch. 11 §6 — Premier (count only — top-25% gating is TODO)
  // ============================================================

  group('Premier chains (Ch. 11 §6)', () {
    test('PAD: 25 Premier Std Qs', () {
      final rs = RulesEngine().evaluate(
          manyQs(25, cls: AgilityClass.premierStandard, level: AgilityLevel.master));
      expect(find(rs, 'akc.premier.pad').isUnlocked, isTrue);
    });

    test('PAD: NOT unlocked at 24 Qs', () {
      final rs = RulesEngine().evaluate(
          manyQs(24, cls: AgilityClass.premierStandard, level: AgilityLevel.master));
      expect(find(rs, 'akc.premier.pad').isUnlocked, isFalse);
    });

    test('PJD: 25 Premier JWW Qs', () {
      final rs = RulesEngine().evaluate(
          manyQs(25, cls: AgilityClass.premierJww, level: AgilityLevel.master));
      expect(find(rs, 'akc.premier.pjd').isUnlocked, isTrue);
    });
  });

  // ============================================================
  // Ch. 2 §2 — MACH chain
  // ============================================================

  group('MACH chain (Ch. 2 §2)', () {
    test('MACH: 750 points + 20 2Qs', () {
      final qs = <Q>[];
      for (var i = 0; i < 20; i++) {
        final d = DateTime(2026, 1, 1).add(Duration(days: i * 7));
        qs.add(q(cls: AgilityClass.standard, level: AgilityLevel.master, date: d, machPoints: 20));
        qs.add(q(cls: AgilityClass.jww, level: AgilityLevel.master, date: d, machPoints: 20));
      }
      final rs = RulesEngine().evaluate(qs);
      expect(find(rs, 'akc.mach').isUnlocked, isTrue);
    });
  });

  // ============================================================
  // Ch. 8 §7 — PAX (2Qs ONLY, no points required)
  // Ch. 8 §8 — PACH (points + 2Qs)
  // ============================================================

  group('PAX chain (Ch. 8 §7) — 2Qs only', () {
    test('PAX: 20 preferred 2Qs unlocks WITHOUT any points', () {
      final qs = <Q>[];
      for (var i = 0; i < 20; i++) {
        final d = DateTime(2026, 1, 1).add(Duration(days: i * 7));
        qs.add(q(
          cls: AgilityClass.standard,
          level: AgilityLevel.master,
          date: d,
          preferred: true,
          machPoints: 0,
        ));
        qs.add(q(
          cls: AgilityClass.jww,
          level: AgilityLevel.master,
          date: d,
          preferred: true,
          machPoints: 0,
        ));
      }
      final rs = RulesEngine().evaluate(qs);
      expect(find(rs, 'akc.pax').isUnlocked, isTrue);
    });

    test('PAX2: 40 preferred 2Qs', () {
      final qs = <Q>[];
      for (var i = 0; i < 40; i++) {
        final d = DateTime(2026, 1, 1).add(Duration(days: i * 7));
        qs.add(q(cls: AgilityClass.standard, level: AgilityLevel.master, date: d, preferred: true));
        qs.add(q(cls: AgilityClass.jww, level: AgilityLevel.master, date: d, preferred: true));
      }
      final rs = RulesEngine().evaluate(qs);
      expect(find(rs, 'akc.pax2').isUnlocked, isTrue);
    });
  });

  group('PACH chain (Ch. 8 §8) — points + 2Qs', () {
    test('PACH: 750 PACH points + 20 2Qs unlocks', () {
      final qs = <Q>[];
      for (var i = 0; i < 20; i++) {
        final d = DateTime(2026, 1, 1).add(Duration(days: i * 7));
        qs.add(q(
          cls: AgilityClass.standard,
          level: AgilityLevel.master,
          date: d,
          preferred: true,
          machPoints: 20,
        ));
        qs.add(q(
          cls: AgilityClass.jww,
          level: AgilityLevel.master,
          date: d,
          preferred: true,
          machPoints: 20,
        ));
      }
      final rs = RulesEngine().evaluate(qs);
      expect(find(rs, 'akc.pach').isUnlocked, isTrue);
    });
  });
}
