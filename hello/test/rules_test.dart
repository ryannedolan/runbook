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
      final naj = find(results, 'akc.agility.jww.naj');
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
      final naj = find(results, 'akc.agility.jww.naj');
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
      final naj = find(results, 'akc.agility.jww.naj');
      final oaj = find(results, 'akc.agility.jww.oaj');
      final axj = find(results, 'akc.agility.jww.axj');

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
      expect(find(results, 'akc.agility.jww.naj').isUnlocked, isTrue);
      expect(find(results, 'akc.agility.jww.oaj').isUnlocked, isTrue);
      expect(find(results, 'akc.agility.jww.axj').isUnlocked, isFalse);
      expect(find(results, 'akc.agility.jww.axj').have, 1);
    });

    test('Std and JWW are independent', () {
      final qs = [
        q(cls: AgilityClass.standard, level: AgilityLevel.master),
      ];
      final results = RulesEngine().evaluate(qs);
      expect(find(results, 'akc.agility.std.na').isUnlocked, isTrue);
      // No JWW Qs at all — no JWW titles should appear.
      expect(
        results.where((r) => r.achievement.id.startsWith('akc.agility.jww.')),
        isEmpty,
      );
    });
  });

  group('MACH gating', () {
    test('MACH does not appear without a Master-level Q', () {
      final qs = [
        q(cls: AgilityClass.standard, level: AgilityLevel.excellent),
        q(cls: AgilityClass.jww, level: AgilityLevel.excellent),
      ];
      final results = RulesEngine().evaluate(qs);
      final mach = results.where((r) => r.achievement.id == 'akc.agility.mach');
      expect(mach, isEmpty, reason: 'MACH gate should suppress evaluation');
    });

    test('MACH appears in-progress with a Master Q', () {
      final qs = [
        q(cls: AgilityClass.standard, level: AgilityLevel.master, machPoints: 10),
      ];
      final results = RulesEngine().evaluate(qs);
      final mach = find(results, 'akc.agility.mach');
      expect(mach.isUnlocked, isFalse);
      expect(mach.hasProgress, isTrue);
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
      final mach = find(results, 'akc.agility.mach');
      expect(mach.isUnlocked, isTrue);
    });
  });
}
