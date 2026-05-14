import '../models/dog.dart';
import '../models/q.dart';
import 'feed_items.dart';

/// Builds derived-stat feed cards (personal bests, top-3 averages,
/// recent-run trends) for a dog. Each card is emitted only when enough
/// Qs exist to make the stat meaningful.
List<AnalyticsFeedItem> buildAnalyticsForDog({
  required Dog dog,
  required List<Q> qs,
}) {
  final out = <AnalyticsFeedItem>[];

  // Partition by (class, preferred) — we don't want to mix Std and JWW
  // times because the courses are different.
  final groups = <_Key, List<Q>>{};
  for (final q in qs) {
    final k = _Key(q.agilityClass, q.preferred);
    groups.putIfAbsent(k, () => []).add(q);
  }

  for (final entry in groups.entries) {
    final k = entry.key;
    final items = entry.value..sort((a, b) => a.date.compareTo(b.date));
    final label = '${k.cls.short}${k.preferred ? ' Pref' : ''}';
    out.addAll(_statsForGroup(dog: dog, classLabel: label, qs: items));
  }

  return out;
}

class _Key {
  const _Key(this.cls, this.preferred);
  final AgilityClass cls;
  final bool preferred;
  @override
  bool operator ==(Object other) =>
      other is _Key && other.cls == cls && other.preferred == preferred;
  @override
  int get hashCode => Object.hash(cls, preferred);
}

List<AnalyticsFeedItem> _statsForGroup({
  required Dog dog,
  required String classLabel,
  required List<Q> qs,
}) {
  final out = <AnalyticsFeedItem>[];
  final withTime = qs.where((q) => q.timeSeconds != null).toList()
    ..sort((a, b) => a.timeSeconds!.compareTo(b.timeSeconds!));
  final withYps = qs.where((q) => q.yps != null).toList()
    ..sort((a, b) => b.yps!.compareTo(a.yps!));

  // Personal best — fastest time (≥1 Q with time).
  if (withTime.isNotEmpty) {
    final best = withTime.first;
    out.add(AnalyticsFeedItem(
      id: '${dog.id}.pb.time.$classLabel',
      dog: dog,
      kind: AnalyticsKind.personalBest,
      title: 'Fastest $classLabel run',
      subtitle: 'Personal best for ${dog.callName}',
      value: best.timeSeconds!.toStringAsFixed(1),
      unit: 's',
      timestamp: best.date,
      contributingQIds: [best.id],
    ));
  }

  // Personal best — highest YPS (≥1 Q with both yards + time).
  if (withYps.isNotEmpty) {
    final best = withYps.first;
    out.add(AnalyticsFeedItem(
      id: '${dog.id}.pb.yps.$classLabel',
      dog: dog,
      kind: AnalyticsKind.personalBest,
      title: 'Top $classLabel speed',
      subtitle: 'Best yards-per-second for ${dog.callName}',
      value: best.yps!.toStringAsFixed(2),
      unit: ' YPS',
      timestamp: best.date,
      contributingQIds: [best.id],
    ));
  }

  // Top-3 average time — need ≥3 Qs with time.
  if (withTime.length >= 3) {
    final top3 = withTime.take(3).toList();
    final avg = top3.fold<double>(0, (s, q) => s + q.timeSeconds!) / 3;
    out.add(AnalyticsFeedItem(
      id: '${dog.id}.avg3.time.$classLabel',
      dog: dog,
      kind: AnalyticsKind.topAverage,
      title: 'Top-3 $classLabel time avg',
      subtitle: 'Average of ${dog.callName}\'s 3 fastest runs',
      value: avg.toStringAsFixed(1),
      unit: 's',
      timestamp: top3.map((q) => q.date).reduce((a, b) => a.isAfter(b) ? a : b),
      contributingQIds: [for (final q in top3) q.id],
    ));
  }

  // Trend — recent runs (≥5 Qs with time). Newest last in the trend
  // array so a downward slope = improving (lower is better for time).
  if (withTime.length >= 5) {
    final chronological = [...withTime]..sort((a, b) => a.date.compareTo(b.date));
    final recent = chronological.length > 10
        ? chronological.sublist(chronological.length - 10)
        : chronological;
    out.add(AnalyticsFeedItem(
      id: '${dog.id}.trend.time.$classLabel',
      dog: dog,
      kind: AnalyticsKind.trend,
      title: 'Recent $classLabel times',
      subtitle: '${dog.callName}\'s last ${recent.length} runs',
      value: recent.last.timeSeconds!.toStringAsFixed(1),
      unit: 's',
      timestamp: recent.last.date,
      trend: [for (final q in recent) q.timeSeconds!],
      contributingQIds: [for (final q in recent) q.id],
    ));
  }

  return out;
}
