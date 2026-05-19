import '../models/q.dart';
import 'achievement.dart';
import 'akc_agility.dart';
import 'akc_fastcat.dart';
import 'akc_scentwork.dart';

typedef Gate = bool Function(List<Q> qs);

/// A node in the achievement rules tree. Either a leaf (an Achievement),
/// a group of children, a gated sub-tree, or a dynamic emitter that
/// produces a variable number of results from the Qs.
class RuleNode {
  RuleNode._({
    this.achievement,
    this.title,
    this.children = const [],
    this.gate,
    this.gatedChild,
    this.dynamicEmit,
  });

  /// Leaf node: a single achievement.
  factory RuleNode.leaf(Achievement a) => RuleNode._(achievement: a);

  /// Group node: a named container of child nodes (always evaluated).
  factory RuleNode.group({
    required String title,
    required List<RuleNode> children,
  }) =>
      RuleNode._(title: title, children: children);

  /// Gated node: child is only evaluated if `gate(qs)` is true.
  factory RuleNode.gated({required Gate gate, required RuleNode child}) =>
      RuleNode._(gate: gate, gatedChild: child);

  /// Dynamic node: produces zero or more results from the dog's Qs.
  /// Used by numbered title families (MACH/MACH2/MACH3/...) where the
  /// number of tiers worth evaluating depends on what the dog has
  /// already achieved — no fixed cap. Receives the override map so
  /// chains like MXB→MXS→MXG can keep emitting tiers that are
  /// over-the-line by override alone.
  factory RuleNode.dynamic({
    required List<AchievementResult> Function(
            List<Q> qs, Map<String, int> overrides)
        emit,
  }) =>
      RuleNode._(dynamicEmit: emit);

  final Achievement? achievement;
  final String? title;
  final List<RuleNode> children;
  final Gate? gate;
  final RuleNode? gatedChild;
  final List<AchievementResult> Function(
      List<Q> qs, Map<String, int> overrides)? dynamicEmit;

  /// Walks the tree and produces an evaluation result for every reachable
  /// achievement.
  void walk(List<Q> qs, List<AchievementResult> out,
      [Map<String, int> overrides = const {}]) {
    if (achievement != null) {
      out.add(achievement!.evaluate(qs, overrides: overrides));
      return;
    }
    if (dynamicEmit != null) {
      out.addAll(dynamicEmit!(qs, overrides));
      return;
    }
    if (gate != null) {
      if (gate!(qs)) gatedChild!.walk(qs, out, overrides);
      return;
    }
    for (final child in children) {
      child.walk(qs, out, overrides);
    }
  }
}

/// The rules engine. Evaluates the full tree of achievement rules
/// against a list of Qs.
class RulesEngine {
  RulesEngine({List<RuleNode>? trees})
      : _trees = trees ??
            [
              akcAgilityTree(),
              akcFastCATTree(),
              akcScentworkTree(),
            ];

  final List<RuleNode> _trees;

  /// All achievements that have any progress (in-progress or unlocked).
  ///
  /// [overrides] maps a [Pool.key] → user-recorded count. Achievements
  /// take `max(realFor(qs), override)` for each of their pools, with
  /// override-only crossings yielding phantom unlocks (`unlockedAt`
  /// null) — those surface on the detail page but not in the feed.
  List<AchievementResult> evaluate(
    List<Q> qs, {
    Map<String, int> overrides = const {},
  }) {
    final results = <AchievementResult>[];
    for (final tree in _trees) {
      tree.walk(qs, results, overrides);
    }
    return results.where((r) => r.hasProgress).toList();
  }
}
