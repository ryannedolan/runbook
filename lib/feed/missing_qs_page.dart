import 'package:flutter/material.dart';

import '../models/dog.dart';
import '../models/q.dart';
import '../repo/repo.dart';
import '../rules/achievement.dart';
import '../rules/akc_agility.dart';
import '../rules/akc_scentwork.dart';
import '../rules/engine.dart';
import 'achievement_detail_page.dart';
import 'feed_items.dart';

/// "What does AKC say I have that I haven't logged yet?" — diffs each
/// dog's recorded Q count against the override count the user entered
/// (typically off the AKC points-progression report) and lists every
/// pool with a positive gap.
class MissingQsPage extends StatelessWidget {
  const MissingQsPage({super.key, required this.repo});
  final Repo repo;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final reports = _buildReports(repo);
        final totalMissing = reports.fold<int>(
          0,
          (s, r) => s + r.items.fold<int>(0, (a, it) => a + it.missing),
        );
        return Scaffold(
          appBar: AppBar(
            title: const Text('Missing Qs'),
            backgroundColor: cs.inversePrimary,
          ),
          body: reports.isEmpty
              ? _emptyState(context)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Text(
                      '$totalMissing missing across ${reports.length} '
                      'dog${reports.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final r in reports) ...[
                      _DogSection(repo: repo, report: r),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'Tap a row to open the title and adjust its Q count, '
                      'or log the missing run.',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _emptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 56, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              'No missing Qs.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Nothing to chase down. If AKC reports more Qs than you've "
              'logged for a title, open that title and tap the + next to '
              'its count.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _DogSection extends StatelessWidget {
  const _DogSection({required this.repo, required this.report});
  final Repo repo;
  final _DogReport report;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pets, size: 18),
              const SizedBox(width: 8),
              Text(
                report.dog.callName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${report.totalMissing} missing',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final it in report.items)
            _MissingRow(repo: repo, dog: report.dog, item: it),
        ],
      ),
    );
  }
}

class _MissingRow extends StatelessWidget {
  const _MissingRow(
      {required this.repo, required this.dog, required this.item});
  final Repo repo;
  final Dog dog;
  final _MissingItem item;

  void _open(BuildContext context) {
    // Build an AchievementFeedItem so the detail page can compute its
    // chain context. The detail page re-evaluates from scratch on
    // every build, so this stub item is just an anchor.
    final qs = repo.qsForDog(dog.id);
    final overrides = repo.overridesForDog(dog.id);
    final result = RulesEngine().evaluate(qs, overrides: overrides).firstWhere(
          (r) => r.achievement.id == item.achievement.id,
          orElse: () => item.achievement.evaluate(qs),
        );
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AchievementDetailPage(
        repo: repo,
        item: AchievementFeedItem(dog: dog, result: result, allQs: qs),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.poolLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${item.real} recorded · ${item.reported} reported',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${item.missing} missing',
                style: TextStyle(
                  color: cs.onErrorContainer,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

class _DogReport {
  _DogReport({required this.dog, required this.items});
  final Dog dog;
  final List<_MissingItem> items;
  int get totalMissing => items.fold(0, (s, i) => s + i.missing);
}

class _MissingItem {
  _MissingItem({
    required this.achievement,
    required this.poolLabel,
    required this.real,
    required this.reported,
  });
  final Achievement achievement;
  final String poolLabel;
  final int real;
  final int reported;
  int get missing => reported - real;
}

List<_DogReport> _buildReports(Repo repo) {
  final byPool = _poolIndex();
  final out = <_DogReport>[];
  for (final dog in repo.dogs) {
    final overrides = repo.overridesForDog(dog.id);
    if (overrides.isEmpty) continue;
    final qs = repo.qsForDog(dog.id);
    final items = <_MissingItem>[];
    final seenLabels = <String>{};
    for (final entry in overrides.entries) {
      final info = byPool[entry.key];
      if (info == null) continue;
      final real = info.pool.realFor(qs);
      final reported = entry.value;
      if (reported <= real) continue;
      // Multiple titles share a pool (MX/MXB/MXS/...; MACH/MACH2)
      // — list once, anchored to the first matching achievement.
      // Implied titles still surface here: the Qs themselves are
      // still missing from our records even when the title is
      // otherwise in hand. Each pool key is independent, so there's
      // no double-count risk.
      final label = _labelForPool(entry.key, info.anchor);
      if (!seenLabels.add(label)) continue;
      items.add(_MissingItem(
        achievement: info.anchor,
        poolLabel: label,
        real: real,
        reported: reported,
      ));
    }
    if (items.isEmpty) continue;
    items.sort((a, b) => b.missing.compareTo(a.missing));
    out.add(_DogReport(dog: dog, items: items));
  }
  out.sort((a, b) => b.totalMissing.compareTo(a.totalMissing));
  return out;
}

/// Index: pool key → (Pool, anchor achievement for navigation).
Map<String, ({Pool pool, Achievement anchor})> _poolIndex() {
  final out = <String, ({Pool pool, Achievement anchor})>{};
  void register(Achievement a) {
    for (final p in a.pools) {
      out.putIfAbsent(p.key, () => (pool: p, anchor: a));
    }
  }
  for (final chain in [...allAkcChains, ...allScentChains]) {
    for (final t in chain.titles) {
      register(t);
    }
  }
  // ChampionTitle isn't in the static chains (it's emitted
  // dynamically); register one instance per family so the points + QQ
  // pools are indexed.
  for (final family in ChampionFamily.values) {
    register(championTier(family, 1));
  }
  return out;
}

/// Display label for a pool: for Q-count pools that's "Master JWW
/// Preferred" or "Scentwork Container Master"; for points/QQs/QQQs
/// pools it's the family-qualified pool name like "MACH points" or
/// "QQs (preferred)".
String _labelForPool(String poolKey, Achievement anchor) {
  switch (poolKey) {
    case 'points::mach':
      return 'MACH points';
    case 'points::pach':
      return 'PACH points';
    case 'dq::reg':
      return 'QQs (regular)';
    case 'dq::pref':
      return 'QQs (preferred)';
    case 'tq::reg':
      return 'Triple Qs (regular)';
    case 'tq::pref':
      return 'Triple Qs (preferred)';
  }
  // Q-count pools — context comes from the achievement's class/level.
  if (anchor is LevelQCountTitle) {
    final cls = anchor.agilityClass;
    final pref = anchor.preferred ? ' Preferred' : '';
    if (cls.isSingleLevel) return '${cls.label}$pref';
    return '${anchor.level.label} ${cls.label}$pref';
  }
  if (anchor is PremierCountTitle) {
    return anchor.agilityClass.label;
  }
  if (anchor is ScentElementLevelTitle) {
    return 'Scentwork ${anchor.element.label} ${anchor.level.label}';
  }
  return anchor.title;
}
