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
      expect(naj.impliedBy, AgilityLevel.master);
      expect(naj.unlockedAt, masterDate);

      expect(oaj.isUnlocked, isTrue);
      expect(oaj.impliedBy, AgilityLevel.master);

      expect(axj.isUnlocked, isTrue);
      expect(axj.impliedBy, AgilityLevel.master);
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
    test('5 Premier Standard Qs unlocks PAD', () {
      final qs = [
        for (var i = 0; i < 5; i++)
          Q.create(
            dogId: 'd',
            date: DateTime(2026, 4, i + 1),
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

    test('NAC qualifies on 4 QQs + 400 MACH points in window', () {
      final year = DateTime.now().year;
      // Build 4 calendar days each with a Master Std and a Master JWW Q,
      // total MACH points >= 400.
      final qs = <Q>[];
      for (var i = 0; i < 4; i++) {
        final d = DateTime(year, 5, 1 + i);
        qs.add(Q.create(
          dogId: 'dog1',
          date: d,
          agilityClass: AgilityClass.standard,
          level: AgilityLevel.master,
          machPoints: 60,
        ));
        qs.add(Q.create(
          dogId: 'dog1',
          date: d,
          agilityClass: AgilityClass.jww,
          level: AgilityLevel.master,
          machPoints: 60,
        ));
      }
      // Top up points past 400 with a 5th solo Master Std Q.
      qs.add(Q.create(
        dogId: 'dog1',
        date: DateTime(year, 6, 1),
        agilityClass: AgilityClass.standard,
        level: AgilityLevel.master,
        machPoints: 30,
      ));
      final results = RulesEngine().evaluate(qs);
      final nac = results.firstWhere(
          (r) => r.achievement.id == 'akc.nac.$year');
      expect(nac.isUnlocked, isTrue);
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
