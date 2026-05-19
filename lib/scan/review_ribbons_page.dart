import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../convo/add_q.dart';
import '../models/dog.dart';
import '../models/q.dart';
import '../repo/dog_import.dart';
import '../repo/repo.dart';
import 'ribbon_parser.dart';

/// After a scan session, list every captured ribbon. Each row shows
/// the parsed fields with a "needs review" marker when key pieces are
/// missing. Tap to edit in the existing convo. "Save all" persists
/// the survivors, deduping against existing Qs.
class ReviewRibbonsPage extends StatefulWidget {
  const ReviewRibbonsPage({
    super.key,
    required this.repo,
    required this.captures,
  });
  final Repo repo;
  final List<ParsedRibbon> captures;

  @override
  State<ReviewRibbonsPage> createState() => _ReviewRibbonsPageState();
}

class _ReviewRibbonsPageState extends State<ReviewRibbonsPage> {
  late List<_Row> _rows;

  @override
  void initState() {
    super.initState();
    _rows = [
      for (final c in widget.captures)
        _Row(
          q: c.q,
          dogId: c.dogId,
          matched: Set.of(c.matchedFields),
          rawText: c.rawText,
        ),
    ];
  }

  Future<void> _editRow(int i) async {
    final row = _rows[i];
    final dog = row.dogId != null ? widget.repo.dogById(row.dogId!) : null;
    if (dog == null) {
      final picked = await _pickDog();
      if (picked == null) return;
      _rows[i] = row.withDog(picked.id);
      setState(() {});
    }
    if (!mounted) return;
    // Seed the draft into the repo so AddQPage(editing:) can load
    // it; capture the (possibly updated) version after the convo
    // pops and delete the seed regardless.
    final seeded = _rows[i].q.copyWith(dogId: _rows[i].dogId ?? '');
    await widget.repo.addQ(seeded);
    if (!mounted) return;
    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => AddQPage(repo: widget.repo, editing: seeded),
      ),
    );
    final updated = widget.repo.qs.firstWhere(
      (q) => q.id == seeded.id,
      orElse: () => seeded,
    );
    await widget.repo.deleteQ(seeded.id);
    if (!mounted) return;
    if (result == 1) {
      setState(() {
        _rows[i] = _rows[i].withEditedQ(updated);
      });
    }
  }

  Future<Dog?> _pickDog() async {
    final dogs = widget.repo.dogs;
    if (dogs.isEmpty) return null;
    return showModalBottomSheet<Dog>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final d in dogs)
            ListTile(
              title: Text(d.callName),
              subtitle: d.breed != null ? Text(d.breed!) : null,
              onTap: () => Navigator.of(ctx).pop(d),
            ),
        ],
      ),
    );
  }

  void _discardRow(int i) {
    setState(() {
      _rows.removeAt(i);
    });
  }

  Future<void> _saveAll() async {
    final existingKeys = <String>{
      for (final q in widget.repo.qs) dedupeKeyFor(q),
    };
    final sessionKeys = <String>{};
    // Decide what to save vs skip and record the skip reason per row
    // so the user can see exactly what's still in the way.
    final outcome = <_Row, ({Q? save, String? skip})>{};
    for (final r in _rows) {
      if (r.dogId == null || r.dogId!.isEmpty) {
        outcome[r] = (save: null, skip: 'Pick a dog before saving.');
        continue;
      }
      if (r.q.sport == Sport.scentwork &&
          (r.q.scentElement == null || r.q.scentLevel == null)) {
        outcome[r] =
            (save: null, skip: 'Scentwork element + level required.');
        continue;
      }
      final q = r.q.copyWith(dogId: r.dogId!);
      final key = dedupeKeyFor(q);
      if (existingKeys.contains(key)) {
        outcome[r] = (
          save: null,
          skip: 'Already saved — same dog, day, class, level.',
        );
        continue;
      }
      if (!sessionKeys.add(key)) {
        outcome[r] = (
          save: null,
          skip: 'Duplicate of another row in this batch.',
        );
        continue;
      }
      outcome[r] = (save: q, skip: null);
    }

    final saved = <Q>[];
    final kept = <_Row>[];
    for (final r in _rows) {
      final o = outcome[r]!;
      if (o.save != null) {
        saved.add(o.save!);
      } else {
        kept.add(r.withSkipReason(o.skip));
      }
    }
    for (final q in saved) {
      await widget.repo.addQ(q);
    }
    if (!mounted) return;

    setState(() {
      _rows = kept;
    });

    if (kept.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved.length == 1
                ? 'Saved 1 Q.'
                : 'Saved ${saved.length} Qs.',
          ),
        ),
      );
      Navigator.of(context).pop(saved.length);
      return;
    }
    // Tally reasons for a one-line summary, then surface the page
    // itself for the user to fix each row.
    final reasonCounts = <String, int>{};
    for (final r in kept) {
      final reason = r.skipReason ?? 'Needs review.';
      reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
    }
    final summary = reasonCounts.entries
        .map((e) => e.value == 1 ? e.key : '${e.value}× ${e.key}')
        .join(' ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(
          saved.isEmpty
              ? 'Nothing saved. ${kept.length} need attention: $summary'
              : 'Saved ${saved.length}. ${kept.length} still need attention: $summary',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Review (${_rows.length})'),
        backgroundColor: cs.inversePrimary,
      ),
      body: _rows.isEmpty
          ? const Center(child: Text('No captures to review.'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: _rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _RowCard(
                row: _rows[i],
                dog: _rows[i].dogId != null
                    ? widget.repo.dogById(_rows[i].dogId!)
                    : null,
                onTap: () => _editRow(i),
                onDiscard: () => _discardRow(i),
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _rows.isEmpty ? null : _saveAll,
            icon: const Icon(Icons.save_alt),
            label: Text('Save ${_rows.length} Q${_rows.length == 1 ? '' : 's'}'),
          ),
        ),
      ),
    );
  }
}

