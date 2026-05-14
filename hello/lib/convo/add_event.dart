import 'package:flutter/material.dart';

import '../models/dog.dart';
import '../models/event.dart';
import '../repo/repo.dart';
import 'add_dog.dart';
import 'convo.dart';

/// Conversation that adds or edits an Event (NAC, Invitational, etc).
class AddEventPage extends StatefulWidget {
  const AddEventPage({
    super.key,
    required this.repo,
    this.preselectedDogId,
    this.editing,
  });
  final Repo repo;
  final String? preselectedDogId;
  final Event? editing;

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  late final ConvoController _ctrl;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _ctrl = ConvoController(next: _nextStep, onComplete: _complete);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ev = widget.editing;
      if (ev != null) {
        await _ctrl.answer(ev.dogId, context);
        if (!mounted) return;
        await _ctrl.answer(ev.type, context);
        if (!mounted) return;
        if (ev.type == EventType.other) {
          await _ctrl.answer(ev.customName ?? '', context);
          if (!mounted) return;
        }
        await _ctrl.answer(ev.date, context);
        if (!mounted) return;
        await _ctrl.answer(ev.result, context);
      } else if (widget.preselectedDogId != null) {
        await _ctrl.answer(widget.preselectedDogId, context);
      }
    });
  }

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
          input: ChoiceInput<String>(const [], extraActions: [addDogAction]),
        );
      }
      return ConvoStep(
        key: 'dog',
        prompt: dogs.length == 1
            ? "Logging an event for ${dogs.first.callName}?"
            : 'Which dog?',
        input: ChoiceInput<String>(
          [for (final d in dogs) Choice<String>(d.callName, d.id)],
          extraActions: [addDogAction],
        ),
      );
    }
    if (!a.containsKey('type')) {
      return ConvoStep(
        key: 'type',
        prompt: 'Which event?',
        input: ChoiceInput<EventType>([
          for (final t in EventType.values) Choice(t.short, t),
        ]),
      );
    }
    final type = a['type'] as EventType;
    if (type == EventType.other && !a.containsKey('customName')) {
      return ConvoStep(
        key: 'customName',
        prompt: 'What was the event called?',
        input: TextInputStep(hint: 'e.g. Regional Performance'),
      );
    }
    if (!a.containsKey('date')) {
      return ConvoStep(
        key: 'date',
        prompt: 'When was it?',
        input: DateInputStep(initial: DateTime.now()),
      );
    }
    if (!a.containsKey('result')) {
      return ConvoStep(
        key: 'result',
        prompt: 'How did it go?',
        input: ChoiceInput<EventResult?>([
          Choice('Champion 🏆', EventResult.champion),
          Choice('Reserve', EventResult.reservePlace),
          Choice('1st', EventResult.place1st),
          Choice('2nd', EventResult.place2nd),
          Choice('3rd', EventResult.place3rd),
          Choice('Top 3', EventResult.top3),
          Choice('Top 10', EventResult.top10),
          Choice('Finalist', EventResult.finalist),
          Choice('Semifinalist', EventResult.semifinalist),
          Choice('Made the cut', EventResult.madeCut),
          Choice('Participated', EventResult.participated),
          Choice('Skip', null),
        ]),
      );
    }
    if (!a.containsKey('save')) {
      return ConvoStep(
        key: 'save',
        prompt: _isEditing ? 'Save changes?' : 'Save event?',
        input: ChoiceInput<String>([
          Choice(_isEditing ? 'Save changes' : 'Save & done', 'save'),
          Choice('Discard', 'cancel'),
        ]),
      );
    }
    return null;
  }

  Future<void> _complete(BuildContext _, Map<String, Object?> a) async {
    if (a['save'] != 'save') {
      if (mounted) Navigator.of(context).pop(0);
      return;
    }
    final dogId = a['dog'] as String;
    final type = a['type'] as EventType;
    final date = a['date'] as DateTime;
    final customName = a['customName'] as String?;
    final result = a['result'] as EventResult?;

    if (_isEditing) {
      final updated = widget.editing!.copyWith(
        dogId: dogId,
        type: type,
        date: date,
        customName: customName?.isNotEmpty == true ? customName : null,
        clearCustomName: type != EventType.other,
        result: result,
        clearResult: result == null,
      );
      await widget.repo.updateEvent(updated);
      if (mounted) Navigator.of(context).pop(1);
      return;
    }

    final ev = Event.create(
      dogId: dogId,
      date: date,
      type: type,
      customName: customName?.isNotEmpty == true ? customName : null,
      result: result,
    );
    await widget.repo.addEvent(ev);
    if (mounted) Navigator.of(context).pop(1);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit event' : 'Log an event')),
      body: ConvoView(controller: _ctrl),
    );
  }
}
