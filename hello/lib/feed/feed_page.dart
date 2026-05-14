import 'package:flutter/material.dart';

import '../convo/add_dog.dart';
import '../convo/add_q.dart';
import '../models/dog.dart';
import '../models/q.dart';
import '../repo/repo.dart';
import '../rules/engine.dart';
import 'achievement_detail_page.dart';
import 'card_widget.dart';
import 'dog_profile_page.dart';
import 'feed_items.dart';
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
          if (qs.isEmpty) continue;
          final results = engine.evaluate(qs);
          for (final r in results) {
            timeline.add(AchievementFeedItem(dog: dog, result: r, allQs: qs));
          }
          for (final q in qs) {
            timeline.add(QFeedItem(dog: dog, q: q));
          }
          timeline.addAll(buildTipsForDog(dog: dog, qs: qs, results: results));
        }
        timeline.sort(_byNewestThenAchievementsFirst);

        final pinned = timeline.where((f) => repo.isPinned(f.cardId)).toList();
        final unpinned = timeline.where((f) => !repo.isPinned(f.cardId)).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Runbook'),
            backgroundColor: cs.inversePrimary,
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

  /// Walks the timeline, collapsing consecutive Q items into a single
  /// RibbonRow widget.
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
        widgets.add(RibbonRow(
          qs: [for (final q in group) q.q],
          onTapQ: (q) {
            final owner = group.firstWhere((g) => g.q.id == q.id).dog;
            _onEditQ(context, owner, q);
          },
        ));
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
      } else if (item is TipFeedItem) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TipCard(
            tip: item,
            isPinned: repo.isPinned(item.cardId),
            onTogglePin: () => repo.togglePin(item.cardId),
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
    if (item is TipFeedItem) {
      return SizedBox(
        width: 220,
        child: TipCard(
          tip: item,
          isPinned: true,
          onTogglePin: () => repo.togglePin(item.cardId),
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
      return 2;
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
