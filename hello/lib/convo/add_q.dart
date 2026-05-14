import 'package:flutter/material.dart';

import '../models/dog.dart';
import '../models/q.dart';
import '../repo/repo.dart';
import 'add_dog.dart';
import 'convo.dart';

/// Conversation that adds (or edits) Qs. When `editing` is non-null we
/// only allow one save and then pop. When adding fresh, we support
/// adding multiple Qs in a row without restarting.
class AddQPage extends StatefulWidget {
  const AddQPage({
    super.key,
    required this.repo,
    this.preselectedDogId,
    this.editing,
  });
  final Repo repo;
  final String? preselectedDogId;
  final Q? editing;

  @override
  State<AddQPage> createState() => _AddQPageState();
}

typedef _ClassDivision = (AgilityClass cls, bool preferred);

class _AddQPageState extends State<AddQPage> {
  late final ConvoController _ctrl;
  int _savedCount = 0;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _ctrl = ConvoController(next: _nextStep, onComplete: _complete);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final q = widget.editing;
      if (q != null) {
        await _ctrl.answer(q.dogId, context);
        if (!mounted) return;
        await _ctrl.answer((q.agilityClass, q.preferred), context);
        if (!mounted) return;
        if (!q.agilityClass.isPremier) {
          await _ctrl.answer(q.level, context);
          if (!mounted) return;
        }
        await _ctrl.answer(q.date, context);
        if (!mounted) return;
        await _ctrl.answer(q.placement, context);
        if (!mounted) return;
        if (_acceptsMachPoints(q.agilityClass, q.level, q.preferred)) {
          await _ctrl.answer(q.machPoints, context);
        }
      } else if (widget.preselectedDogId != null) {
        await _ctrl.answer(widget.preselectedDogId, context);
      }
    });
  }

  static bool _acceptsMachPoints(AgilityClass cls, AgilityLevel level, bool preferred) {
    if (level != AgilityLevel.master) return false;
    if (cls.isPremier) return false;
    return cls == AgilityClass.standard || cls == AgilityClass.jww;
  }

  static const _classChoices = <(String, _ClassDivision)>[
    ('Standard', (AgilityClass.standard, false)),
    ('Standard Preferred', (AgilityClass.standard, true)),
    ('JWW', (AgilityClass.jww, false)),
    ('JWW Preferred', (AgilityClass.jww, true)),
    ('FAST', (AgilityClass.fast, false)),
    ('FAST Preferred', (AgilityClass.fast, true)),
    ('T2B', (AgilityClass.t2b, false)),
    ('T2B Preferred', (AgilityClass.t2b, true)),
    ('Premier Standard', (AgilityClass.premierStandard, false)),
    ('Premier JWW', (AgilityClass.premierJww, false)),
  ];

  ConvoStep? _nextStep(Map<String, Object?> a) {
    if (!a.containsKey('dog')) {
      final dogs = widget.repo.dogs;
      final addDogAction = ChoiceAction(
        label: dogs.isEmpty ? 'Add a dog' : 'New dog',
        icon: Icons.add,
        run: (ctx, onAnswer) async {
          final result = await Navigator.of(ctx).push<({Dog dog, bool merged})>(
            MaterialPageRoute(builder: (_) => AddDogPage(repo: widget.repo)),
          );
          if (result != null) onAnswer(result.dog.id);
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
    if (!a.containsKey('classDivision')) {
      return ConvoStep(
        key: 'classDivision',
        prompt: 'Which class?',
        input: ChoiceInput<_ClassDivision>([
          for (final c in _classChoices) Choice(c.$1, c.$2),
        ]),
      );
    }
    final cd = a['classDivision'] as _ClassDivision;
    final cls = cd.$1;
    final preferred = cd.$2;
    if (!cls.isPremier && !a.containsKey('level')) {
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
    if (!a.containsKey('placement')) {
      return ConvoStep(
        key: 'placement',
        prompt: 'Did you place?',
        input: ChoiceInput<int?>([
          Choice('1st', 1),
          Choice('2nd', 2),
          Choice('3rd', 3),
          Choice('4th', 4),
          Choice('No placement', null),
        ]),
      );
    }
    final level = (cls.isPremier ? AgilityLevel.master : a['level']) as AgilityLevel;
    if (_acceptsMachPoints(cls, level, preferred) &&
        !a.containsKey('machPoints')) {
      final label = preferred ? 'PACH' : 'MACH';
      return ConvoStep(
        key: 'machPoints',
        prompt: '$label points earned? (optional)',
        input: NumberInputStep(hint: 'e.g. 24'),
      );
    }
    if (_isEditing) {
      if (!a.containsKey('saveEdit')) {
        return ConvoStep(
          key: 'saveEdit',
          prompt: 'Save changes?',
          input: ChoiceInput<String>([
            Choice('Save changes', 'save'),
            Choice('Discard', 'cancel'),
          ]),
        );
      }
      return null;
    }
    if (!a.containsKey('addAnother')) {
      final dog = widget.repo.dogById(a['dog'] as String);
      final name = dog?.callName ?? 'this dog';
      return ConvoStep(
        key: 'addAnother',
        prompt: _savedCount == 0
            ? 'Save this Q?'
            : 'Saved! Add another Q for $name?',
        input: ChoiceInput<bool>([
          Choice(_savedCount == 0 ? 'Save & log another' : 'Yes, another', true),
          Choice(_savedCount == 0 ? 'Save & done' : 'All done', false),
        ]),
      );
    }
    return null;
  }

  Future<void> _complete(BuildContext _, Map<String, Object?> a) async {
    final cd = a['classDivision'] as _ClassDivision;
    final cls = cd.$1;
    final preferred = cd.$2;
    final level = (cls.isPremier ? AgilityLevel.master : a['level']) as AgilityLevel;

    final placement = a['placement'] as int?;

    if (_isEditing) {
      if (a['saveEdit'] == 'cancel') {
        if (mounted) Navigator.of(context).pop(0);
        return;
      }
      final updated = widget.editing!.copyWith(
        date: a['date'] as DateTime,
        agilityClass: cls,
        level: level,
        preferred: preferred,
        placement: placement,
        clearPlacement: placement == null,
        machPoints: (a['machPoints'] as num?)?.toInt() ?? 0,
      );
      await widget.repo.updateQ(updated);
      if (mounted) Navigator.of(context).pop(1);
      return;
    }

    final q = Q.create(
      dogId: a['dog'] as String,
      date: a['date'] as DateTime,
      agilityClass: cls,
      level: level,
      preferred: preferred,
      placement: placement,
      machPoints: (a['machPoints'] as num?)?.toInt() ?? 0,
    );
    await widget.repo.addQ(q);
    _savedCount++;

    if (a['addAnother'] == true) {
      _ctrl.rewindToKey('classDivision');
    } else {
      if (mounted) Navigator.of(context).pop(_savedCount);
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
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Q' : 'Log a Q'),
      ),
      body: ConvoView(controller: _ctrl),
    );
  }
}