class _Row {
  _Row({
    required this.q,
    required this.dogId,
    required this.matched,
    required this.rawText,
    this.skipReason,
  });

  final Q q;
  final String? dogId;
  final Set<String> matched;
  final String rawText;

  /// Filled in by the save attempt to explain why this row didn't get
  /// persisted (e.g. "duplicate of a saved Q"). Cleared whenever the
  /// user edits the row or the page re-runs the save.
  final String? skipReason;

  _Row withDog(String id) => _Row(
        q: q,
        dogId: id,
        matched: matched,
        rawText: rawText,
        // User just picked a dog — any prior skip reason is stale.
      );
  _Row withEditedQ(Q newQ) => _Row(
        q: newQ,
        dogId: newQ.dogId.isEmpty ? dogId : newQ.dogId,
        // After manual edit we trust everything.
        matched: {
          'sport',
          'date',
          if (newQ.sport == Sport.akcAgility) ...['agilityClass', 'level'],
          if (newQ.sport == Sport.scentwork) ...['scentElement', 'scentLevel'],
        },
        rawText: rawText,
        // Edit invalidates the previous skip reason.
      );
  _Row withSkipReason(String? reason) => _Row(
        q: q,
        dogId: dogId,
        matched: matched,
        rawText: rawText,
        skipReason: reason,
      );
}

class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.row,
    required this.dog,
    required this.onTap,
    required this.onDiscard,
  });
  final _Row row;
  final Dog? dog;
  final VoidCallback onTap;
  final VoidCallback onDiscard;

  bool get _needsReview {
    if (row.skipReason != null) return true;
    if (dog == null) return true;
    if (row.q.sport == Sport.scentwork) {
      if (row.q.scentElement == null || row.q.scentLevel == null) return true;
    }
    if (!row.matched.contains('date')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: _needsReview
          ? cs.errorContainer.withValues(alpha: 0.4)
          : cs.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          dog?.callName ?? '(no dog matched)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _SportBadge(sport: row.q.sport),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _line2(),
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _line3(),
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                    if (_needsReview)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _reviewReason(),
                          style: TextStyle(
                            color: cs.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Discard',
                onPressed: onDiscard,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _line2() {
    final q = row.q;
    final bits = <String>[];
    if (row.matched.contains('date')) {
      bits.add(DateFormat('EEE, MMM d, y').format(q.date));
    }
    switch (q.sport) {
      case Sport.akcAgility:
        final cls = q.agilityClass!.label;
        final lvl = q.agilityClass!.isPremier
            ? 'Master'
            : (row.matched.contains('level') ? q.level!.label : '');
        final pref = q.preferred ? ' Preferred' : '';
        bits.add('$lvl $cls$pref'.trim());
        break;
      case Sport.fastCAT:
        bits.add('FastCAT');
        break;
      case Sport.scentwork:
        final el = q.scentElement?.label ?? '?';
        final lv = q.scentLevel?.label ?? '?';
        bits.add('Scentwork $el — $lv');
        break;
    }
    return bits.join(' · ');
  }

  String _line3() {
    final q = row.q;
    final bits = <String>[];
    if (q.timeSeconds != null) {
      bits.add('${q.timeSeconds!.toStringAsFixed(2)}s');
    }
    if (q.yards != null) bits.add('${q.yards!.toStringAsFixed(0)} yds');
    if (q.machPoints > 0) bits.add('${q.machPoints} pts');
    if (q.score != null) bits.add('score ${q.score}');
    if (q.placement != null) bits.add('place ${q.placement}');
    if (q.trial != null) bits.add(q.trial!);
    return bits.isEmpty ? 'Tap to fill in details' : bits.join(' · ');
  }

  String _reviewReason() {
    // Skip-reasons from a save attempt are the most specific signal —
    // surface them verbatim. Otherwise compute the next missing thing.
    if (row.skipReason != null) return row.skipReason!;
    if (dog == null) return 'Pick a dog before saving';
    if (row.q.sport == Sport.scentwork &&
        (row.q.scentElement == null || row.q.scentLevel == null)) {
      return 'Element/level missing — tap to set';
    }
    if (!row.matched.contains('date')) return 'Date missing — tap to set';
    return 'Tap to review';
  }
}

class _SportBadge extends StatelessWidget {
  const _SportBadge({required this.sport});
  final Sport sport;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        sport.short.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: cs.onSecondaryContainer,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

