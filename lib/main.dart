import 'dart:async';

import 'package:flutter/material.dart';

import 'feed/feed_page.dart';
import 'repo/repo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = await Repo.open();
  // Fire-and-forget: backfill from bundled YAML datasets. Idempotent
  // and safe to interleave with the first frame; the repo notifies
  // listeners when new Qs land.
  unawaited(repo.backfillFromAssets());
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
