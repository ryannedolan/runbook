import 'package:flutter_test/flutter_test.dart';
import 'package:runbook/export/csv_export.dart';
import 'package:runbook/models/dog.dart';
import 'package:runbook/models/q.dart';
import 'package:runbook/repo/repo.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Repo> seed({required List<Dog> dogs, required List<Q> qs}) async {
    final repo = await Repo.open();
    for (final d in dogs) {
      await repo.addDog(d);
    }
    for (final q in qs) {
      await repo.addQ(q);
    }
    return repo;
  }

  test('Empty repo writes just the header', () async {
    final repo = await Repo.open();
    final csv = buildQsCsv(repo);
    final lines = csv.trim().split('\n');
    expect(lines, hasLength(1));
    expect(lines.first.split(','), equals(kCsvColumns));
  });

  test('One Master STD Q renders all sport-specific fields', () async {
    final geddy = Dog.create(callName: 'Geddy Lee', akcId: 'PAL285213');
    final q = Q.create(
      dogId: geddy.id,
      date: DateTime(2024, 5, 3),
      agilityClass: AgilityClass.standard,
      level: AgilityLevel.master,
      timeSeconds: 41.23,
      yards: 170,
      sct: 60,
      placement: 1,
      machPoints: 18,
    );
    final repo = await seed(dogs: [geddy], qs: [q]);
    final csv = buildQsCsv(repo);
    final rows = csv.trim().split('\n');
    expect(rows, hasLength(2));
    final cells = rows[1].split(',');
    expect(cells[0], 'Geddy Lee');
    expect(cells[1], 'PAL285213');
    expect(cells[2], '2024-05-03');
    expect(cells[3], 'AKC Agility');
    expect(cells[4], 'Standard');
    expect(cells[5], 'Master');
    expect(cells[6], 'regular');
    expect(cells[7], '1');
    expect(cells[8], '41.23');
    expect(cells[9], '170');
    // yps is computed from yards/time when no override present
    expect(double.parse(cells[10]), closeTo(170 / 41.23, 0.01));
    expect(cells[11], '60');
    expect(cells[12], ''); // score blank for non-FAST/T2B
    expect(cells[13], '18');
  });

  test('T2B writes no level column (it has no level)', () async {
    final neil = Dog.create(callName: 'Neil');
    final q = Q.create(
      dogId: neil.id,
      date: DateTime(2024, 5, 3),
      agilityClass: AgilityClass.t2b,
      level: AgilityLevel.master,
      score: 12,
    );
    final repo = await seed(dogs: [neil], qs: [q]);
    final csv = buildQsCsv(repo);
    final cells = csv.trim().split('\n')[1].split(',');
    expect(cells[4], 'T2B');
    expect(cells[5], '', reason: 'T2B has no level — column blank');
    expect(cells[13], ''); // mach_points stays blank
    expect(cells[12], '12'); // score column has the points
  });

  test('Notes with commas/quotes are properly quoted', () async {
    final dog = Dog.create(callName: 'Z');
    final q = Q.create(
      dogId: dog.id,
      date: DateTime(2024, 5, 3),
      agilityClass: AgilityClass.standard,
      level: AgilityLevel.novice,
      notes: 'tricky run, with "quotes" and, commas',
    );
    final repo = await seed(dogs: [dog], qs: [q]);
    final csv = buildQsCsv(repo);
    final row = csv.trim().split('\n')[1];
    expect(row.endsWith('"tricky run, with ""quotes"" and, commas"'), isTrue);
  });

  test('Rows are newest-first', () async {
    final dog = Dog.create(callName: 'Z');
    final older = Q.create(
      dogId: dog.id,
      date: DateTime(2023, 1, 1),
      agilityClass: AgilityClass.standard,
      level: AgilityLevel.novice,
    );
    final newer = Q.create(
      dogId: dog.id,
      date: DateTime(2024, 1, 1),
      agilityClass: AgilityClass.standard,
      level: AgilityLevel.novice,
    );
    final repo = await seed(dogs: [dog], qs: [older, newer]);
    final csv = buildQsCsv(repo);
    final rows = csv.trim().split('\n');
    expect(rows[1], contains('2024-01-01'));
    expect(rows[2], contains('2023-01-01'));
  });
}
