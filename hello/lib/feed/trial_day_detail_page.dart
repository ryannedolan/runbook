import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../convo/add_q.dart';
import '../models/dog.dart';
import '../models/q.dart';
import '../repo/repo.dart';
import 'widgets/icon_chiclet.dart';

/// Detail view for one trial day for one dog. The feed renders each
/// trial day as a compact card; tapping the date header opens this
/// page, which lists every Q from that day with full per-run detail
/// (class/level, time, yards/YPS, score, MACH points, trial #).
class TrialDayDetailPage extends StatelessWidget {
  const TrialDayDetailPage({
    super.key,
    required this.repo,
    required this.dogId,
    required this.date,
  });

  final Repo repo;
  final String dogId;
  final DateTime date;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _hasDoubleQ(List<Q> qs) {
    bool dq(bool preferred) =>
        qs.any((q) =>
            q.level == AgilityLevel.master &&
            q.preferred == preferred &&
            q.agilityClass == AgilityClass.standard) &&
        qs.any((q) =>
            q.level == AgilityLevel.master &&
            q.preferred == preferred &&
            q.agilityClass == AgilityClass.jww);
    return dq(false) || dq(true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final dog = repo.dogById(dogId);
        if (dog == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Trial day')),
            body: const Center(child: Text('Dog no longer exists.')),
          );
        }
        final qs = repo.qsForDog(dog.id).where((q) => _sameDay(q.date, date)).toList()
          ..sort((a, b) {
            // Group ribbons in a sensible read order: by sport, then class.
            final s = a.sport.index.compareTo(b.sport.index);
            if (s != 0) return s;
            return a.agilityClass.index.compareTo(b.agilityClass.index);
          });

        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: Text(DateFormat('EEE, MMM d, y').format(date)),
            backgroundColor: cs.surfaceContainerHighest,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _header(context, dog, qs),
              const SizedBox(height: 24),
              if (qs.isEmpty)
                Text(
                  'No Qs found for ${dog.callName} on this date.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                )
              else
                for (final q in qs) _QDetailTile(repo: repo, q: q),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, Dog dog, List<Q> qs) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.calendar_today_outlined, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${dog.callName} • ${qs.length} Q${qs.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('EEEE, MMMM d, y').format(date),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              if (_hasDoubleQ(qs))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _DoubleQPill(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QDetailTile extends StatelessWidget {
  const _QDetailTile({required this.repo, required this.q});
  final Repo repo;
  final Q q;

  String _classLabel() => switch (q.sport) {
        Sport.akcAgility => () {
            final lvl = q.agilityClass.isPremier ? '' : '${q.level.label} ';
            final pref = q.preferred ? ' Preferred' : '';
            return '$lvl${q.agilityClass.label}$pref';
          }(),
        Sport.fastCAT => 'FastCAT',
        Sport.scentwork =>
          'Scentwork ${q.scentElement?.label ?? '?'} — ${q.scentLevel?.label ?? '?'}',
      };

  List<({String label, String value})> _stats() {
    final out = <({String label, String value})>[];
    if (q.timeSeconds != null) {
      out.add((
        label: q.sport == Sport.scentwork ? 'Search time' : 'Time',
        value: '${q.timeSeconds!.toStringAsFixed(2)}s',
      ));
    }
    if (q.yards != null) {
      out.add((
        label: 'Yards',
        value: q.yards!.toStringAsFixed(0),
      ));
    }
    if (q.yps != null) {
      out.add((label: 'YPS', value: q.yps!.toStringAsFixed(2)));
    }
    if (q.score != null) {
      final lbl = q.sport == Sport.fastCAT ? 'Points' : 'Score';
      out.add((label: lbl, value: q.score!.toString()));
    }
    if (q.machPoints > 0) {
      out.add((
        label: q.preferred ? 'PACH pts' : 'MACH pts',
        value: q.machPoints.toString(),
      ));
    }
    if (q.placement != null && q.placement! >= 1 && q.placement! <= 4) {
      const place = {1: '1st', 2: '2nd', 3: '3rd', 4: '4th'};
      out.add((label: 'Place', value: place[q.placement!]!));
    }
    if (q.trial != null) {
      out.add((label: 'Trial', value: q.trial!));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stats = _stats();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    QRibbonChiclet(q: q, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _classLabel(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (stats.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      for (final s in stats)
                        _StatChip(label: s.label, value: s.value),
                    ],
                  ),
                ],
                if (q.notes != null && q.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    q.notes!,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _DoubleQPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE6C547),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'DOUBLE-Q',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: Color(0xFF5A3500),
        ),
      ),
    );
  }
}
