import 'package:flutter_test/flutter_test.dart';
import 'package:runbook/models/q.dart';

void main() {
  group('Q fromJson migrates legacy non-agility placeholders', () {
    test('Legacy FastCAT Q drops placeholder agilityClass/level on read', () {
      // Pre-refactor Qs were saved with these placeholders because
      // agilityClass + level were required fields.
      final legacy = <String, dynamic>{
        'id': 'q1',
        'dogId': 'd1',
        'date': '2026-05-01T00:00:00.000',
        'sport': 'fastCAT',
        'agilityClass': 'fast', // placeholder — must be ignored
        'level': 'novice', // placeholder — must be ignored
        'score': 17,
        'timeSeconds': 8.45,
      };
      final q = Q.fromJson(legacy);
      expect(q.sport, Sport.fastCAT);
      expect(q.agilityClass, isNull);
      expect(q.level, isNull);
      expect(q.score, 17);
      expect(q.timeSeconds, closeTo(8.45, 0.001));
    });

    test('Legacy Scentwork Q drops placeholder agilityClass/level on read', () {
      final legacy = <String, dynamic>{
        'id': 'q2',
        'dogId': 'd1',
        'date': '2026-05-01T00:00:00.000',
        'sport': 'scentwork',
        'agilityClass': 'fast',
        'level': 'novice',
        'scentElement': 'container',
        'scentLevel': 'master',
      };
      final q = Q.fromJson(legacy);
      expect(q.sport, Sport.scentwork);
      expect(q.agilityClass, isNull);
      expect(q.level, isNull);
      expect(q.scentElement, ScentElement.container);
      expect(q.scentLevel, ScentLevel.master);
    });

    test('Agility Q keeps its fields', () {
      final json = <String, dynamic>{
        'id': 'q3',
        'dogId': 'd1',
        'date': '2026-05-01T00:00:00.000',
        // sport defaults to akcAgility
        'agilityClass': 'standard',
        'level': 'master',
      };
      final q = Q.fromJson(json);
      expect(q.sport, Sport.akcAgility);
      expect(q.agilityClass, AgilityClass.standard);
      expect(q.level, AgilityLevel.master);
    });

    test('Round-trip: new non-agility Q persists without placeholders', () {
      final q = Q.create(
        dogId: 'd1',
        date: DateTime(2026, 5, 1),
        sport: Sport.fastCAT,
        score: 17,
        timeSeconds: 8.45,
      );
      final json = q.toJson();
      expect(json.containsKey('agilityClass'), isFalse);
      expect(json.containsKey('level'), isFalse);
      // And re-loads cleanly.
      final q2 = Q.fromJson(json);
      expect(q2.agilityClass, isNull);
      expect(q2.level, isNull);
      expect(q2.score, 17);
    });
  });
}
