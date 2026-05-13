import 'package:flutter/material.dart';

import '../models/dog.dart';
import '../models/q.dart';
import '../repo/repo.dart';
import 'add_dog.dart';
import 'convo.dart';

/// Conversation that adds Qs. Allows adding multiple in a row without
/// restarting from scratch.
class AddQPage extends StatefulWidget {
  const AddQPage({super.key, required this.repo, this.preselectedDogId});
  final Repo repo;
  final String? preselectedDogId;

  @override
  State<AddQPage> createState() => _AddQPageState();
}

class _AddQPageState extends State<AddQPage> {
  late final ConvoController _ctrl;
  int _savedCount = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = ConvoController(next: _nextStep, onComplete: _complete);
    if (widget.preselectedDogId != null) {
      // Auto-answer the dog step. We do this after the first frame so the
      // ConvoView is ready.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ctrl.answer(widget.preselectedDogId, context);
      });
    }
  }

  ConvoStep? _nextStep(Map<String, Object?> a) {
    if (!a.containsKey('dog')) {
      final dogs = widget.repo.dogs;
      final addDogAction = ChoiceAction(
        label: dogs.isEmpty ? 'Add a dog' : 'New dog',
        icon: Icons.add,
        run: (ctx, onAnswer) async {
          final dog = await Navigator.of(ctx).push<Dog>(
            MaterialPageRoute(builder: (_) => AddDogPage(repo: widget.repo)),
          );
          if (dog != null) onAnswer(dog.id);
        },
      );
      if (dogs.isEmpty) {
        return ConvoStep(
          key: 'dog',
          prompt: "You haven't added a dog yet. Let's start there.",
          input: ChoiceInput<String>(
            const [],
            extraActions: [addDogAction],
          ),
        );
      }
      return ConvoStep(
        key: 'dog',
        prompt: dogs.length == 1
            ? "Adding a Q for ${dogs.first.callName}?"
            : 'Which dog?',
        input: ChoiceInput<String>(
          [for (final d in dogs) Choice<String>(d.callName, d.id)],
          extraActions: [addDogAction],
        ),
      );
    }
    if (!a.containsKey('agilityClass')) {
      return ConvoStep(
        key: 'agilityClass',
        prompt: 'Which class?',
        input: ChoiceInput<AgilityClass>([
          for (final c in AgilityClass.values) Choice(c.label, c),
        ]),
      );
    }
    if (!a.containsKey('level')) {
      return ConvoStep(
        key: 'level',
        prompt: 'Which level?',
        input: ChoiceInput<AgilityLevel>([
          for (final l in AgilityLevel.values) Choice(l.label, l),
        ]),
      );
    }
    if (!a.containsKey('date')) {
      return ConvoStep(
        key: 'date',
        prompt: 'When was the Q?',
        input: DateInputStep(initial: DateTime.now()),
      );
    }
    // MACH points only apply at master level; skip otherwise.
    if (a['level'] == AgilityLevel.master && !a.containsKey('machPoints')) {
      return ConvoStep(
        key: 'machPoints',
        prompt: 'MACH points earned? (optional)',
        input: NumberInputStep(hint: 'e.g. 24'),
      );
    }
    if (!a.containsKey('addAnother')) {
      final dog = widget.repo.dogById(a['dog'] as String);
      final name = dog?.callName ?? 'this dog';
      return ConvoStep(
        key: 'addAnother',
        prompt: _savedCount == 0
            ? 'Want to add another Q for $name?'
            : 'Saved! Add another Q for $name?',
        input: ChoiceInput<bool>([
          Choice('Yes, another', true),
          Choice('All done', false),
        ]),
      );
    }
    return null;
  }

  Future<void> _complete(BuildContext ctx, Map<String, Object?> a) async {
    final q = Q.create(
      dogId: a['dog'] as String,
      date: a['date'] as DateTime,
      agilityClass: a['agilityClass'] as AgilityClass,
      level: a['level'] as AgilityLevel,
      machPoints: (a['machPoints'] as num?)?.toInt() ?? 0,
    );
    await widget.repo.addQ(q);
    _savedCount++;

    if (a['addAnother'] == true) {
      // Keep dog, drop everything else.
      _ctrl.rewindToKey('agilityClass');
    } else {
      if (ctx.mounted) Navigator.of(ctx).pop(_savedCount);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log a Q')),
      body: ConvoView(controller: _ctrl),
    );
  }
}
