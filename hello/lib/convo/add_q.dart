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
        await _ctrl.answer(q.sport, context);
        if (!mounted) return;
        switch (q.sport) {
          case Sport.akcAgility:
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
            await _ctrl.answer(q.timeSeconds, context);
            if (!mounted) return;
            if (_acceptsYards(q.agilityClass)) {
              await _ctrl.answer(q.yards, context);
              if (!mounted) return;
            }
            if (_acceptsScore(q.agilityClass)) {
              await _ctrl.answer(q.score?.toDouble(), context);
              if (!mounted) return;
            }
            if (_acceptsMachPoints(q.agilityClass, q.level, q.preferred)) {
              await _ctrl.answer(q.machPoints, context);
            }
            break;
          case Sport.fastCAT:
            await _ctrl.answer(q.date, context);
            if (!mounted) return;
            await _ctrl.answer(q.trial ?? '', context);
            if (!mounted) return;
            await _ctrl.answer(q.placement, context);
            if (!mounted) return;
            await _ctrl.answer(q.score?.toDouble(), context);
            if (!mounted) return;
            await _ctrl.answer(q.timeSeconds, context);
            break;
          case Sport.scentwork:
            await _ctrl.answer(q.scentElement, context);
            if (!mounted) return;
            await _ctrl.answer(q.scentLevel, context);
            if (!mounted) return;
            await _ctrl.answer(q.date, context);
            if (!mounted) return;
            await _ctrl.answer(q.placement, context);
            if (!mounted) return;
            await _ctrl.answer(q.timeSeconds, context);
            break;
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

  /// Courses where yardage is meaningful (used for YPS).
  static bool _acceptsYards(AgilityClass cls) =>
      cls == AgilityClass.standard ||
      cls == AgilityClass.jww ||
      cls == AgilityClass.premierStandard ||
      cls == AgilityClass.premierJww;

  /// FAST is scored on point accumulation.
  static bool _acceptsScore(AgilityClass cls) => cls == AgilityClass.fast;

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
    if (!a.containsKey('sport')) {
      return ConvoStep(
        key: 'sport',
        prompt: 'Which sport?',
        input: ChoiceInput<Sport>([
          for (final s in Sport.values) Choice(s.short, s),
        ]),
      );
    }
    final sport = a['sport'] as Sport;
    return switch (sport) {
      Sport.akcAgility => _agilityStep(a),
      Sport.fastCAT => _fastCATStep(a),
      Sport.scentwork => _scentworkStep(a),
    };
  }

  ConvoStep? _agilityStep(Map<String, Object?> a) {
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
    if (!a.containsKey('timeSeconds')) {
      return ConvoStep(
        key: 'timeSeconds',
        prompt: 'Course time? (seconds, optional)',
        input: NumberInputStep(hint: 'e.g. 41.2', suffix: 's'),
      );
    }
    if (_acceptsYards(cls) && !a.containsKey('yards')) {
      return ConvoStep(
        key: 'yards',
        prompt: 'Course yardage? (optional)',
        input: NumberInputStep(hint: 'e.g. 170', suffix: ' yds'),
      );
    }
    if (_acceptsScore(cls) && !a.containsKey('score')) {
      return ConvoStep(
        key: 'score',
        prompt: 'FAST points scored? (optional)',
        input: NumberInputStep(hint: 'e.g. 65', suffix: ' pts'),
      );
    }
    if (_acceptsMachPoints(cls, level, preferred) &&
        !a.containsKey('machPoints')) {
      final label = preferred ? 'PACH' : 'MACH';
      return ConvoStep(
        key: 'machPoints',
        prompt: '$label points earned? (optional)',
        input: NumberInputStep(hint: 'e.g. 24'),
      );
    }
    return _finalStep(a);
  }

  ConvoStep? _fastCATStep(Map<String, Object?> a) {
    if (!a.containsKey('date')) {
      return ConvoStep(
        key: 'date',
        prompt: 'When was the run?',
        input: DateInputStep(initial: DateTime.now()),
      );
    }
    if (!a.containsKey('trial')) {
      return ConvoStep(
        key: 'trial',
        prompt: 'Which trial? (optional — e.g. Trial 1)',
        input: TextInputStep(hint: 'Trial 1', allowSkip: true),
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
    if (!a.containsKey('score')) {
      return ConvoStep(
        key: 'score',
        prompt: 'FastCAT points earned?',
        input: NumberInputStep(hint: 'e.g. 17', suffix: ' pts'),
      );
    }
    if (!a.containsKey('timeSeconds')) {
      return ConvoStep(
        key: 'timeSeconds',
        prompt: 'Time on the course? (seconds, optional)',
        input: NumberInputStep(hint: 'e.g. 8.4', suffix: 's'),
      );
    }
    return _finalStep(a);
  }

  ConvoStep? _scentworkStep(Map<String, Object?> a) {
    if (!a.containsKey('scentElement')) {
      return ConvoStep(
        key: 'scentElement',
        prompt: 'Which element?',
        input: ChoiceInput<ScentElement>([
          for (final e in ScentElement.values) Choice(e.label, e),
        ]),
      );
    }
    if (!a.containsKey('scentLevel')) {
      return ConvoStep(
        key: 'scentLevel',
        prompt: 'Which level?',
        input: ChoiceInput<ScentLevel>([
          for (final l in ScentLevel.values) Choice(l.label, l),
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
    if (!a.containsKey('timeSeconds')) {
      return ConvoStep(
        key: 'timeSeconds',
        prompt: 'Search time? (seconds, optional)',
        input: NumberInputStep(hint: 'e.g. 33.5', suffix: 's'),
      );
    }
    return _finalStep(a);
  }

  ConvoStep? _finalStep(Map<String, Object?> a) {
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
    final sport = a['sport'] as Sport;
    final date = a['date'] as DateTime;
    final placement = a['placement'] as int?;
    final timeSeconds = (a['timeSeconds'] as num?)?.toDouble();
    final score = (a['score'] as num?)?.toInt();

    // Sport-specific bindings. For non-agility Qs we set placeholder
    // agilityClass/level since they're required but ignored.
    AgilityClass cls;
    AgilityLevel level;
    bool preferred;
    double? yards;
    int machPoints;
    ScentElement? scentElement;
    ScentLevel? scentLevel;
    String? trial;

    switch (sport) {
      case Sport.akcAgility:
        final cd = a['classDivision'] as _ClassDivision;
        cls = cd.$1;
        preferred = cd.$2;
        level = cls.isPremier
            ? AgilityLevel.master
            : a['level'] as AgilityLevel;
        yards = (a['yards'] as num?)?.toDouble();
        machPoints = (a['machPoints'] as num?)?.toInt() ?? 0;
        scentElement = null;
        scentLevel = null;
        trial = null;
        break;
      case Sport.fastCAT:
        cls = AgilityClass.fast; // placeholder
        level = AgilityLevel.novice;
        preferred = false;
        yards = null;
        machPoints = 0;
        scentElement = null;
        scentLevel = null;
        final t = (a['trial'] as String?)?.trim();
        trial = (t == null || t.isEmpty) ? null : t;
        break;
      case Sport.scentwork:
        cls = AgilityClass.fast; // placeholder
        level = AgilityLevel.novice;
        preferred = false;
        yards = null;
        machPoints = 0;
        scentElement = a['scentElement'] as ScentElement?;
        scentLevel = a['scentLevel'] as ScentLevel?;
        trial = null;
        break;
    }

    if (_isEditing) {
      if (a['saveEdit'] == 'cancel') {
        if (mounted) Navigator.of(context).pop(0);
        return;
      }
      final updated = widget.editing!.copyWith(
        date: date,
        sport: sport,
        agilityClass: cls,
        level: level,
        preferred: preferred,
        placement: placement,
        clearPlacement: placement == null,
        timeSeconds: timeSeconds,
        clearTimeSeconds: timeSeconds == null,
        yards: yards,
        clearYards: yards == null,
        score: score,
        clearScore: score == null,
        machPoints: machPoints,
        scentElement: scentElement,
        clearScentElement: scentElement == null,
        scentLevel: scentLevel,
        clearScentLevel: scentLevel == null,
        trial: trial,
        clearTrial: trial == null,
      );
      await widget.repo.updateQ(updated);
      if (mounted) Navigator.of(context).pop(1);
      return;
    }

    final q = Q.create(
      dogId: a['dog'] as String,
      date: date,
      sport: sport,
      agilityClass: cls,
      level: level,
      preferred: preferred,
      placement: placement,
      timeSeconds: timeSeconds,
      yards: yards,
      score: score,
      machPoints: machPoints,
      scentElement: scentElement,
      scentLevel: scentLevel,
      trial: trial,
    );
    await widget.repo.addQ(q);
    _savedCount++;

    if (a['addAnother'] == true) {
      _ctrl.rewindToKey('sport');
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
