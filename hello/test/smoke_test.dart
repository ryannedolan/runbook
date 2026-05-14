import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runbook/feed/feed_page.dart';
import 'package:runbook/models/dog.dart';
import 'package:runbook/models/q.dart';
import 'package:runbook/repo/repo.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Empty repo shows "add a dog" empty state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await Repo.open();
    await tester.pumpWidget(MaterialApp(home: FeedPage(repo: repo)));
    expect(find.text("Let's start by adding a dog."), findsOneWidget);
    expect(find.text('Add a dog'), findsOneWidget);
  });

  test('Duplicate dogs are merged on load and Qs are reassigned', () async {
    final dogs = [
      Dog(id: 'a', callName: 'Echo'),
      Dog(id: 'b', callName: 'echo', breed: 'BC'),
      Dog(id: 'c', callName: 'ECHO', heightInches: 21),
    ];
    final qs = [
      Q.create(
        dogId: 'b',
        date: DateTime(2026, 1, 1),
        agilityClass: AgilityClass.standard,
        level: AgilityLevel.novice,
      ),
      Q.create(
        dogId: 'c',
        date: DateTime(2026, 1, 2),
        agilityClass: AgilityClass.jww,
        level: AgilityLevel.novice,
      ),
    ];
    SharedPreferences.setMockInitialValues({
      'runbook.dogs': jsonEncode([for (final d in dogs) d.toJson()]),
      'runbook.qs': jsonEncode([for (final q in qs) q.toJson()]),
    });
    final repo = await Repo.open();
    expect(repo.dogs, hasLength(1));
    expect(repo.dogs.single.id, 'a');
    expect(repo.dogs.single.breed, 'BC');
    expect(repo.dogs.single.heightInches, 21);
    expect(repo.qsForDog('a'), hasLength(2));
    expect(repo.qsForDog('b'), isEmpty);
  });

  testWidgets('Seeded repo shows feed with title cards', (tester) async {
    // Tall viewport so the lazy SliverList builds all of the trial-day
    // groups + achievement cards.
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final repo = await Repo.open();
    await repo.seedSampleData();
    await tester.pumpWidget(MaterialApp(home: FeedPage(repo: repo)));
    // Three Novice STD Qs in seed data → NA title earned. The rosette
    // also renders the title text inside, so "NA" appears twice.
    expect(find.text('NA'), findsNWidgets(2));
    expect(find.text('NAJ'), findsNWidgets(2));
    // FAB
    expect(find.text('Log a Q'), findsOneWidget);
  });
}
