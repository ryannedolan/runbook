// Importer behavior + a smoke test over the bundled `assets/dogs/*.yaml`
// so YAML schema drift from the agentic workflow doesn't silently break
// downstream Q parsing.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runbook/models/dog.dart';
import 'package:runbook/models/q.dart';
import 'package:runbook/repo/dog_import.dart';
import 'package:runbook/repo/repo.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('parseDogYaml', () {
    test('AKC agility STD Master with mach points', () {
      const raw = '''
---
sport: agility
venue: AKC
date: 2025-01-03
class: STD
level: MAS
score: 100
time: 51.75
yards: 164.0
mach_points: 14
place: 1
''';
      final qs = parseDogYaml(raw, dogId: 'd');
      expect(qs, hasLength(1));
      final q = qs.single.q;
      expect(q.sport, Sport.akcAgility);
      expect(q.agilityClass, AgilityClass.standard);
      expect(q.level, AgilityLevel.master);
      expect(q.preferred, isFalse);
      expect(q.score, 100);
      expect(q.machPoints, 14);
      expect(q.timeSeconds, 51.75);
      expect(q.placement, 1);
    });

    test('T2B REG → master regular, PREF → master preferred', () {
      const raw = '''
---
sport: agility
venue: AKC
date: 2025-12-06
class: T2B
level: PREF
score: 10
time: 46.96
place: 1
---
sport: agility
venue: AKC
date: 2025-12-06
class: T2B
level: REG
time: 35.34
score: 9
''';
      final qs = parseDogYaml(raw, dogId: 'd');
      expect(qs, hasLength(2));
      expect(qs[0].q.preferred, isTrue);
      expect(qs[0].q.level, AgilityLevel.master);
      expect(qs[1].q.preferred, isFalse);
      expect(qs[1].q.level, AgilityLevel.master);
    });

    test('Scentwork Novice container with MM:SS.HH search time', () {
      const raw = '''
---
sport: scent work
venue: AKC
date: 2024-05-11
element: Container
class: Novice
search_time: '00:51.47'
place: 5
''';
      final qs = parseDogYaml(raw, dogId: 'd');
      expect(qs, hasLength(1));
      final q = qs.single.q;
      expect(q.sport, Sport.scentwork);
      expect(q.scentElement, ScentElement.container);
      expect(q.scentLevel, ScentLevel.novice);
      // 51.47 seconds.
      expect(q.timeSeconds, closeTo(51.47, 0.001));
    });

    test('Scentwork MM:SS:HH search time (colon hundredths)', () {
      const raw = '''
---
sport: scent work
venue: AKC
date: 2024-07-20
element: Buried
class: Novice
search_time: 01:06:65
''';
      final qs = parseDogYaml(raw, dogId: 'd');
      expect(qs, hasLength(1));
      // 1 min 6.65 s = 66.65 s.
      expect(qs.single.q.timeSeconds, closeTo(66.65, 0.001));
    });

    test('FastCAT yields Sport.fastCAT and a score from "points"', () {
      const raw = '''
---
sport: fastcat
venue: AKC
date: 2025-10-11
trial: Trial 2
class: Single
points: 23.19
time: 8.82
place: 24
''';
      final q = parseDogYaml(raw, dogId: 'd').single.q;
      expect(q.sport, Sport.fastCAT);
      expect(q.score, 23);
      expect(q.timeSeconds, 8.82);
      expect(q.placement, 24);
      expect(q.trial, 'Trial 2');
    });

    test('Skips non-AKC venue (ASCA agility)', () {
      const raw = '''
---
sport: agility
venue: ASCA
date: 2015-04-11
class: REGULAR
level: Open
''';
      expect(parseDogYaml(raw, dogId: 'd'), isEmpty);
    });

    test('Skips unmodeled sport (barn hunt)', () {
      const raw = '''
---
sport: barn hunt
venue: Barn Hunt Association
date: 2013-09-14
class: Novice
''';
      expect(parseDogYaml(raw, dogId: 'd'), isEmpty);
    });

    test('Skips Handler Discrimination element (not modeled)', () {
      const raw = '''
---
sport: scent work
venue: AKC
date: 2024-07-21
element: Handler Discrimination
class: Novice
''';
      expect(parseDogYaml(raw, dogId: 'd'), isEmpty);
    });
  });

  group('dedupeKeyFor', () {
    test('agility: matches across score/time differences', () {
      final a = Q.create(
        dogId: 'd',
        date: DateTime(2026, 1, 1),
        agilityClass: AgilityClass.jww,
        level: AgilityLevel.master,
        score: 100,
        timeSeconds: 42.1,
      );
      final b = a.copyWith(score: 95, timeSeconds: 50.0);
      expect(dedupeKeyFor(a), dedupeKeyFor(b));
    });

    test('FastCAT: same-day distinct trials → distinct keys', () {
      final a = Q.create(
        dogId: 'd',
        date: DateTime(2025, 10, 11),
        sport: Sport.fastCAT,
        agilityClass: AgilityClass.fast,
        level: AgilityLevel.novice,
        trial: 'Trial 1',
        score: 23,
      );
      final b = a.copyWith(trial: 'Trial 2', score: 21);
      expect(dedupeKeyFor(a), isNot(dedupeKeyFor(b)));
    });

    test('agility re-import after first import is idempotent', () {
      // Two records with identical event identity but freshly parsed
      // (different Q.id) should produce the same dedupe key, so the
      // second pass adds nothing.
      const raw = '''
---
sport: agility
venue: AKC
date: 2025-01-03
class: STD
level: MAS
score: 100
time: 51.75
''';
      final first = parseDogYaml(raw, dogId: 'd').single;
      final second = parseDogYaml(raw, dogId: 'd').single;
      expect(first.dedupeKey, second.dedupeKey);
    });
  });

  group('Repo.backfillFromAssets', () {
    test('imports new Qs and is idempotent', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = await Repo.open();
      final dog = Dog.create(callName: 'Echo', akcId: 'TESTID');
      await repo.addDog(dog);

      Future<DatasetIndex> index() async => DatasetIndex({
            'TESTID': DogDataset(akcId: 'TESTID', callName: 'Echo'),
          });
      Future<List<ImportedQ>> qs(String akcId, String dogId) async {
        final q = Q.create(
          dogId: dogId,
          date: DateTime(2026, 1, 1),
          agilityClass: AgilityClass.jww,
          level: AgilityLevel.novice,
          score: 100,
        );
        return [ImportedQ(q: q, dedupeKey: dedupeKeyFor(q))];
      }

      final firstAdded = await repo.backfillFromAssets(
        loadIndex: index,
        loadQs: qs,
      );
      expect(firstAdded, 1);
      expect(repo.qsForDog(dog.id), hasLength(1));

      final secondAdded = await repo.backfillFromAssets(
        loadIndex: index,
        loadQs: qs,
      );
      expect(secondAdded, 0);
      expect(repo.qsForDog(dog.id), hasLength(1));
    });

    test('auto-links unlinked dog by call name', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = await Repo.open();
      final dog = Dog.create(callName: 'Echo'); // no AKC id yet.
      await repo.addDog(dog);

      Future<DatasetIndex> index() async => DatasetIndex({
            'AKC-99': DogDataset(akcId: 'AKC-99', callName: 'Echo'),
          });
      Future<List<ImportedQ>> qs(String akcId, String dogId) async => [];

      await repo.backfillFromAssets(loadIndex: index, loadQs: qs);
      expect(repo.dogById(dog.id)?.akcId, 'AKC-99');
    });
  });

  group('bundled assets', () {
    // Loads every assets/dogs/*.yaml through the real importer. Catches
    // schema drift from the agentic workflow.
    test('every bundled YAML parses with no dedupe collisions', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final manifest = jsonDecode(
        await File('AssetManifest.json').exists()
            ? File('AssetManifest.json').readAsStringSync()
            : '{}',
      ) as Map<String, dynamic>;
      // Fall back to file system if AssetManifest isn't reachable in
      // unit-test sandbox.
      final files = manifest.keys
              .where((p) => p.startsWith('assets/dogs/') && p.endsWith('.yaml'))
              .toList()
              .isNotEmpty
          ? manifest.keys
              .where((p) => p.startsWith('assets/dogs/') && p.endsWith('.yaml'))
              .map((p) => File(p))
              .toList()
          : Directory('assets/dogs')
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.yaml'))
              .toList();
      expect(files, isNotEmpty, reason: 'no datasets bundled');
      for (final f in files) {
        final raw = f.readAsStringSync();
        final qs = parseDogYaml(raw, dogId: 'd');
        expect(qs, isNotEmpty,
            reason: '${f.path} parsed to zero Qs — schema may have drifted');
        final seen = <String>{};
        for (final iq in qs) {
          expect(seen.add(iq.dedupeKey), isTrue,
              reason: 'duplicate key ${iq.dedupeKey} in ${f.path}');
        }
      }
    });
  });
}
