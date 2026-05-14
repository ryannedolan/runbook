import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../convo/add_dog.dart';
import '../convo/add_q.dart';
import '../models/dog.dart';
import '../models/q.dart';
import '../repo/repo.dart';
import 'widgets/ribbons.dart';

class DogProfilePage extends StatelessWidget {
  const DogProfilePage({super.key, required this.repo, required this.dogId});
  final Repo repo;
  final String dogId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final dog = repo.dogById(dogId);
        if (dog == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Dog')),
            body: const Center(child: Text('This dog has been removed.')),
          );
        }
        final qs = repo.qsForDog(dogId)
          ..sort((a, b) => b.date.compareTo(a.date));
        return _DogProfileBody(repo: repo, dog: dog, qs: qs);
      },
    );
  }
}

class _DogProfileBody extends StatelessWidget {
  const _DogProfileBody({required this.repo, required this.dog, required this.qs});
  final Repo repo;
  final Dog dog;
  final List<Q> qs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(dog.callName),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _onEdit(context),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _onDelete(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Log a Q'),
        onPressed: () => _onAddQ(context),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _kv(context, 'Breed', dog.breed ?? '—'),
          _kv(context, 'Height', dog.heightInches != null
              ? '${_fmt(dog.heightInches!)} in'
              : '—'),
          if (dog.notes != null && dog.notes!.isNotEmpty)
            _kv(context, 'Notes', dog.notes!),
          const SizedBox(height: 16),
          Text(
            'Qs (${qs.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (qs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No Qs logged yet. Tap "Log a Q" to add one.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            )
          else
            for (final q in qs)
              _QRow(
                q: q,
                onTap: () => _onEditQ(context, q),
                onDelete: () => _onDeleteQ(context, q),
              ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(k, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(1);

  Future<void> _onEdit(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddDogPage(repo: repo, editing: dog),
      ),
    );
  }

  Future<void> _onDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${dog.callName}?'),
        content: Text(
          qs.isEmpty
              ? 'This will remove the dog from your list.'
              : 'This will remove ${dog.callName} and ${qs.length} Q${qs.length == 1 ? '' : 's'}. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await repo.deleteDog(dog.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _onAddQ(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddQPage(repo: repo, preselectedDogId: dog.id),
      ),
    );
  }

  Future<void> _onEditQ(BuildContext context, Q q) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddQPage(repo: repo, editing: q),
      ),
    );
  }

  Future<void> _onDeleteQ(BuildContext context, Q q) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this Q?'),
        content: Text(
          '${q.level.label} ${q.agilityClass.short}'
          '${q.preferred ? ' Preferred' : ''} on '
          '${DateFormat.yMMMd().format(q.date)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await repo.deleteQ(q.id);
    }
  }
}

class _QRow extends StatelessWidget {
  const _QRow({required this.q, required this.onTap, required this.onDelete});
  final Q q;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pref = q.preferred ? ' Preferred' : '';
    final levelLabel = q.agilityClass.isPremier ? '' : '${q.level.label} ';
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              FlatRibbon.forQ(q, height: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$levelLabel${q.agilityClass.short}$pref',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      DateFormat.yMMMd().format(q.date),
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (q.machPoints > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${q.machPoints} pts',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
              IconButton(
                tooltip: 'Delete',
                icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
