import 'package:flutter/material.dart';

import '../../models/q.dart';
import '../../rules/achievement.dart';

// ============================================================================
// IconChiclet — a colored rounded-square (or circle) holding a Material
// icon. The chiclet's color carries the meaning (sport, level, placement,
// tier); the icon glyph stays uniform within a family.
// ============================================================================

enum ChicletShape { square, circle }

class IconChiclet extends StatelessWidget {
  const IconChiclet({
    super.key,
    required this.icon,
    required this.background,
    this.foreground = Colors.white,
    this.size = 40,
    this.iconSize,
    this.shape = ChicletShape.square,
    this.borderColor,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;

  /// Defaults to `size * 0.62` when null.
  final double? iconSize;
  final ChicletShape shape;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final glyphSize = iconSize ?? size * 0.62;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: shape == ChicletShape.circle
            ? null
            : BorderRadius.circular(size * 0.22),
        shape: shape == ChicletShape.circle
            ? BoxShape.circle
            : BoxShape.rectangle,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1)
            : null,
      ),
      child: Icon(icon, color: foreground, size: glyphSize),
    );
  }
}

// ============================================================================
// Q ribbon — a bookmark-shaped chiclet (Icons.bookmark mimics a flat
// ribbon). Q ribbons are green for agility/scentwork, light blue for
// FastCAT. A placed Q renders alongside a placement chiclet.
// ============================================================================

class QRibbonChiclet extends StatelessWidget {
  const QRibbonChiclet({super.key, required this.q, this.size = 28});
  final Q q;
  final double size;

  Color _qColor() => switch (q.sport) {
        Sport.akcAgility => Colors.green.shade600,
        Sport.scentwork => Colors.green.shade700,
        Sport.fastCAT => Colors.lightBlue.shade400,
      };

  @override
  Widget build(BuildContext context) {
    final placement = q.placement;
    // AKC awards ribbons for 1st–4th only. Beyond 4th (common in
    // scentwork and FastCAT, where placement counts every qualifying
    // dog) the placement number isn't a ribbon-worthy distinction, so
    // we render just the green Q ribbon.
    final showPlacement =
        placement != null && placement >= 1 && placement <= 4;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconChiclet(
          icon: Icons.bookmark,
          background: _qColor(),
          size: size,
        ),
        if (showPlacement) ...[
          SizedBox(width: size * 0.15),
          PlacementChiclet(placement: placement, size: size),
        ],
      ],
    );
  }
}

/// Standalone placement ribbon (1st/2nd/3rd/4th).
class PlacementChiclet extends StatelessWidget {
  const PlacementChiclet({super.key, required this.placement, this.size = 28});
  final int placement;
  final double size;

  @override
  Widget build(BuildContext context) {
    final spec = _placementSpec(placement);
    return IconChiclet(
      icon: Icons.bookmark,
      background: spec.background,
      foreground: spec.foreground,
      size: size,
      borderColor: spec.borderColor,
    );
  }
}

class _PlacementSpec {
  const _PlacementSpec(this.background, {this.foreground = Colors.white, this.borderColor});
  final Color background;
  final Color foreground;
  final Color? borderColor;
}

_PlacementSpec _placementSpec(int p) => switch (p) {
      1 => _PlacementSpec(Colors.blue.shade700),
      2 => _PlacementSpec(Colors.red.shade700),
      3 => _PlacementSpec(Colors.amber.shade600),
      4 => _PlacementSpec(
            Colors.grey.shade100,
            foreground: Colors.grey.shade700,
            borderColor: Colors.grey.shade400,
          ),
      _ => _PlacementSpec(Colors.grey.shade400),
    };

// ============================================================================
// Title rosette — chiclet for an Achievement. Color encodes the level
// chain and tier; icon stays consistent so the family reads at a glance.
// ============================================================================

class TitleChiclet extends StatelessWidget {
  const TitleChiclet({
    super.key,
    required this.achievement,
    this.size = 48,
    this.dimmed = false,
  });

  final Achievement achievement;
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final spec = _titleSpecFor(achievement);
    return Opacity(
      opacity: dimmed ? 0.45 : 1.0,
      child: IconChiclet(
        icon: spec.icon,
        background: spec.background,
        foreground: spec.foreground,
        size: size,
        shape: spec.shape,
      ),
    );
  }
}

class _TitleSpec {
  const _TitleSpec({
    required this.icon,
    required this.background,
    this.foreground = Colors.white,
    this.shape = ChicletShape.square,
  });
  final IconData icon;
  final Color background;
  final Color foreground;
  final ChicletShape shape;
}

