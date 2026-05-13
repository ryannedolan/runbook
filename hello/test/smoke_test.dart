import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runbook/feed/feed_page.dart';
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

  testWidgets('Seeded repo shows feed with title cards', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await Repo.open();
    await repo.seedSampleData();
    await tester.pumpWidget(MaterialApp(home: FeedPage(repo: repo)));
    // Three Novice STD Qs in seed data → NA title earned.
    expect(find.text('NA'), findsOneWidget);
    // Multiple Novice JWW Qs → NAJ title earned.
    expect(find.text('NAJ'), findsOneWidget);
    // FAB
    expect(find.text('Log a Q'), findsOneWidget);
  });
}
