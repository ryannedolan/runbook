import '../models/q.dart';
import 'achievement.dart';
import 'akc_agility.dart';

typedef Gate = bool Function(List<Q> qs);

/// A node in the achievement rules tree. Either a leaf (an Achievement),
/// a group of children, or a gated sub-tree.
class RuleNode {
  RuleNode._({
    this.achievement,
    this.title,
    this.children = const [],
    this.gate,
    this.gatedChild,
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

  final Achievement? achievement;
  final String? title;
  final List<RuleNode> children;
  final Gate? gate;
  final RuleNode? gatedChild;

  /// Walks the tree and produces an evaluation result for every reachable
  /// achievement.
  void walk(List<Q> qs, List<AchievementResult> out) {
    if (achievement != null) {
      out.add(achievement!.evaluate(qs));
      return;
    }
    if (gate != null) {
      if (gate!(qs)) gatedChild!.walk(qs, out);
      return;
    }
    for (final child in children) {
      child.walk(qs, out);
    }
  }
}

/// The rules engine. Evaluates the full tree of achievement rules
/// against a list of Qs.
class RulesEngine {
  RulesEngine({List<RuleNode>? trees})
      : _trees = trees ?? [akcAgilityTree()];

  final List<RuleNode> _trees;

  /// All achievements that have any progress (in-progress or unlocked).
  List<AchievementResult> evaluate(List<Q> qs) {
    final results = <AchievementResult>[];
    for (final tree in _trees) {
      tree.walk(qs, results);
    }
    return results.where((r) => r.hasProgress).toList();
  }
}
