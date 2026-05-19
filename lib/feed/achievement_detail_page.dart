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

/// Achievement detail. The page's identity is the *active* title (the
/// one the user opened from the feed). The chain pills below the header
/// let the user peek at sibling titles' Qs and stats without leaving —
/// only the lower sections (`_qsSection`, `_statsSection`) re-bind to
/// the viewed title; the header, app bar, and chain remain anchored on
/// the active title.
class AchievementDetailPage extends StatefulWidget {
  const AchievementDetailPage({
    super.key,
    required this.repo,
    required this.item,
  });

  final Repo repo;
  final AchievementFeedItem item;

  @override
  State<AchievementDetailPage> createState() => _AchievementDetailPageState();
}

class _AchievementDetailPageState extends State<AchievementDetailPage> {
  /// Which chain title's Qs/stats are currently shown below. Defaults
  /// to the active title; tapping a chain pill flips it.
  String? _viewedAchievementId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repo,
      builder: (context, _) {
        final dog = widget.repo.dogById(widget.item.dog.id);
        if (dog == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Achievement')),
            body: const Center(child: Text('Dog no longer exists.')),
          );
        }
        final qs = widget.repo.qsForDog(dog.id);
        final overrides = widget.repo.overridesForDog(dog.id);
        final engine = RulesEngine();
        final activeResult = engine
            .evaluate(qs, overrides: overrides)
            .firstWhere(
              (r) => r.achievement.id == widget.item.result.achievement.id,
              orElse: () => widget.item.result,
            );
        final activeAchievement = activeResult.achievement;
        final chain = chainOf(activeAchievement, qs: qs);

        // Resolve the currently-viewed sibling: defaults to active.
        Achievement viewedAchievement = activeAchievement;
        if (chain != null && _viewedAchievementId != null) {
          for (final t in chain.titles) {
            if (t.id == _viewedAchievementId) {
              viewedAchievement = t;
              break;
            }
          }
        }
        // Look up the override-adjusted viewed result from the engine
        // (single-title evaluate would skip override application).
        AchievementResult viewedResult;
        if (viewedAchievement.id == activeAchievement.id) {
          viewedResult = activeResult;
        } else {
          final all = engine.evaluate(qs, overrides: overrides);
          viewedResult = all.firstWhere(
            (r) => r.achievement.id == viewedAchievement.id,
            orElse: () => viewedAchievement.evaluate(qs),
          );
        }

        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: Text(activeAchievement.title),
            backgroundColor: activeResult.isUnlocked
                ? const Color(0xFFFFE9A8)
                : cs.surfaceContainerHighest,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _header(context, activeResult, dog.callName),
              const SizedBox(height: 24),
              if (chain != null)
                _chainSection(
                  context,
                  chain,
                  viewedAchievement,
                  qs,
                ),
              if (viewedAchievement.id != activeAchievement.id)
                _viewingBanner(context, viewedAchievement, activeAchievement),
              // Skip the adjuster row entirely when this title was
              // unlocked by a higher-level Q — backfilling phantoms
              // doesn't change anything (the title is already in hand)
              // and offering the button is misleading.
              if (viewedResult.impliedBy == null)
                for (final pool in viewedAchievement.pools)
                  _PoolAdjuster(
                    repo: widget.repo,
                    dogId: dog.id,
                    pool: pool,
                    realCount: pool.realFor(qs),
                    need: viewedAchievement.needForPool(pool.key) ?? 0,
                  ),
              // Stats first — Qs lists can run long for high-tier
              // titles and shouldn't bury the summary.
              _statsSection(context, viewedResult, qs),
              _qsSection(context, viewedResult, qs, dog.id),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DogProfilePage(repo: widget.repo, dogId: dog.id),
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

