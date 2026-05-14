import 'package:flutter/material.dart';

import '../convo/add_dog.dart';
import '../convo/add_event.dart';
import '../convo/add_q.dart';
import '../models/dog.dart';
import '../models/q.dart';
import '../repo/repo.dart';
import '../rules/engine.dart';
import 'achievement_detail_page.dart';
import 'analytics.dart';
import 'card_widget.dart';
import 'dog_profile_page.dart';
import 'feed_items.dart';
import 'q_history_page.dart';
import 'tips.dart';

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
          final events = repo.eventsForDog(dog.id);
          if (qs.isEmpty && events.isEmpty) continue;
          final results = engine.evaluate(qs);
          for (final r in results) {
            timeline.add(AchievementFeedItem(dog: dog, result: r, allQs: qs));
          }
          for (final q in qs) {
            timeline.add(QFeedItem(dog: dog, q: q));
          }
          for (final ev in events) {
            timeline.add(EventFeedItem(dog: dog, event: ev));
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
                tooltip: 'Log an event',
                icon: const Icon(Icons.emoji_events_outlined),
                onPressed: () => _onLogEvent(context),
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
            child: TextButton.icon(
              icon: const Icon(Icons.pets),
              label: const Text('Add another dog'),
              onPressed: () => _onAddDog(context),
            ),
          ),
        ),
      ],
    );
  }

  /// Walks the timeline, collapsing consecutive Q items into trial-day
  /// groups (one per dog/date) so the user sees a clear "this trial"
  /// cluster.
  List<Widget> _buildTimelineSlivers(BuildContext context, List<FeedItem> items) {
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
          widgets.add(TrialDayCard(
            dog: day.first.dog,
            date: day.first.q.date,
            qs: [for (final q in day) q.q],
            onTapQ: (q) => _onEditQ(context, day.first.dog, q),
          ));
        }
      } else if (item is AchievementFeedItem) {
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
      } else if (item is EventFeedItem) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: EventCard(
            item: item,
            isPinned: repo.isPinned(item.cardId),
            onTogglePin: () => repo.togglePin(item.cardId),
            onOpen: () => _onEditEvent(context, item),
            onDogTap: () => _onDogTap(context, item.dog),
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
        ),
      );
    }
    if (item is EventFeedItem) {
      return SizedBox(
        width: 260,
        child: EventCard(
          item: item,
          isPinned: true,
          onTogglePin: () => repo.togglePin(item.cardId),
          onOpen: () => _onEditEvent(context, item),
          onDogTap: () => _onDogTap(context, item.dog),
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
      if (f is EventFeedItem) return 1;
      if (f is TipFeedItem) return 2;
      if (f is AnalyticsFeedItem) return 3;
      return 4;
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

  Future<void> _onLogEvent(BuildContext context) async {
    final saved = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => AddEventPage(repo: repo)),
    );
    if (saved != null && saved > 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event logged'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onEditEvent(BuildContext context, EventFeedItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEventPage(repo: repo, editing: item.event),
      ),
    );
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
}
