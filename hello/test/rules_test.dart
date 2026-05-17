import 'package:flutter_test/flutter_test.dart';
import 'package:runbook/models/q.dart';
import 'package:runbook/rules/achievement.dart';
import 'package:runbook/rules/engine.dart';

void main() {
  Q q({
    required AgilityClass cls,
    required AgilityLevel level,
    DateTime? date,
    int machPoints = 0,
  }) =>
      Q.create(
        dogId: 'dog1',
        date: date ?? DateTime(2026, 1, 1),
        agilityClass: cls,
        level: level,
        machPoints: machPoints,
      );

  AchievementResult find(List<AchievementResult> results, String id) =>
      results.firstWhere((r) => r.achievement.id == id);

  group('NAJ direct unlock', () {
    test('3 Novice JWW Qs unlocks NAJ', () {
      final qs = [
        q(cls: AgilityClass.jww, level: AgilityLevel.novice, date: DateTime(2026, 1, 1)),
        q(cls: AgilityClass.jww, level: AgilityLevel.novice, date: DateTime(2026, 1, 2)),
        q(cls: AgilityClass.jww, level: AgilityLevel.novice, date: DateTime(2026, 1, 3)),
      ];
      final results = RulesEngine().evaluate(qs);
      final naj = find(results, 'akc.jww.naj');
      expect(naj.isUnlocked, isTrue);
      expect(naj.impliedBy, isNull);
      expect(naj.unlockedAt, DateTime(2026, 1, 3));
    });

    test('2 Novice JWW Qs leaves NAJ in progress', () {
      final qs = [
        q(cls: AgilityClass.jww, level: AgilityLevel.novice),
        q(cls: AgilityClass.jww, level: AgilityLevel.novice),
      ];
      final results = RulesEngine().evaluate(qs);
      final naj = find(results, 'akc.jww.naj');
      expect(naj.isUnlocked, isFalse);
      expect(naj.have, 2);
      expect(naj.need, 3);
    });
  });

  group('Implication: higher-level Q implies lower titles', () {
    test('A single Master JWW Q implies NAJ, OAJ, AXJ', () {
      final masterDate = DateTime(2026, 5, 1);
      final qs = [
        q(cls: AgilityClass.jww, level: AgilityLevel.master, date: masterDate),
      ];
      final results = RulesEngine().evaluate(qs);
      final naj = find(results, 'akc.jww.naj');
      final oaj = find(results, 'akc.jww.oaj');
      final axj = find(results, 'akc.jww.axj');

      expect(naj.isUnlocked, isTrue);
      expect(naj.impliedBy, 'Master');
      expect(naj.unlockedAt, masterDate);

      expect(oaj.isUnlocked, isTrue);
      expect(oaj.impliedBy, 'Master');

      expect(axj.isUnlocked, isTrue);
      expect(axj.impliedBy, 'Master');
    });

    test('An Excellent JWW Q implies NAJ and OAJ but not AXJ', () {
      final qs = [
        q(cls: AgilityClass.jww, level: AgilityLevel.excellent),
      ];
      final results = RulesEngine().evaluate(qs);
      expect(find(results, 'akc.jww.naj').isUnlocked, isTrue);
      expect(find(results, 'akc.jww.oaj').isUnlocked, isTrue);
      expect(find(results, 'akc.jww.axj').isUnlocked, isFalse);
      expect(find(results, 'akc.jww.axj').have, 1);
    });

    test(
        'A Master scentwork Q implies Novice / Advanced / Excellent at the same element',
        () {
      final masterDate = DateTime(2026, 5, 1);
      final qs = [
        Q.create(
          dogId: 'dog1',
          date: masterDate,
          // Placeholder agility class/level — scentwork Qs ignore them.
          agilityClass: AgilityClass.fast,
          level: AgilityLevel.novice,
          sport: Sport.scentwork,
          scentElement: ScentElement.container,
          scentLevel: ScentLevel.master,
        ),
      ];
      final results = RulesEngine().evaluate(qs);
      final novice = find(results, 'akc.sw.container.novice');
      final advanced = find(results, 'akc.sw.container.advanced');
      final excellent = find(results, 'akc.sw.container.excellent');
      final master = find(results, 'akc.sw.container.master');
      expect(novice.isUnlocked, isTrue);
      expect(novice.impliedBy, 'Master');
      expect(advanced.isUnlocked, isTrue);
      expect(advanced.impliedBy, 'Master');
      expect(excellent.isUnlocked, isTrue);
      expect(excellent.impliedBy, 'Master');
      // The Master title itself needs 3 direct Qs — not implied.
      expect(master.isUnlocked, isFalse);
      expect(master.have, 1);
    });

    test(
        'Implication is scoped to the same element — Container Master does '
        'not imply Interior Novice',
        () {
      final qs = [
        Q.create(
          dogId: 'dog1',
          date: DateTime(2026, 5, 1),
          agilityClass: AgilityClass.fast,
          level: AgilityLevel.novice,
          sport: Sport.scentwork,
          scentElement: ScentElement.container,
          scentLevel: ScentLevel.master,
        ),
      ];
      final results = RulesEngine().evaluate(qs);
      // No Interior Qs → Interior chain shouldn't surface at all.
      expect(
        results.where((r) => r.achievement.id.startsWith('akc.sw.interior.')),
        isEmpty,
      );
    });

    test('Std and JWW are independent', () {
      final qs = [
        q(cls: AgilityClass.standard, level: AgilityLevel.master),
      ];
      final results = RulesEngine().evaluate(qs);
      expect(find(results, 'akc.std.na').isUnlocked, isTrue);
      // No JWW Qs at all — no JWW titles should appear.
      expect(
        results.where((r) => r.achievement.id.startsWith('akc.jww.')),
        isEmpty,
      );
    });
  });

  group('Preferred chain', () {
    test('3 Novice Preferred JWW Qs unlocks NJP, not NAJ', () {
      final qs = [
        for (var i = 0; i < 3; i++)
          Q.create(
            dogId: 'd',
            date: DateTime(2026, 1, i + 1),
            agilityClass: AgilityClass.jww,
            level: AgilityLevel.novice,
            preferred: true,
          ),
      ];
      final results = RulesEngine().evaluate(qs);
      expect(find(results, 'akc.pjww.njp').isUnlocked, isTrue);
      // No regular Q → NAJ should not appear at all.
      expect(results.where((r) => r.achievement.id == 'akc.jww.naj'), isEmpty);
    });

    test('Master Preferred Std Q implies MXP, MXP not MX', () {
      final qs = [
        Q.create(
          dogId: 'd',
          date: DateTime(2026, 5, 1),
          agilityClass: AgilityClass.standard,
          level: AgilityLevel.master,
          preferred: true,
        ),
      ];
      final results = RulesEngine().evaluate(qs);
      // No regular Std Qs → no NA/OA/AX/MX results at all.
      expect(results.where((r) => r.achievement.id.startsWith('akc.std.')), isEmpty);
      // Preferred chain — NAP/OAP/AXP implied, MXP in progress.
      expect(find(results, 'akc.pstd.nap').isUnlocked, isTrue);
      expect(find(results, 'akc.pstd.oap').isUnlocked, isTrue);
      expect(find(results, 'akc.pstd.axp').isUnlocked, isTrue);
      expect(find(results, 'akc.pstd.mxp').isUnlocked, isFalse);
      expect(find(results, 'akc.pstd.mxp').have, 1);
    });
  });

  group('Premier titles', () {
    test('25 Premier Standard Qs unlocks PAD', () {
      final qs = [
        for (var i = 0; i < 25; i++)
          Q.create(
            dogId: 'd',
            date: DateTime(2026, 4, 1).add(Duration(days: i)),
            agilityClass: AgilityClass.premierStandard,
            level: AgilityLevel.master,
          ),
      ];
      final results = RulesEngine().evaluate(qs);
      expect(find(results, 'akc.premier.pad').isUnlocked, isTrue);
      // PJD has no Qs → no PJD entry.
      expect(results.where((r) => r.achievement.id == 'akc.premier.pjd'), isEmpty);
    });
  });

  group('Master tier titles', () {
    test('25 Master Std Qs unlocks both MX and MXB', () {
      final qs = [
        for (var i = 0; i < 25; i++)
          Q.create(
            dogId: 'd',
            date: DateTime(2026, 1, 1).add(Duration(days: i)),
            agilityClass: AgilityClass.standard,
            level: AgilityLevel.master,
          ),
      ];
      final results = RulesEngine().evaluate(qs);
      expect(find(results, 'akc.std.mx').isUnlocked, isTrue);
      expect(find(results, 'akc.std.mxb').isUnlocked, isTrue);
      expect(find(results, 'akc.std.mxs').isUnlocked, isFalse);
      expect(find(results, 'akc.std.mxs').have, 25);
      expect(find(results, 'akc.std.mxs').need, 50);
    });
  });

  group('MACH gating', () {
    test('MACH does not appear without a Master-level Q', () {
      final qs = [
        q(cls: AgilityClass.standard, level: AgilityLevel.excellent),
        q(cls: AgilityClass.jww, level: AgilityLevel.excellent),
      ];
      final results = RulesEngine().evaluate(qs);
      final mach = results.where((r) => r.achievement.id == 'akc.mach');
      expect(mach, isEmpty, reason: 'MACH gate should suppress evaluation');
    });

    test('MACH appears in-progress with a Master Q', () {
      final qs = [
        q(cls: AgilityClass.standard, level: AgilityLevel.master, machPoints: 10),
      ];
      final results = RulesEngine().evaluate(qs);
      final mach = find(results, 'akc.mach');
      expect(mach.isUnlocked, isFalse);
      expect(mach.hasProgress, isTrue);
    });

    test('FAST chain: 3 Novice FAST Qs unlocks NF', () {
      final qs = [
        for (var i = 0; i < 3; i++)
          q(cls: AgilityClass.fast, level: AgilityLevel.novice, date: DateTime(2026, 1, 1 + i)),
      ];
      final results = RulesEngine().evaluate(qs);
      final nf = find(results, 'akc.fast.nf');
      expect(nf.isUnlocked, isTrue);
    });

    test('FAST Preferred chain: 3 Novice FAST Preferred Qs unlocks NFP, not NF', () {
      final qs = [
        for (var i = 0; i < 3; i++)
          Q.create(
            dogId: 'dog1',
            date: DateTime(2026, 1, 1 + i),
            agilityClass: AgilityClass.fast,
            level: AgilityLevel.novice,
            preferred: true,
          ),
      ];
      final results = RulesEngine().evaluate(qs);
      final nfp = find(results, 'akc.fast.nfp');
      expect(nfp.isUnlocked, isTrue);
      expect(results.where((r) => r.achievement.id == 'akc.fast.nf'), isEmpty);
    });

    test('FastCAT: 150 cumulative points unlocks BCAT', () {
      final qs = [
        for (var i = 0; i < 9; i++)
          Q.create(
            dogId: 'dog1',
            date: DateTime(2026, 1, 1 + i),
            agilityClass: AgilityClass.fast, // placeholder
            level: AgilityLevel.novice,
            sport: Sport.fastCAT,
            score: 17,
          ),
      ];
      final results = RulesEngine().evaluate(qs);
      final bcat = results.firstWhere((r) => r.achievement.id == 'akc.fastcat.bcat');
      expect(bcat.isUnlocked, isTrue);
    });

    test('Scentwork: 3 Novice Container Qs unlocks SCN', () {
      final qs = [
        for (var i = 0; i < 3; i++)
          Q.create(
            dogId: 'dog1',
            date: DateTime(2026, 1, 1 + i),
            agilityClass: AgilityClass.fast, // placeholder
            level: AgilityLevel.novice,
            sport: Sport.scentwork,
            scentElement: ScentElement.container,
            scentLevel: ScentLevel.novice,
          ),
      ];
      final results = RulesEngine().evaluate(qs);
      final scn = results.firstWhere((r) => r.achievement.id == 'akc.sw.container.novice');
      expect(scn.isUnlocked, isTrue);
    });

    test('NAC qualifies on 7 QQs + 550 MACH points in window (2027 rules)', () {
      // NAC 2027 window: Dec 1, 2025 - Nov 30, 2026.
      // Build 7 calendar days each with a Master Std + Master JWW,
      // total MACH points >= 550.
      final qs = <Q>[];
      for (var i = 0; i < 7; i++) {
        final d = DateTime(2026, 5, 1 + i);
        qs.add(Q.create(
          dogId: 'dog1',
          date: d,
          agilityClass: AgilityClass.standard,
          level: AgilityLevel.master,
          machPoints: 40,
        ));
        qs.add(Q.create(
          dogId: 'dog1',
          date: d,
          agilityClass: AgilityClass.jww,
          level: AgilityLevel.master,
          machPoints: 40,
        ));
      }
      // Top up points past 550 with a solo Master Std Q.
      qs.add(Q.create(
        dogId: 'dog1',
        date: DateTime(2026, 6, 1),
        agilityClass: AgilityClass.standard,
        level: AgilityLevel.master,
        machPoints: 30,
      ));
      final results = RulesEngine().evaluate(qs);
      final nac = results.firstWhere(
          (r) => r.achievement.id == 'akc.nac.2027');
      expect(nac.isUnlocked, isTrue);
    });

    test('NAC: each Premier leg adds 15 NAC points', () {
      // 5 DQ days + 2 Premier STD + 2 Premier JWW. That's 5 + 2 (pair
      // substitution) = 7 effective QQs. Points: 5 days × (40+40) = 400
      // from masters + 4 premier × 15 = 60. Total 460 — short. Add a few
      // bonus master Qs to get past 550.
      final qs = <Q>[];
      for (var i = 0; i < 5; i++) {
        final d = DateTime(2026, 5, 1 + i);
        qs.add(Q.create(dogId: 'd', date: d, agilityClass: AgilityClass.standard, level: AgilityLevel.master, machPoints: 40));
        qs.add(Q.create(dogId: 'd', date: d, agilityClass: AgilityClass.jww, level: AgilityLevel.master, machPoints: 40));
      }
      qs.add(Q.create(dogId: 'd', date: DateTime(2026, 6, 1), agilityClass: AgilityClass.premierStandard, level: AgilityLevel.master));
      qs.add(Q.create(dogId: 'd', date: DateTime(2026, 6, 2), agilityClass: AgilityClass.premierStandard, level: AgilityLevel.master));
      qs.add(Q.create(dogId: 'd', date: DateTime(2026, 6, 3), agilityClass: AgilityClass.premierJww, level: AgilityLevel.master));
      qs.add(Q.create(dogId: 'd', date: DateTime(2026, 6, 4), agilityClass: AgilityClass.premierJww, level: AgilityLevel.master));
      // Bonus master Q's to push points past 550.
      for (var i = 0; i < 4; i++) {
        qs.add(Q.create(dogId: 'd', date: DateTime(2026, 7, 1 + i), agilityClass: AgilityClass.standard, level: AgilityLevel.master, machPoints: 50));
      }
      final results = RulesEngine().evaluate(qs);
      final nac = results.firstWhere((r) => r.achievement.id == 'akc.nac.2027');
      expect(nac.isUnlocked, isTrue);
    });

    test('NAC Preferred qualifies separately from regular', () {
      // 7 preferred DQ days + enough PACH points.
      final qs = <Q>[];
      for (var i = 0; i < 7; i++) {
        final d = DateTime(2026, 4, 1 + i);
        qs.add(Q.create(
          dogId: 'd',
          date: d,
          agilityClass: AgilityClass.standard,
          level: AgilityLevel.master,
          preferred: true,
          machPoints: 50,
        ));
        qs.add(Q.create(
          dogId: 'd',
          date: d,
          agilityClass: AgilityClass.jww,
          level: AgilityLevel.master,
          preferred: true,
          machPoints: 50,
        ));
      }
      final results = RulesEngine().evaluate(qs);
      final preferredNac = results.firstWhere(
          (r) => r.achievement.id == 'akc.nac.preferred.2027');
      expect(preferredNac.isUnlocked, isTrue);
      // Regular NAC should NOT be unlocked — no regular master Qs.
      expect(
        results.where((r) => r.achievement.id == 'akc.nac.2027' && r.isUnlocked),
        isEmpty,
      );
    });

    test('T2B chain: 15 Master T2B Qs unlocks T2B title', () {
      final qs = [
        for (var i = 0; i < 15; i++)
          q(cls: AgilityClass.t2b, level: AgilityLevel.master, date: DateTime(2026, 1, 1 + i)),
      ];
      final results = RulesEngine().evaluate(qs);
      final t2b = find(results, 'akc.t2b.t2b');
      expect(t2b.isUnlocked, isTrue);
    });

    test('MACH unlocks at threshold', () {
      final qs = <Q>[];
      // 20 double-Q days, each with a Std and JWW Master Q worth ~40 mach
      // points (total 800 > 750).
      for (var i = 0; i < 20; i++) {
        final d = DateTime(2026, 1, 1).add(Duration(days: i * 7));
        qs.add(q(cls: AgilityClass.standard, level: AgilityLevel.master, date: d, machPoints: 20));
        qs.add(q(cls: AgilityClass.jww, level: AgilityLevel.master, date: d, machPoints: 20));
      }
      final results = RulesEngine().evaluate(qs);
      final mach = find(results, 'akc.mach');
      expect(mach.isUnlocked, isTrue);
    });
  });
}