_TitleSpec _titleSpecFor(Achievement a) {
  if (a is NACQualificationTitle) {
    return _TitleSpec(
      icon: Icons.emoji_events,
      background: Colors.indigo.shade700,
      foreground: Colors.amber.shade300,
    );
  }
  if (a is PointAccumulationTitle && a.sportFilter == Sport.fastCAT) {
    return _TitleSpec(
      icon: Icons.bolt,
      background: a.pointsNeeded >= 1000
          ? Colors.lightBlue.shade700
          : Colors.lightBlue.shade500,
    );
  }
  if (a is ScentElementLevelTitle) {
    // tint by level (deeper = harder)
    final l = a.level;
    final shade = switch (l) {
      ScentLevel.novice => Colors.teal.shade400,
      ScentLevel.advanced => Colors.teal.shade600,
      ScentLevel.excellent => Colors.teal.shade700,
      ScentLevel.master => Colors.teal.shade800,
      ScentLevel.detective => Colors.teal.shade900,
    };
    return _TitleSpec(
      icon: Icons.search,
      background: shade,
    );
  }
  if (a is ChampionTitle) {
    return _TitleSpec(
      icon: Icons.military_tech,
      background: a.preferred ? Colors.deepPurple.shade700 : Colors.red.shade800,
      foreground: Colors.amber.shade300,
      shape: ChicletShape.circle,
    );
  }
  if (a is TripleQTitle) {
    return _TitleSpec(
      icon: Icons.filter_3,
      background: a.preferred ? Colors.deepPurple.shade500 : Colors.red.shade600,
      foreground: Colors.amber.shade200,
    );
  }
  if (a is PremierCountTitle) {
    return _TitleSpec(
      icon: Icons.workspace_premium,
      background: Colors.orange.shade700,
    );
  }
  if (a is LevelQCountTitle) {
    final preferred = a.preferred;
    final l = a.level;
    if (l == AgilityLevel.master) {
      final n = a.qCountNeeded;
      if (n >= 100) {
        return _TitleSpec(
          icon: Icons.workspace_premium,
          background: Colors.amber.shade700,
          foreground: Colors.amber.shade50,
        );
      }
      if (n >= 50) {
        return _TitleSpec(
          icon: Icons.workspace_premium,
          background: Colors.blueGrey.shade400,
        );
      }
      if (n >= 25) {
        return _TitleSpec(
          icon: Icons.workspace_premium,
          background: Colors.brown.shade400,
        );
      }
      // Entry Master (MX/MXJ vs MXP/MJP)
      return _TitleSpec(
        icon: Icons.workspace_premium,
        background:
            preferred ? Colors.deepPurple.shade700 : Colors.indigo.shade800,
      );
    }
    if (l == AgilityLevel.excellent) {
      return _TitleSpec(
        icon: Icons.workspace_premium,
        background: preferred ? Colors.purple.shade600 : Colors.red.shade700,
      );
    }
    if (l == AgilityLevel.open) {
      return _TitleSpec(
        icon: Icons.workspace_premium,
        background: preferred ? Colors.purple.shade400 : Colors.blue.shade700,
      );
    }
    // Novice
    return _TitleSpec(
      icon: Icons.workspace_premium,
      background: preferred ? Colors.purple.shade300 : Colors.green.shade700,
    );
  }
  return _TitleSpec(
    icon: Icons.workspace_premium,
    background: Colors.grey.shade600,
  );
}

// ============================================================================
// Analytics chiclet — kind drives the icon, neutral palette.
// ============================================================================

enum AnalyticsChicletKind { personalBest, topAverage, trend }

class AnalyticsChiclet extends StatelessWidget {
  const AnalyticsChiclet({super.key, required this.kind, this.size = 44});
  final AnalyticsChicletKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = switch (kind) {
      AnalyticsChicletKind.personalBest => Icons.workspace_premium_outlined,
      AnalyticsChicletKind.topAverage => Icons.leaderboard,
      AnalyticsChicletKind.trend => Icons.show_chart,
    };
    return IconChiclet(
      icon: icon,
      background: cs.secondary.withValues(alpha: 0.16),
      foreground: cs.onSecondaryContainer,
      size: size,
    );
  }
}

// ============================================================================
// Tip chiclet — small dismissible-pickup or encouragement reminder.
// ============================================================================

class TipChiclet extends StatelessWidget {
  const TipChiclet({super.key, this.isCollectable = false, this.size = 36});
  final bool isCollectable;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconChiclet(
      icon: isCollectable ? Icons.bookmark_outline : Icons.local_fire_department,
      background: cs.tertiary.withValues(alpha: 0.20),
      foreground: cs.tertiary,
      size: size,
    );
  }
}
