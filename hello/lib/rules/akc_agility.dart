import '../models/q.dart';
import 'achievement.dart';
import 'engine.dart';

/// AKC agility title rules, organized as a gated decision tree.
RuleNode akcAgilityTree() {
  return RuleNode.group(
    title: 'AKC Agility',
    children: [
      // Standard class titles. Always evaluated.
      RuleNode.leaf(LevelQCountTitle(
        id: 'akc.agility.std.na',
        title: 'NA',
        description: 'Novice Agility — 3 Q\'s in Novice Standard',
        agilityClass: AgilityClass.standard,
        level: AgilityLevel.novice,
        qCountNeeded: 3,
      )),
      RuleNode.leaf(LevelQCountTitle(
        id: 'akc.agility.std.oa',
        title: 'OA',
        description: 'Open Agility — 3 Q\'s in Open Standard',
        agilityClass: AgilityClass.standard,
        level: AgilityLevel.open,
        qCountNeeded: 3,
      )),
      RuleNode.leaf(LevelQCountTitle(
        id: 'akc.agility.std.ax',
        title: 'AX',
        description: 'Agility Excellent — 3 Q\'s in Excellent Standard',
        agilityClass: AgilityClass.standard,
        level: AgilityLevel.excellent,
        qCountNeeded: 3,
      )),
      RuleNode.leaf(LevelQCountTitle(
        id: 'akc.agility.std.mx',
        title: 'MX',
        description: 'Master Agility Excellent — 10 Q\'s in Master Standard',
        agilityClass: AgilityClass.standard,
        level: AgilityLevel.master,
        qCountNeeded: 10,
      )),

      // JWW class titles.
      RuleNode.leaf(LevelQCountTitle(
        id: 'akc.agility.jww.naj',
        title: 'NAJ',
        description: 'Novice Agility Jumper — 3 Q\'s in Novice JWW',
        agilityClass: AgilityClass.jww,
        level: AgilityLevel.novice,
        qCountNeeded: 3,
      )),
      RuleNode.leaf(LevelQCountTitle(
        id: 'akc.agility.jww.oaj',
        title: 'OAJ',
        description: 'Open Agility Jumper — 3 Q\'s in Open JWW',
        agilityClass: AgilityClass.jww,
        level: AgilityLevel.open,
        qCountNeeded: 3,
      )),
      RuleNode.leaf(LevelQCountTitle(
        id: 'akc.agility.jww.axj',
        title: 'AXJ',
        description: 'Excellent Agility Jumper — 3 Q\'s in Excellent JWW',
        agilityClass: AgilityClass.jww,
        level: AgilityLevel.excellent,
        qCountNeeded: 3,
      )),
      RuleNode.leaf(LevelQCountTitle(
        id: 'akc.agility.jww.mxj',
        title: 'MXJ',
        description: 'Master Excellent Jumper — 10 Q\'s in Master JWW',
        agilityClass: AgilityClass.jww,
        level: AgilityLevel.master,
        qCountNeeded: 10,
      )),

      // Combo title — only worth evaluating once there's at least one
      // Master-level Q in either class.
      RuleNode.gated(
        gate: (qs) => qs.any((q) => q.level == AgilityLevel.master),
        child: RuleNode.leaf(MachTitle()),
      ),
    ],
  );
}
