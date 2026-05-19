import 'package:flutter_test/flutter_test.dart';
import 'package:runbook/models/dog.dart';
import 'package:runbook/models/q.dart';
import 'package:runbook/scan/ribbon_parser.dart';

void main() {
  final geddy = Dog.create(callName: 'Geddy Lee');
  final neil = Dog.create(callName: 'Neil');
  final dogs = [geddy, neil];

  group('Sport detection', () {
    test('agility STD Novice', () {
      final p = RibbonParser(dogs: dogs).parse(
        'Geddy Lee\nStandard Novice A\n11/15/2015\nTime 41.41\n1st Place',
      );
      expect(p.q.sport, Sport.akcAgility);
      expect(p.q.agilityClass, AgilityClass.standard);
      expect(p.q.level, AgilityLevel.novice);
      expect(p.q.placement, 1);
      expect(p.q.timeSeconds, closeTo(41.41, 0.01));
      expect(p.dogId, geddy.id);
      expect(p.matchedFields, containsAll({'sport', 'dog', 'date', 'placement', 'timeSeconds'}));
    });

    test('agility Master JWW Preferred', () {
      final p = RibbonParser(dogs: dogs).parse(
        'Neil\nJumpers With Weaves\nMaster Preferred\nMay 3, 2024\n2nd Place\nMACH Points: 8',
      );
      expect(p.q.sport, Sport.akcAgility);
      expect(p.q.agilityClass, AgilityClass.jww);
      expect(p.q.level, AgilityLevel.master);
      expect(p.q.preferred, true);
      expect(p.q.placement, 2);
      expect(p.q.machPoints, 8);
      expect(p.q.date.year, 2024);
      expect(p.q.date.month, 5);
      expect(p.q.date.day, 3);
    });

    test('FastCAT', () {
      final p = RibbonParser(dogs: dogs).parse(
        'Geddy Lee\nFastCAT\nTrial 1\n22.4 MPH\n8.45 sec\n17 points',
      );
      expect(p.q.sport, Sport.fastCAT);
      expect(p.q.timeSeconds, closeTo(8.45, 0.01));
      expect(p.q.score, 17);
      expect(p.q.trial, 'Trial 1');
    });

    test('Scentwork Container Novice', () {
      final p = RibbonParser(dogs: dogs).parse(
        'Geddy Lee\nScent Work\nContainer Novice\n2023-04-12\nSearch Time 0:35.45',
      );
      expect(p.q.sport, Sport.scentwork);
      expect(p.q.scentElement, ScentElement.container);
      expect(p.q.scentLevel, ScentLevel.novice);
      expect(p.q.timeSeconds, closeTo(35.45, 0.01));
    });

    test('Shorthand JW MAS P → JWW Master Preferred', () {
      final p = RibbonParser(dogs: dogs).parse(
        'Geddy Lee\nJW MAS P\n5/3/2024\n1st',
      );
      expect(p.q.sport, Sport.akcAgility);
      expect(p.q.agilityClass, AgilityClass.jww);
      expect(p.q.level, AgilityLevel.master);
      expect(p.q.preferred, true);
      expect(p.isUseful, isTrue);
    });

    test('Shorthand STD NOV → Standard Novice', () {
      final p = RibbonParser(dogs: dogs).parse(
        'Neil\nSTD NOV\n3/2/2026',
      );
      expect(p.q.sport, Sport.akcAgility);
      expect(p.q.agilityClass, AgilityClass.standard);
      expect(p.q.level, AgilityLevel.novice);
      expect(p.q.preferred, false);
      expect(p.isUseful, isTrue);
    });

    test('Bare Master Excellent (no class word) still useful via dog+level', () {
      final p = RibbonParser(dogs: dogs).parse(
        'Geddy Lee\nExcellent B\n5/3/2024',
      );
      expect(p.q.sport, Sport.akcAgility);
      expect(p.q.level, AgilityLevel.excellent);
      // No class keyword → defaults to standard (user can fix in review).
      expect(p.isUseful, isTrue);
    });

    test('Premier Standard forces Master level', () {
      final p = RibbonParser(dogs: dogs).parse(
        'Neil\nPremier Standard\nApril 12, 2025',
      );
      expect(p.q.sport, Sport.akcAgility);
      expect(p.q.agilityClass, AgilityClass.premierStandard);
      expect(p.q.level, AgilityLevel.master);
      expect(p.q.preferred, false);
    });

    test('PRM is Premier — not Preferred', () {
      final p = RibbonParser(dogs: dogs).parse(
        'Geddy Lee\nPRM JW\n5/3/2024\n1st',
      );
      expect(p.q.agilityClass, AgilityClass.premierJww);
      expect(p.q.preferred, false,
          reason: 'PRM != P — Premier and Preferred are distinct dimensions');
      expect(p.q.level, AgilityLevel.master);
    });

    test('PRM JW P → Premier JWW Preferred', () {
      final p = RibbonParser(dogs: dogs).parse(
        'Geddy Lee\nPRM JW P\n5/3/2024',
      );
      expect(p.q.agilityClass, AgilityClass.premierJww);
      expect(p.q.preferred, true);
      expect(p.q.level, AgilityLevel.master);
    });

    test('Mas alone resolves to Master', () {
      final p = RibbonParser(dogs: dogs).parse('Geddy Lee\nJW Mas\n5/3/2024');
      expect(p.q.agilityClass, AgilityClass.jww);
      expect(p.q.level, AgilityLevel.master);
    });

    test('Ex alone resolves to Excellent', () {
      final p = RibbonParser(dogs: dogs).parse('Geddy Lee\nSTD Ex\n5/3/2024');
      expect(p.q.level, AgilityLevel.excellent);
    });

    test('SCT with 1000ths + dotted abbrev', () {
      final p = RibbonParser(dogs: dogs).parse(
        'Geddy Lee\nMaster STD\n5/3/2024\nS.C.T. 58.123\nTime 41.23',
      );
      expect(p.q.sct, closeTo(58.123, 0.001));
    });

    test('PLACE: 1 extracted as placement', () {
      final p = RibbonParser(dogs: dogs).parse(
        'Geddy Lee\nMaster STD\n5/3/2024\nPLACE: 2',
      );
      expect(p.q.placement, 2);
    });

    test('Class+level shorthand: JWWMAS (concatenated)', () {
      final p = RibbonParser(dogs: dogs).parse(
        'Geddy Lee\nJWWMAS\n5/3/2024',
      );
      expect(p.q.agilityClass, AgilityClass.jww);
      expect(p.q.level, AgilityLevel.master);
    });

    test('Class+level shorthand: STD EX', () {
      final p = RibbonParser(dogs: dogs).parse(
        'Geddy Lee\nSTD EX\n5/3/2024',
      );
      expect(p.q.agilityClass, AgilityClass.standard);
      expect(p.q.level, AgilityLevel.excellent);
    });

    test('T2B is treated as single-level (Master)', () {
      final p = RibbonParser(dogs: dogs).parse(
        'Geddy Lee\nT2B\n5/3/2024\n12 points',
      );
      expect(p.q.agilityClass, AgilityClass.t2b);
      expect(p.q.level, AgilityLevel.master);
    });

    test('YPS extracted from ribbon text and stored as override', () {
      final p = RibbonParser(dogs: dogs).parse(
        'Geddy Lee\nJWW Master\n5/3/2024\nTime 41.23\nYards 170\n4.12 YPS',
      );
      expect(p.q.ypsOverride, closeTo(4.12, 0.001));
      expect(p.q.yps, closeTo(4.12, 0.001),
          reason: 'override takes precedence over yards/time math');
    });

    test('SCT + time → computed MACH points', () {
      final p = RibbonParser(dogs: dogs).parse(
        'Geddy Lee\nMaster Standard\n5/3/2024\nSCT 60\nTime 47.30',
      );
      expect(p.q.sport, Sport.akcAgility);
      expect(p.q.agilityClass, AgilityClass.standard);
      expect(p.q.level, AgilityLevel.master);
      expect(p.q.sct, closeTo(60, 0.01));
      expect(p.q.timeSeconds, closeTo(47.30, 0.01));
      // 60 - 47.30 = 12.70s → floor = 12 points
      expect(p.q.machPoints, 12);
    });

    test('SCT mismatch with scanned points yields a note', () {
      final p = RibbonParser(dogs: dogs).parse(
        'Neil\nMaster JWW\n5/3/2024\nSCT 40\nTime 28.00\nMACH Points: 5',
      );
      // Computed = 40 - 28 = 12; scanned = 5; diff > 2 → note set
      expect(p.q.machPoints, 12);
      expect(p.q.notes, isNotNull);
      expect(p.q.notes!.toLowerCase(), contains('points'));
    });

    test('Q.computeMachPoints utility', () {
      expect(Q.computeMachPoints(sct: 60, timeSeconds: 47.3), 12);
      expect(Q.computeMachPoints(sct: 60, timeSeconds: 60.5), 0);
      expect(Q.computeMachPoints(sct: null, timeSeconds: 30), 0);
      expect(Q.computeMachPoints(sct: 60, timeSeconds: null), 0);
    });

    test('Garbage text is recognized as not useful', () {
      final p = RibbonParser(dogs: dogs).parse('xxx yyy zzz');
      expect(p.isUseful, isFalse);
    });

    test('Text fingerprint normalizes', () {
      final p = RibbonParser(dogs: dogs).parse('Hello World 123');
      expect(p.textFingerprint, 'helloworld123');
    });
  });
}
