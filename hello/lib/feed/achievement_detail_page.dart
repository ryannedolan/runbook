import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../convo/add_q.dart';
import '../models/q.dart';
import '../repo/repo.dart';
import '../rules/achievement.dart';
import '../rules/akc_agility.dart';
import '../rules/engine.dart';
import 'dog_profile_page.dart';
import 'feed_items.dart';
import 'widgets/icon_chiclet.dart';

class AchievementDetailPage extends StatelessWidget {
  const AchievementDetailPage({
    super.key,
    required this.repo,
    required this.item,
  });

  final Repo repo;
  final AchievementFeedItem item;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final dog = repo.dogById(item.dog.id);
        if (dog == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Achievement')),
            body: const Center(child: Text('Dog no longer exists.')),
          );
        }
        final qs = repo.qsForDog(dog.id);
        final engine = RulesEngine();
        final fresh = engine.evaluate(qs).firstWhere(
              (r) => r.achievement.id == item.result.achievement.id,
              orElse: () => item.result,
            );
        final achievement = fresh.achievement;
        final chain = chainOf(achievement);
        final cs = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: Text(achievement.title),
            backgroundColor: fresh.isUnlocked
                ? const Color(0xFFFFE9A8)
                : cs.surfaceContainerHighest,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _header(context, fresh, dog.callName),
              const SizedBox(height: 24),
              if (chain != null) _chainSection(context, chain, achievement, qs, dog.id),
              _qsSection(context, fresh, qs, dog.id),
              _statsSection(context, fresh, qs),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DogProfilePage(repo: repo, dogId: dog.id),
                  ));
                },
                icon: const Icon(Icons.pets),
                label: Text("Open ${dog.callName}'s profile"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, AchievementResult r, String dogName) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TitleChiclet(
              achievement: r.achievement,
              size: 88,
              dimmed: !r.isUnlocked,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.achievement.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$dogName • ${r.achievement.sport}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(r.achievement.description),
        const SizedBox(height: 16),
        if (r.isUnlocked) ...[
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Unlocked ${DateFormat.yMMMd().format(r.unlockedAt!)}'
                  '${r.impliedBy != null ? '\n(Implied by a ${r.impliedBy!.label} Q)' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ] else
          _progressBlock(context, r),
      ],
    );
  }

  Widget _progressBlock(BuildContext context, AchievementResult r) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: r.progress,
            minHeight: 10,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${r.have} of ${r.need}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        if (r.need - r.have == 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "One more Q to go!",
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }

  Widget _chainSection(
    BuildContext context,
    TitleProgression chain,
    Achievement current,
    List<Q> qs,
    String dogId,
  ) {
    final cs = Theme.of(context).colorScheme;
    final engine = RulesEngine();
    final results = engine.evaluate(qs);
    AchievementResult? rOf(Achievement a) {
      for (final r in results) {
        if (r.achievement.id == a.id) return r;
      }
      return null;
    }

    final i = chain.titles.indexOf(current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${chain.name} chain',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var idx = 0; idx < chain.titles.length; idx++)
              _ChainPill(
                title: chain.titles[idx],
                result: rOf(chain.titles[idx]),
                isCurrent: idx == i,
              ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _qsSection(
    BuildContext context,
    AchievementResult r,
    List<Q> qs,
    String dogId,
  ) {
    final cs = Theme.of(context).colorScheme;
    final contributing = qs
        .where((q) => r.contributingQIds.contains(q.id))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contributing Qs (${contributing.length})',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (contributing.isEmpty)
          Text(
            r.impliedBy != null
                ? "No direct Qs — this title was earned by a higher-level Q."
                : "No Qs yet. Log one to start earning ${r.achievement.title}.",
            style: TextStyle(color: cs.onSurfaceVariant),
          )
        else
          for (final q in contributing) _qTile(context, q),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _qTile(BuildContext context, Q q) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddQPage(repo: repo, editing: q),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              QRibbonChiclet(q: q, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  DateFormat.yMMMd().format(q.date),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              if (q.machPoints > 0)
                Text(
                  '${q.machPoints} pts',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statsSection(BuildContext context, AchievementResult r, List<Q> qs) {
    final cs = Theme.of(context).colorScheme;
    final contributing =
        qs.where((q) => r.contributingQIds.contains(q.id)).toList();
    final withTimes = contributing.where((q) => q.timeSeconds != null).toList();
    final withYps = contributing.where((q) => q.yps != null).toList();
    final a = r.achievement;
    final isChampion = a is ChampionTitle;
    final isNAC = a is NACQualificationTitle;
    if (contributing.isEmpty && !isChampion && !isNAC) {
      return const SizedBox.shrink();
    }

    final tiles = <Widget>[];
    if (withTimes.isNotEmpty) {
      final avg = withTimes.fold<double>(0, (s, q) => s + q.timeSeconds!) /
          withTimes.length;
      tiles.add(_StatTile(label: 'Avg time', value: '${avg.toStringAsFixed(1)}s'));
    }
    if (withYps.isNotEmpty) {
      final avg =
          withYps.fold<double>(0, (s, q) => s + q.yps!) / withYps.length;
      tiles.add(_StatTile(label: 'Avg YPS', value: avg.toStringAsFixed(2)));
    }
    if (isChampion) {
      final live = a.liveCounts(qs);
      tiles.add(_StatTile(
        label: a.preferred ? 'PACH points' : 'MACH points',
        value: '${live.points} / ${a.pointsNeeded}',
      ));
      tiles.add(_StatTile(
        label: 'Double Qs',
        value: '${live.dqs} / ${a.doubleQsNeeded}',
      ));
    }
    if (a is NACQualificationTitle) {
      final live = a.liveCounts(qs);
      tiles.add(_StatTile(
        label: 'MACH points (window)',
        value: '${live.points} / ${a.pointsNeeded}',
      ));
      tiles.add(_StatTile(
        label: 'QQs (window)',
        value: '${live.qqs} / ${a.qqsNeeded}',
      ));
    }
    if (tiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stats',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: tiles),
      ],
    );
  }
}

class _ChainPill extends StatelessWidget {
  const _ChainPill({
    required this.title,
    required this.result,
    required this.isCurrent,
  });
  final Achievement title;
  final AchievementResult? result;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unlocked = result?.isUnlocked == true;
    Color bg;
    Color fg;
    if (unlocked) {
      bg = const Color(0xFFFFE9A8);
      fg = const Color(0xFF5A3500);
    } else if (result?.hasProgress == true) {
      bg = cs.primaryContainer;
      fg = cs.onPrimaryContainer;
    } else {
      bg = cs.surfaceContainerHighest;
      fg = cs.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: isCurrent ? Border.all(color: cs.primary, width: 2) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unlocked)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.check, size: 13, color: fg),
            ),
          Text(
            title.title,
            style: TextStyle(
              color: fg,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
          if (result != null && !unlocked && result!.hasProgress)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '${result!.have}/${result!.need}',
                style: TextStyle(color: fg, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
