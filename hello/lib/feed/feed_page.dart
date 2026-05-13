import 'package:flutter/material.dart';

import '../convo/add_dog.dart';
import '../convo/add_q.dart';
import '../repo/repo.dart';
import '../rules/engine.dart';
import 'card_widget.dart';

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
        final feedItems = <FeedItem>[];
        for (final dog in dogs) {
          final qs = repo.qsForDog(dog.id);
          if (qs.isEmpty) continue;
          final results = engine.evaluate(qs);
          for (final r in results) {
            feedItems.add(FeedItem(dog: dog, result: r));
          }
        }
        // Sort: unlocked unlock-date desc, in-progress at the bottom by
        // most-recent-progress desc.
        feedItems.sort((a, b) {
          if (a.result.isUnlocked != b.result.isUnlocked) {
            return a.result.isUnlocked ? -1 : 1;
          }
          return b.sortTimestamp.compareTo(a.sortTimestamp);
        });

        final pinned = feedItems.where((f) => repo.isPinned(f.cardId)).toList();
        final unpinned = feedItems.where((f) => !repo.isPinned(f.cardId)).toList();

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
              : CustomScrollView(
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
                              for (final item in pinned)
                                AchievementCard(
                                  item: item,
                                  isPinned: true,
                                  onTogglePin: () =>
                                      repo.togglePin(item.cardId),
                                  size: CardSize.pinned,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      SliverToBoxAdapter(
                        child: Divider(
                          color: cs.outlineVariant,
                          height: 1,
                        ),
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
                    if (unpinned.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'Add a Q to start unlocking titles.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        sliver: SliverList.builder(
                          itemCount: unpinned.length + 1,
                          itemBuilder: (ctx, i) {
                            if (i == unpinned.length) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(0, 16, 0, 96),
                                child: TextButton.icon(
                                  icon: const Icon(Icons.pets),
                                  label: const Text('Add another dog'),
                                  onPressed: () => _onAddDog(context),
                                ),
                              );
                            }
                            final item = unpinned[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AchievementCard(
                                item: item,
                                isPinned: false,
                                onTogglePin: () =>
                                    repo.togglePin(item.cardId),
                                size: CardSize.feed,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
        );
      },
    );
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

  void _onAddDog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddDogPage(repo: repo)),
    );
  }

  void _onLogQ(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddQPage(repo: repo)),
    );
  }
}
