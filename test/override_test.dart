import 'package:flutter_test/flutter_test.dart';
import 'package:runbook/models/q.dart';
import 'package:runbook/rules/achievement.dart';
import 'package:runbook/rules/akc_agility.dart';
import 'package:runbook/rules/engine.dart';

void main() {
  Q novJww(DateTime d) => Q.create(
        dogId: 'dog1',
        date: d,
        agilityClass: AgilityClass.jww,
        level: AgilityLevel.novice,
      );

  Q masterStd(DateTime d, {int machPoints = 0}) => Q.create(
        dogId: 'dog1',
        date: d,
        agilityClass: AgilityClass.standard,
        level: AgilityLevel.master,
        machPoints: machPoints,
      );

  AchievementResult find(List<AchievementResult> rs, String id) =>
      rs.firstWhere((r) => r.achievement.id == id);

  group('Override pool counts', () {
    test('poolKey is shared across the bronze chain', () {
      final mx = regularStandardChain.titles.firstWhere((t) => t.id == 'akc.std.mx');
      final mxb = regularStandardChain.titles.firstWhere((t) => t.id == 'akc.std.mxb');
      final mxc = regularStandardChain.titles.firstWhere((t) => t.id == 'akc.std.mxc');
      expect(mx.pools, isNotEmpty);
      expect(mx.pools.first.key, equals(mxb.pools.first.key));
      expect(mx.pools.first.key, equals(mxc.pools.first.key));
    });

    test('Override bumps a title from in-progress to phantom-unlocked (no date)', () {
      final qs = [novJww(DateTime(2026, 1, 1))]; // 1 real Q
      final naj = find(
        RulesEngine().evaluate(qs),
        'akc.jww.naj',
      );
      expect(naj.isUnlocked, isFalse);
      expect(naj.have, 1);

      // Override to 3 → phantom unlocked.
      final key = naj.achievement.pools.first.key;
      final results = RulesEngine().evaluate(qs, overrides: {key: 3});
      final adj = find(results, 'akc.jww.naj');
      expect(adj.have, 3);
      expect(adj.need, 3);
      expect(adj.isUnlocked, isTrue, reason: 'have >= need → unlocked');
      expect(adj.unlockedAt, isNull,
          reason: 'no real Q crossed the line — phantom unlock');
    });

    test('Real count exceeding override leaves override silently dead', () {
      final qs = [
        novJww(DateTime(2026, 1, 1)),
        novJww(DateTime(2026, 1, 2)),
        novJww(DateTime(2026, 1, 3)),
      ];
      final naj = find(
        RulesEngine().evaluate(qs, overrides: {
          'agility::jww::novice::reg': 2, // override below real
        }),
        'akc.jww.naj',
      );
      // Real (3) wins via max(real, override) = 3. Override is dead weight.
      expect(naj.have, 3);
      expect(naj.unlockedAt, isNotNull,
          reason: 'real Qs crossed the line — real unlock with date');
    });

    test('Pool override shared across MX/MXB/MXS chain', () {
      // No real Qs. Override Master Std pool to 30 (past MX@10 and MXB@25).
      final results = RulesEngine().evaluate(<Q>[], overrides: {
        'agility::standard::master::reg': 30,
      });
      final mx = find(results, 'akc.std.mx');
      final mxb = find(results, 'akc.std.mxb');
      final mxs = find(results, 'akc.std.mxs');
      expect(mx.have, 30);
      expect(mx.isUnlocked, isTrue);
      expect(mxb.have, 30);
      expect(mxb.isUnlocked, isTrue);
      expect(mxs.have, 30);
      expect(mxs.isUnlocked, isFalse,
          reason: 'MXS needs 50; 30 < 50');
    });

    test('MACH points + QQ overrides phantom-unlock MACH', () {
      // Pretend the dog has one logged Master STD Q so the MACH
      // subtree is evaluated; user records AKC's total via override.
      final qs = [masterStd(DateTime(2026, 1, 1))];
      final results = RulesEngine().evaluate(qs, overrides: {
        'points::mach': 750,
        'dq::reg': 20,
      });
      final mach = find(results, 'akc.mach');
      expect(mach.isUnlocked, isTrue, reason: 'thresholds met by override');
      expect(mach.unlockedAt, isNull,
          reason: 'phantom unlock — no real Q crossed both thresholds');
    });

    test('PAX (QQs-only) phantom-unlocks via dq::pref override alone', () {
      // One preferred Master STD Q to open the PAX subtree.
      final pq = Q.create(
        dogId: 'dog1',
        date: DateTime(2026, 1, 1),
        agilityClass: AgilityClass.standard,
        level: AgilityLevel.master,
        preferred: true,
      );
      final results = RulesEngine().evaluate([pq], overrides: {
        'dq::pref': 20,
      });
      final pax = find(results, 'akc.pax');
      expect(pax.isUnlocked, isTrue);
      expect(pax.unlockedAt, isNull);
    });

    test('Triple-Q override unlocks TQX', () {
      // Need at least one Master FAST Q to open the TQX gate.
      final masterFast = Q.create(
        dogId: 'dog1',
        date: DateTime(2026, 1, 1),
        agilityClass: AgilityClass.fast,
        level: AgilityLevel.master,
      );
      final results = RulesEngine().evaluate([masterFast], overrides: {
        'tq::reg': 10,
      });
      final tqx = find(results, 'akc.tqx');
      expect(tqx.isUnlocked, isTrue);
      expect(tqx.unlockedAt, isNull);
    });

    test('Real Q + override stays at max(real, override)', () {
      // 5 real Master Std Qs, AKC reports 20 total.
      final qs = [for (var i = 0; i < 5; i++) masterStd(DateTime(2026, 1, 1 + i))];
      final results = RulesEngine().evaluate(qs, overrides: {
        'agility::standard::master::reg': 20,
      });
      final mx = find(results, 'akc.std.mx');
      expect(mx.have, 20);
      expect(mx.isUnlocked, isTrue);
      final mxb = find(results, 'akc.std.mxb');
      expect(mxb.have, 20);
      expect(mxb.isUnlocked, isFalse, reason: 'MXB needs 25');

      // Now user adds another real Q — total real = 6. Override unchanged
      // at 20. Effective stays 20 (no double-count).
      final qs2 = [...qs, masterStd(DateTime(2026, 1, 6))];
      final adj = find(
        RulesEngine().evaluate(qs2, overrides: {
          'agility::standard::master::reg': 20,
        }),
        'akc.std.mx',
      );
      expect(adj.have, 20, reason: 'max(6, 20) = 20 — no double-count');
    });
  });
}