  /// Small "Viewing <title>" strip that makes it obvious the Qs/stats
  /// sections are showing a sibling title in the chain, not the active
  /// one. Tap to snap back.
  Widget _viewingBanner(
    BuildContext context,
    Achievement viewed,
    Achievement active,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _viewedAchievementId = null),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.visibility, size: 16, color: cs.onPrimaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Viewing ${viewed.title} below. Tap to return to ${active.title}.',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                  r.unlockedAt != null
                      ? 'Unlocked ${DateFormat.yMMMd().format(r.unlockedAt!)}'
                          '${r.impliedBy != null ? '\n(Implied by a ${r.impliedBy} Q)' : ''}'
                      : 'Unlocked (count adjusted manually — no recorded date)',
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
    Achievement viewed,
    List<Q> qs,
  ) {
    final cs = Theme.of(context).colorScheme;
    final engine = RulesEngine();
    final results = engine.evaluate(
      qs,
      overrides: widget.repo.overridesForDog(widget.item.dog.id),
    );
    AchievementResult? rOf(Achievement a) {
      for (final r in results) {
        if (r.achievement.id == a.id) return r;
      }
      return null;
    }

    final i = chain.titles.indexOf(viewed);
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
                onTap: idx == i
                    ? null
                    : () => setState(() =>
                        _viewedAchievementId = chain.titles[idx].id),
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
            builder: (_) => AddQPage(repo: widget.repo, editing: q),
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
    final overrides = widget.repo.overridesForDog(widget.item.dog.id);

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
      final live = a.liveCounts(qs, overrides: overrides);
      // PAX has no points pool — skip that tile.
      if (a.pointsPerLevel != 0) {
        tiles.add(_StatTile(
          label: a.preferred ? 'PACH points' : 'MACH points',
          value: '${live.points} / ${a.pointsNeeded}',
        ));
      }
      tiles.add(_StatTile(
        label: 'QQs',
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
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ChainPill extends StatelessWidget {
  const _ChainPill({
    required this.title,
    required this.result,
    required this.isCurrent,
    this.onTap,
  });
  final Achievement title;
  final AchievementResult? result;
  final bool isCurrent;
  final VoidCallback? onTap;

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
    final pill = Container(
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
    if (onTap == null) return pill;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: pill,
    );
  }
}

/// +/- adjuster for a title's pool count. Lets the user reconcile the
/// AKC points-progression report against the Qs they've actually
/// recorded. The override count is stored per-pool in Repo and
/// applied at engine.evaluate() time.
///
///   - `+` enabled iff effective < currentTitle.need. Raising past the
///     current title's need is pointless from here — drill into a
///     harder tier (e.g. MXB instead of MX) to push higher.
///   - `-` enabled iff override > real. Only "phantom" Qs are
///     removable from this view; recorded Qs are immutable here.
class _PoolAdjuster extends StatelessWidget {
  const _PoolAdjuster({
    required this.repo,
    required this.dogId,
    required this.pool,
    required this.realCount,
    required this.need,
  });

  final Repo repo;
  final String dogId;
  final Pool pool;
  final int realCount;
  final int need;

  int get _override => repo.overrideForPool(dogId, pool.key);
  int get _effective => realCount > _override ? realCount : _override;

  Future<void> _bump(int delta) async {
    // `+` operates on the displayed (effective) value so a tap always
    // produces a visible bump even when real > override (otherwise
    // tapping + while real=10, override=0 would set override=1 but
    // leave the display at 10/N — looks broken).
    //
    // `-` operates on the raw override, since reducing past real is
    // already gated by the canDecrement check.
    final newOverride = delta > 0
        ? _effective + delta
        : (_override + delta);
    await repo.setOverride(dogId, pool.key, newOverride.clamp(0, 1 << 30));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canIncrement = _effective < need;
    final canDecrement = _override > realCount;
    final manual = _override > realCount ? _override - realCount : 0;
    final unit = pool.label.toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  pool.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '$_effective / $need',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  visualDensity: VisualDensity.compact,
                  onPressed: canDecrement ? () => _bump(-1) : null,
                  tooltip: 'Remove a manually added $unit',
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  visualDensity: VisualDensity.compact,
                  onPressed: canIncrement ? () => _bump(1) : null,
                  tooltip: 'Add a $unit',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              manual == 0
                  ? '$realCount recorded'
                  : '$realCount recorded + $manual added manually',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
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
