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
            // The non-null assertion on q.agilityClass / q.level is
            // valid here: the constructor's invariant guarantees
            // these are non-null for AKC Agility Qs.
            await _ctrl.answer((q.agilityClass!, q.preferred), context);
            if (!mounted) return;
            if (!_isSingleLevel(q.agilityClass!)) {
              await _ctrl.answer(q.level, context);
              if (!mounted) return;
            }
            await _ctrl.answer(q.date, context);
            if (!mounted) return;
            await _ctrl.answer(q.placement, context);
            if (!mounted) return;
            await _ctrl.answer(q.timeSeconds, context);
            if (!mounted) return;
            if (_acceptsYards(q.agilityClass!)) {
              await _ctrl.answer(q.yards, context);
              if (!mounted) return;
              await _ctrl.answer(q.ypsOverride, context);
              if (!mounted) return;
            }
            if (_acceptsScore(q.agilityClass!)) {
              await _ctrl.answer(q.score?.toDouble(), context);
              if (!mounted) return;
            }
            if (_acceptsMachPoints(q.agilityClass!, q.level!, q.preferred)) {
              // Edit replays the SCT step so the user can correct or
              // fill it in. machPoints is recomputed from sct + time
              // on save.
              await _ctrl.answer(q.sct, context);
            }
            break;
          case Sport.fastCAT:
            await _ctrl.answer(q.date, context);
            if (!mounted) return;
            await _ctrl.answer(q.trial ?? '', context);
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

  /// Classes where the run is scored at a single level (Master) so the
  /// level question would be redundant. Thin wrapper over the enum
  /// extension so the convo code reads cleanly.
  static bool _isSingleLevel(AgilityClass cls) => cls.isSingleLevel;

  /// Courses where the judge measures yardage and reports YPS. Premier
  /// classes are not wheeled by the judge — yards and YPS aren't
  /// recorded on Premier ribbons, so we don't ask for them.
  static bool _acceptsYards(AgilityClass cls) =>
      cls == AgilityClass.standard || cls == AgilityClass.jww;

  /// FAST and T2B are both points-based — the judge awards points per
  /// run; no way to compute them from time alone.
  static bool _acceptsScore(AgilityClass cls) =>
      cls == AgilityClass.fast || cls == AgilityClass.t2b;

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
    ('Premier Standard Preferred', (AgilityClass.premierStandard, true)),
    ('Premier JWW', (AgilityClass.premierJww, false)),
    ('Premier JWW Preferred', (AgilityClass.premierJww, true)),
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
          initialValue: _ctrl.carryoverFor('dog') as String?,
        ),
      );
    }
    if (!a.containsKey('sport')) {
      return ConvoStep(
        key: 'sport',
        prompt: 'Which sport?',
        input: ChoiceInput<Sport>(
          [for (final s in Sport.values) Choice(s.short, s)],
          initialValue: _ctrl.carryoverFor('sport') as Sport?,
        ),
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
        input: ChoiceInput<_ClassDivision>(
          [for (final c in _classChoices) Choice(c.$1, c.$2)],
          initialValue: _ctrl.carryoverFor('classDivision') as _ClassDivision?,
        ),
      );
    }
    final cd = a['classDivision'] as _ClassDivision;
    final cls = cd.$1;
    final preferred = cd.$2;
    if (!_isSingleLevel(cls) && !a.containsKey('level')) {
      return ConvoStep(
        key: 'level',
        prompt: 'Which level?',
        input: ChoiceInput<AgilityLevel>(
          [for (final l in AgilityLevel.values) Choice(l.label, l)],
          initialValue: _ctrl.carryoverFor('level') as AgilityLevel?,
        ),
      );
    }
    if (!a.containsKey('date')) {
      return ConvoStep(
        key: 'date',
        prompt: 'When was the Q?',
        input: DateInputStep(
          initial: _ctrl.carryoverFor('date') as DateTime? ?? DateTime.now(),
        ),
      );
    }
    if (!a.containsKey('placement')) {
      return ConvoStep(
        key: 'placement',
        prompt: 'Did you place?',
        input: ChoiceInput<int?>(
          [
            Choice('1st', 1),
            Choice('2nd', 2),
            Choice('3rd', 3),
            Choice('4th', 4),
            Choice('No placement', null),
          ],
          initialValue: _ctrl.carryoverFor('placement') as int?,
        ),
      );
    }
    final level = _isSingleLevel(cls)
        ? AgilityLevel.master
        : a['level'] as AgilityLevel;
    if (!a.containsKey('timeSeconds')) {
      return ConvoStep(
        key: 'timeSeconds',
        prompt: 'Course time? (seconds, optional)',
        input: NumberInputStep(
          hint: 'e.g. 41.2',
          suffix: 's',
          initial: _ctrl.carryoverFor('timeSeconds') as num?,
        ),
      );
    }
    if (_acceptsYards(cls) && !a.containsKey('yards')) {
      return ConvoStep(
        key: 'yards',
        prompt: 'Course yardage? (optional)',
        input: NumberInputStep(
          hint: 'e.g. 170',
          suffix: ' yds',
          initial: _ctrl.carryoverFor('yards') as num?,
        ),
      );
    }
    if (_acceptsYards(cls) && !a.containsKey('yps')) {
      // Computed from yards/time when both are known; ask the user to
      // record what's printed on the ribbon so we don't have to trust
      // the math. The hint shows the live computed value when yards
      // and time are both available.
      final t = (a['timeSeconds'] as num?)?.toDouble();
      final y = (a['yards'] as num?)?.toDouble();
      final hint = (t != null && t > 0 && y != null)
          ? 'e.g. ${(y / t).toStringAsFixed(2)}'
          : 'e.g. 4.13';
      return ConvoStep(
        key: 'yps',
        prompt: 'YPS? (optional)',
        input: NumberInputStep(
          hint: hint,
          suffix: ' YPS',
          initial: _ctrl.carryoverFor('yps') as num?,
        ),
      );
    }
    if (_acceptsScore(cls) && !a.containsKey('score')) {
      // T2B points come from the judge — there's no way to compute
      // them from time or any other recorded field, so we ask for
      // them without an "(optional)" out.
      final t2b = cls == AgilityClass.t2b;
      return ConvoStep(
        key: 'score',
        prompt: t2b
            ? 'T2B points earned?'
            : 'FAST points scored? (optional)',
        input: NumberInputStep(
          hint: t2b ? 'e.g. 12' : 'e.g. 65',
          suffix: ' pts',
          allowSkip: !t2b,
          initial: _ctrl.carryoverFor('score') as num?,
        ),
      );
    }
    if (_acceptsMachPoints(cls, level, preferred) &&
        !a.containsKey('sct')) {
      final label = preferred ? 'PACH' : 'MACH';
      return ConvoStep(
        key: 'sct',
        prompt: 'Standard course time? (optional — we\'ll compute $label points)',
        input: NumberInputStep(
          hint: 'e.g. 58',
          suffix: 's',
          initial: _ctrl.carryoverFor('sct') as num?,
        ),
      );
    }
    return _finalStep(a);
  }

  ConvoStep? _fastCATStep(Map<String, Object?> a) {
    if (!a.containsKey('date')) {
      return ConvoStep(
        key: 'date',
        prompt: 'When was the run?',
        input: DateInputStep(
          initial: _ctrl.carryoverFor('date') as DateTime? ?? DateTime.now(),
        ),
      );
    }
    if (!a.containsKey('trial')) {
      return ConvoStep(
        key: 'trial',
        prompt: 'Which trial? (optional — e.g. Trial 1)',
        input: TextInputStep(
          hint: 'Trial 1',
          allowSkip: true,
          initial: _ctrl.carryoverFor('trial') as String?,
        ),
      );
    }
    if (!a.containsKey('score')) {
      return ConvoStep(
        key: 'score',
        prompt: 'FastCAT points earned?',
        input: NumberInputStep(
          hint: 'e.g. 17',
          suffix: ' pts',
          initial: _ctrl.carryoverFor('score') as num?,
        ),
      );
    }
    if (!a.containsKey('timeSeconds')) {
      return ConvoStep(
        key: 'timeSeconds',
        prompt: 'Time on the course? (seconds, optional)',
        input: NumberInputStep(
          hint: 'e.g. 8.4',
          suffix: 's',
          initial: _ctrl.carryoverFor('timeSeconds') as num?,
        ),
      );
    }
    return _finalStep(a);
  }

  ConvoStep? _scentworkStep(Map<String, Object?> a) {
    if (!a.containsKey('scentElement')) {
      return ConvoStep(
        key: 'scentElement',
        prompt: 'Which element?',
        input: ChoiceInput<ScentElement>(
          [for (final e in ScentElement.values) Choice(e.label, e)],
          initialValue: _ctrl.carryoverFor('scentElement') as ScentElement?,
        ),
      );
    }
    if (!a.containsKey('scentLevel')) {
      return ConvoStep(
        key: 'scentLevel',
        prompt: 'Which level?',
        input: ChoiceInput<ScentLevel>(
          [for (final l in ScentLevel.values) Choice(l.label, l)],
          initialValue: _ctrl.carryoverFor('scentLevel') as ScentLevel?,
        ),
      );
    }
    if (!a.containsKey('date')) {
      return ConvoStep(
        key: 'date',
        prompt: 'When was the Q?',
        input: DateInputStep(
          initial: _ctrl.carryoverFor('date') as DateTime? ?? DateTime.now(),
        ),
      );
    }
    if (!a.containsKey('placement')) {
      return ConvoStep(
        key: 'placement',
        prompt: 'Did you place?',
        input: ChoiceInput<int?>(
          [
            Choice('1st', 1),
            Choice('2nd', 2),
            Choice('3rd', 3),
            Choice('4th', 4),
            Choice('No placement', null),
          ],
          initialValue: _ctrl.carryoverFor('placement') as int?,
        ),
      );
    }
    if (!a.containsKey('timeSeconds')) {
      return ConvoStep(
        key: 'timeSeconds',
        prompt: 'Search time? (seconds, optional)',
        input: NumberInputStep(
          hint: 'e.g. 33.5',
          suffix: 's',
          initial: _ctrl.carryoverFor('timeSeconds') as num?,
        ),
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

    // Sport-specific bindings. agilityClass + level are only set on
    // AKC Agility Qs; FastCAT and Scentwork leave them null.
    AgilityClass? cls;
    AgilityLevel? level;
    bool preferred;
    double? yards;
    int machPoints;
    double? sct;
    double? ypsOverride;
    ScentElement? scentElement;
    ScentLevel? scentLevel;
    String? trial;

    switch (sport) {
      case Sport.akcAgility:
        final cd = a['classDivision'] as _ClassDivision;
        cls = cd.$1;
        preferred = cd.$2;
        level = _isSingleLevel(cls)
            ? AgilityLevel.master
            : a['level'] as AgilityLevel;
        yards = (a['yards'] as num?)?.toDouble();
        sct = (a['sct'] as num?)?.toDouble();
        ypsOverride = (a['yps'] as num?)?.toDouble();
        // Auto-compute MACH/PACH points from sct + time when eligible.
        machPoints = _acceptsMachPoints(cls, level, preferred)
            ? Q.computeMachPoints(sct: sct, timeSeconds: timeSeconds)
            : 0;
        scentElement = null;
        scentLevel = null;
        trial = null;
        break;
      case Sport.fastCAT:
        cls = null;
        level = null;
        preferred = false;
        yards = null;
        sct = null;
        ypsOverride = null;
        machPoints = 0;
        scentElement = null;
        scentLevel = null;
        final t = (a['trial'] as String?)?.trim();
        trial = (t == null || t.isEmpty) ? null : t;
        break;
      case Sport.scentwork:
        cls = null;
        level = null;
        preferred = false;
        yards = null;
        sct = null;
        ypsOverride = null;
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
        clearAgilityClass: cls == null,
        level: level,
        clearLevel: level == null,
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
        sct: sct,
        clearSct: sct == null,
        ypsOverride: ypsOverride,
        clearYpsOverride: ypsOverride == null,
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
      sct: sct,
      ypsOverride: ypsOverride,
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
