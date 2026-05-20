import 'package:flutter/material.dart';

import 'feed/feed_page.dart';
import 'repo/repo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = await Repo.open();
  // No startup backfill — the JSON datasets aren't bundled into the
  // build anymore. Backfill is triggered per-dog when the user saves
  // a dog with an AKC ID (see add_dog.dart).
  runApp(RunbookApp(repo: repo));
}

class RunbookApp extends StatelessWidget {
  const RunbookApp({super.key, required this.repo});
  final Repo repo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Runbook',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: FeedPage(repo: repo),
    );
  }
}
