import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../convo/add_q.dart';
import '../models/dog.dart';
import '../models/q.dart';
import '../repo/repo.dart';
import 'widgets/icon_chiclet.dart';

/// Cross-dog searchable / filterable Q history.
class QHistoryPage extends StatefulWidget {
  const QHistoryPage({super.key, required this.repo});
  final Repo repo;

  @override
  State<QHistoryPage> createState() => _QHistoryPageState();
}

class _QHistoryPageState extends State<QHistoryPage> {
  String? _dogId;
  AgilityClass? _cls;
  AgilityLevel? _level;
  bool? _preferred; // null = either, true = preferred-only, false = regular-only
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repo,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final dogs = widget.repo.dogs;
        // repo.qs is unmodifiable; make a copy before sorting.
        final all = [...widget.repo.qs]
          ..sort((a, b) => b.date.compareTo(a.date));
        final filtered = all.where(_matches).toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Q history')),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                color: cs.surfaceContainerLow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (dogs.length > 1) _dogFilter(context, dogs),
                    _classFilter(context),
                    _levelFilter(context),
                    _prefDateFilter(context),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filtered.length} Q${filtered.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          all.isEmpty
                              ? 'No Qs logged yet.'
                              : 'No Qs match these filters.',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) =>
                            _QHistoryTile(repo: widget.repo, q: filtered[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _matches(Q q) {
    if (_dogId != null && q.dogId != _dogId) return false;
    if (_cls != null && q.agilityClass != _cls) return false;
    if (_level != null && q.level != _level) return false;
    if (_preferred != null && q.preferred != _preferred) return false;
    if (_rangeStart != null && q.date.isBefore(_rangeStart!)) return false;
    if (_rangeEnd != null && q.date.isAfter(_rangeEnd!)) return false;
    return true;
  }

  Widget _dogFilter(BuildContext context, List<Dog> dogs) {
    return _ChipRow(
      label: 'Dog',
      children: [
        _filterChip(label: 'Any', selected: _dogId == null, onSelected: () {
          setState(() => _dogId = null);
        }),
        for (final d in dogs)
          _filterChip(
            label: d.callName,
            selected: _dogId == d.id,
            onSelected: () => setState(() => _dogId = d.id),
          ),
      ],
    );
  }

  Widget _classFilter(BuildContext context) {
    return _ChipRow(
      label: 'Class',
      children: [
        _filterChip(label: 'Any', selected: _cls == null, onSelected: () {
          setState(() => _cls = null);
        }),
        for (final c in AgilityClass.values)
          _filterChip(
            label: c.short,
            selected: _cls == c,
            onSelected: () => setState(() => _cls = c),
          ),
      ],
    );
  }

  Widget _levelFilter(BuildContext context) {
    return _ChipRow(
      label: 'Level',
      children: [
        _filterChip(label: 'Any', selected: _level == null, onSelected: () {
          setState(() => _level = null);
        }),
        for (final l in AgilityLevel.values)
          _filterChip(
            label: l.label,
            selected: _level == l,
            onSelected: () => setState(() => _level = l),
          ),
      ],
    );
  }

  Widget _prefDateFilter(BuildContext context) {
    return _ChipRow(
      label: 'Division',
      children: [
        _filterChip(
          label: 'Any',
          selected: _preferred == null,
          onSelected: () => setState(() => _preferred = null),
        ),
        _filterChip(
          label: 'Regular',
          selected: _preferred == false,
          onSelected: () => setState(() => _preferred = false),
        ),
        _filterChip(
          label: 'Preferred',
          selected: _preferred == true,
          onSelected: () => setState(() => _preferred = true),
        ),
        const SizedBox(width: 8),
        ActionChip(
          avatar: const Icon(Icons.date_range, size: 16),
          label: Text(_rangeLabel()),
          onPressed: () => _pickRange(context),
        ),
        if (_rangeStart != null || _rangeEnd != null)
          IconButton(
            tooltip: 'Clear dates',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() {
              _rangeStart = null;
              _rangeEnd = null;
            }),
          ),
      ],
    );
  }

  String _rangeLabel() {
    if (_rangeStart == null && _rangeEnd == null) return 'Any date';
    final f = DateFormat.MMMd();
    final s = _rangeStart != null ? f.format(_rangeStart!) : '…';
    final e = _rangeEnd != null ? f.format(_rangeEnd!) : '…';
    return '$s – $e';
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _rangeStart != null && _rangeEnd != null
          ? DateTimeRange(start: _rangeStart!, end: _rangeEnd!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _rangeStart = picked.start;
        _rangeEnd = picked.end;
      });
    }
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: children),
            ),
          ),
        ],
      ),
    );
  }
}

class _QHistoryTile extends StatelessWidget {
  const _QHistoryTile({required this.repo, required this.q});
  final Repo repo;
  final Q q;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dog = repo.dogById(q.dogId);
    final pref = q.preferred ? ' Preferred' : '';
    final levelLabel = q.agilityClass.isPremier ? '' : '${q.level.label} ';
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AddQPage(repo: repo, editing: q),
        )),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            children: [
              QRibbonChiclet(q: q, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$levelLabel${q.agilityClass.short}$pref',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (dog != null)
                          Text(
                            dog.callName,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      DateFormat.yMMMd().format(q.date),
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
