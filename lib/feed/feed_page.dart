import 'package:flutter/material.dart';

import '../convo/add_dog.dart';
import '../convo/add_q.dart';
import '../export/csv_export.dart';
import '../models/dog.dart';
import '../models/q.dart';
import '../repo/repo.dart';
import '../rules/engine.dart';
import '../scan/scan_ribbons_page.dart';
import 'achievement_detail_page.dart';
import 'analytics.dart';
import 'analytics_detail_page.dart';
import 'card_widget.dart';
import 'dog_profile_page.dart';
import 'feed_items.dart';
import 'missing_qs_page.dart';
import 'q_history_page.dart';
import 'tips.dart';
import 'trial_day_detail_page.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key, required this.repo});
  final Repo repo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final dogs = repo.dogs;
        final engine = RulesEngine();
        final timeline = <FeedItem>[];
        for (final dog in dogs) {
          final qs = repo.qsForDog(dog.id);
          final overrides = repo.overridesForDog(dog.id);
          if (qs.isEmpty && overrides.isEmpty) continue;
          final results = engine.evaluate(qs, overrides: overrides);
          for (final r in results) {
            timeline.add(AchievementFeedItem(dog: dog, result: r, allQs: qs));
          }
          for (final q in qs) {
            timeline.add(QFeedItem(dog: dog, q: q));
          }
          timeline.addAll(
              buildTipsForDog(dog: dog, qs: qs, results: results, repo: repo));
          timeline.addAll(buildAnalyticsForDog(dog: dog, qs: qs));
        }
        timeline.sort(_byNewestThenAchievementsFirst);

        final pinned = timeline.where((f) => repo.isPinned(f.cardId)).toList();
        final unpinned = timeline.where((f) => !repo.isPinned(f.cardId)).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Runbook'),
            backgroundColor: cs.inversePrimary,
            actions: [
              IconButton(
                tooltip: 'Scan ribbons',
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () => _onScanRibbons(context),
              ),
              IconButton(
                tooltip: 'Q history',
                icon: const Icon(Icons.search),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => QHistoryPage(repo: repo)),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _onLogQ(context),
            icon: const Icon(Icons.add),
            label: const Text('Log a Q'),
          ),
          body: dogs.isEmpty
              ? _emptyState(context)
              : _timelineBody(context, pinned, unpinned),
        );
      },
    );
  }

  Widget _timelineBody(BuildContext context, List<FeedItem> pinned, List<FeedItem> unpinned) {
    final cs = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        if (pinned.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Pinned',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in pinned) _renderPinned(context, item),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Divider(color: cs.outlineVariant, height: 1),
          ),
        ],
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Feed',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
        ..._buildTimelineSlivers(context, unpinned),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          sliver: SliverToBoxAdapter(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.pets),
                  label: const Text('Add another dog'),
                  onPressed: () => _onAddDog(context),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Missing Qs'),
                  onPressed: () => _onMissingQs(context),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Export as CSV'),
                  onPressed: () => _onExportCsv(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Walks the timeline, collapsing consecutive Q items into trial-day
  /// groups (one per dog/date) so the user sees a clear "this trial"
  /// cluster. Unlocked achievements that fall on a (dog, date) with a
  /// matching trial-day get inlined into that card's title-chip row
  /// instead of taking a separate card.
  List<Widget> _buildTimelineSlivers(BuildContext context, List<FeedItem> items) {
    // Index unlocked achievements by (dog, day) so we can inline them
    // into the matching trial-day card. We also track which ones got
    // inlined so they don't double-render as standalone cards.
    final qDayKeys = <String>{};
    for (final f in items) {
      if (f is! QFeedItem) continue;
      final d = f.q.date;
      qDayKeys.add('${f.dog.id}::${d.year}-${d.month}-${d.day}');
    }
    final achievementsByDay = <String, List<AchievementFeedItem>>{};
    final inlinedIds = <String>{};
    for (final f in items) {
      if (f is! AchievementFeedItem) continue;
      final at = f.result.unlockedAt;
      if (at == null) continue;
      final key = '${f.dog.id}::${at.year}-${at.month}-${at.day}';
      if (!qDayKeys.contains(key)) continue;
      achievementsByDay.putIfAbsent(key, () => []).add(f);
      inlinedIds.add(f.cardId);
    }

    final widgets = <Widget>[];
    var i = 0;
    while (i < items.length) {
      final item = items[i];
      if (item is QFeedItem) {
        final group = <QFeedItem>[];
        while (i < items.length && items[i] is QFeedItem) {
          group.add(items[i] as QFeedItem);
          i++;
        }
        // Sub-group by (dog, calendar date) and render each as a TrialDayCard.
        final byKey = <String, List<QFeedItem>>{};
        final order = <String>[];
        for (final qf in group) {
          final dateKey =
              '${qf.dog.id}::${qf.q.date.year}-${qf.q.date.month}-${qf.q.date.day}';
          if (!byKey.containsKey(dateKey)) {
            order.add(dateKey);
            byKey[dateKey] = [];
          }
          byKey[dateKey]!.add(qf);
        }
        for (final key in order) {
          final day = byKey[key]!;
          final dayDog = day.first.dog;
          final dayDate = day.first.q.date;
          final dayAchievements = achievementsByDay[key] ?? const [];
          widgets.add(TrialDayCard(
            dog: dayDog,
            date: dayDate,
            qs: [for (final q in day) q.q],
            onTapQ: (q) => _onEditQ(context, dayDog, q),
            onOpenDay: () => _onOpenTrialDay(context, dayDog, dayDate),
            earnedAchievements: [for (final f in dayAchievements) f.result],
            onTapAchievement: (r) {
              // Find the original feed item to reuse the existing
              // achievement-detail navigation.
              for (final f in dayAchievements) {
                if (f.result.achievement.id == r.achievement.id) {
                  _onOpenAchievement(context, f);
                  return;
                }
              }
            },
          ));
        }
      } else if (item is AchievementFeedItem) {
        // Inlined into a trial-day card above? Skip.
        if (inlinedIds.contains(item.cardId)) {
          i++;
          continue;
        }
        // Phantom-unlocked (count adjusted manually, no real Q date)
        // — these surface only on the detail page, never in the feed.
        if (item.result.isUnlocked && item.result.unlockedAt == null) {
          i++;
          continue;
        }
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AchievementCard(
            item: item,
            isPinned: repo.isPinned(item.cardId),
            onTogglePin: () => repo.togglePin(item.cardId),
            onOpen: () => _onOpenAchievement(context, item),
            onDogTap: () => _onDogTap(context, item.dog),
            size: CardSize.feed,
          ),
        ));
        i++;
      } else if (item is AnalyticsFeedItem) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AnalyticsCard(
            item: item,
            isPinned: repo.isPinned(item.cardId),
            onTogglePin: () => repo.togglePin(item.cardId),
            onDogTap: () => _onDogTap(context, item.dog),
            onOpen: () => _onOpenAnalytics(context, item),
          ),
        ));
        i++;
      } else if (item is TipFeedItem) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TipCard(
            tip: item,
            isPinned: repo.isPinned(item.cardId),
            onTogglePin: () => repo.togglePin(item.cardId),
            onMarkCollected: item.isCollectable
                ? () => repo.markRibbonCollected(
                      item.collectableRibbonDogId!,
                      item.collectableRibbonAchievementId!,
                    )
                : null,
          ),
        ));
        i++;
      } else {
        i++;
      }
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        sliver: SliverList(delegate: SliverChildListDelegate(widgets)),
      ),
    ];
  }

  Widget _renderPinned(BuildContext context, FeedItem item) {
    if (item is AchievementFeedItem) {
      return AchievementCard(
        item: item,
        isPinned: true,
        onTogglePin: () => repo.togglePin(item.cardId),
        onOpen: () => _onOpenAchievement(context, item),
        onDogTap: () => _onDogTap(context, item.dog),
        size: CardSize.pinned,
      );
    }
    if (item is AnalyticsFeedItem) {
      return SizedBox(
        width: 240,
        child: AnalyticsCard(
          item: item,
          isPinned: true,
          onTogglePin: () => repo.togglePin(item.cardId),
          onDogTap: () => _onDogTap(context, item.dog),
          onOpen: () => _onOpenAnalytics(context, item),
        ),
      );
    }
    if (item is TipFeedItem) {
      return SizedBox(
        width: 220,
        child: TipCard(
          tip: item,
          isPinned: true,
          onTogglePin: () => repo.togglePin(item.cardId),
          onMarkCollected: item.isCollectable
              ? () => repo.markRibbonCollected(
                    item.collectableRibbonDogId!,
                    item.collectableRibbonAchievementId!,
                  )
              : null,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  int _byNewestThenAchievementsFirst(FeedItem a, FeedItem b) {
    final cmp = b.sortTimestamp.compareTo(a.sortTimestamp);
    if (cmp != 0) return cmp;
    // On tie: achievements first, then tips, then Q ribbons.
    int rank(FeedItem f) {
      if (f is AchievementFeedItem) return 0;
      if (f is TipFeedItem) return 1;
      if (f is AnalyticsFeedItem) return 2;
      return 3;
    }

    return rank(a).compareTo(rank(b));
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "Let's start by adding a dog.",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              "Once you've added a dog, you can start logging Qs and watching titles roll in.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add a dog'),
              onPressed: () => _onAddDog(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAddDog(BuildContext context) async {
    final result = await Navigator.of(context).push<({Dog dog, bool merged})>(
      MaterialPageRoute(builder: (_) => AddDogPage(repo: repo)),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.merged
              ? 'Updated ${result.dog.callName}'
              : 'Added ${result.dog.callName}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onLogQ(BuildContext context) async {
    final saved = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => AddQPage(repo: repo)),
    );
    if (saved != null && saved > 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved == 1 ? 'Logged 1 Q' : 'Logged $saved Qs'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onEditQ(BuildContext context, Dog dog, Q q) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddQPage(repo: repo, editing: q)),
    );
  }

  Future<void> _onScanRibbons(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ScanRibbonsPage(repo: repo)),
    );
  }

  Future<void> _onMissingQs(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MissingQsPage(repo: repo)),
    );
  }

  Future<void> _onExportCsv(BuildContext context) async {
    if (!csvExportSupportedOnThisPlatform) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('CSV export is only available on the mobile app.'),
      ));
      return;
    }
    try {
      final count = await shareQsCsv(repo);
      if (!context.mounted) return;
      if (count == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nothing to export yet — log or scan some Qs first.'),
        ));
      }
      // On success, the OS share sheet takes over; no in-app message
      // is needed (it'd compete with the share-result toast).
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
      ));
    }
  }


  void _onDogTap(BuildContext context, Dog dog) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DogProfilePage(repo: repo, dogId: dog.id)),
    );
  }

  void _onOpenAchievement(BuildContext context, AchievementFeedItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AchievementDetailPage(repo: repo, item: item),
      ),
    );
  }

  void _onOpenAnalytics(BuildContext context, AnalyticsFeedItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalyticsDetailPage(repo: repo, item: item),
      ),
    );
  }

  void _onOpenTrialDay(BuildContext context, Dog dog, DateTime date) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TrialDayDetailPage(repo: repo, dogId: dog.id, date: date),
      ),
    );
  }
}
