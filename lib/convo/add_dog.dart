import 'dart:async';

import 'package:flutter/material.dart';

import '../models/dog.dart';
import '../repo/repo.dart';
import 'convo.dart';

/// Conversation that adds (or edits) a dog. Pops with the saved Dog.
class AddDogPage extends StatefulWidget {
  const AddDogPage({super.key, required this.repo, this.editing});
  final Repo repo;

  /// If non-null, this convo is editing an existing dog. Their current
  /// info is shown as defaults; the user can change anything.
  final Dog? editing;

  @override
  State<AddDogPage> createState() => _AddDogPageState();
}

class _AddDogPageState extends State<AddDogPage> {
  late final ConvoController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = ConvoController(next: _nextStep, onComplete: _complete);
    final d = widget.editing;
    if (d != null) {
      // Pre-fill answers so the user can review before changing.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _ctrl.answer(d.callName, context);
        if (!mounted) return;
        await _ctrl.answer(d.breed ?? '', context);
        if (!mounted) return;
        await _ctrl.answer(d.heightInches, context);
        if (!mounted) return;
        await _ctrl.answer(d.akcId ?? '', context);
        if (!mounted) return;
        await _ctrl.answer(d.notes ?? '', context);
      });
    }
  }

  ConvoStep? _nextStep(Map<String, Object?> a) {
    if (!a.containsKey('callName')) {
      return ConvoStep(
        key: 'callName',
        prompt: widget.editing != null
            ? "What's their call name?"
            : "Let's add a new dog. What's their call name?",
        input: TextInputStep(
          hint: 'e.g. Bandit',
          initial: _ctrl.carryoverFor('callName') as String?,
        ),
      );
    }
    if (!a.containsKey('breed')) {
      return ConvoStep(
        key: 'breed',
        prompt: "What breed is ${a['callName']}? (optional)",
        input: TextInputStep(
          hint: 'e.g. Border Collie',
          allowSkip: true,
          initial: _ctrl.carryoverFor('breed') as String?,
        ),
      );
    }
    if (!a.containsKey('heightInches')) {
      return ConvoStep(
        key: 'heightInches',
        prompt: 'Height at the withers? (inches, optional)',
        input: NumberInputStep(
          hint: 'e.g. 21',
          suffix: ' in',
          initial: _ctrl.carryoverFor('heightInches') as num?,
        ),
      );
    }
    if (!a.containsKey('akcId')) {
      return ConvoStep(
        key: 'akcId',
        prompt: "AKC registration #? (optional — lets the app backfill "
            "Qs for you)",
        input: TextInputStep(
          hint: 'e.g. PAL285213',
          allowSkip: true,
          initial: _ctrl.carryoverFor('akcId') as String?,
        ),
      );
    }
    if (!a.containsKey('notes')) {
      return ConvoStep(
        key: 'notes',
        prompt: 'Anything else worth noting? (optional)',
        input: TextInputStep(
          hint: 'Anything',
          allowSkip: true,
          initial: _ctrl.carryoverFor('notes') as String?,
        ),
      );
    }
    if (!a.containsKey('save')) {
      final name = a['callName'] as String;
      final breed = _nonEmpty(a['breed'] as String?);
      final height = (a['heightInches'] as num?)?.toDouble();
      final akcId = _nonEmpty(a['akcId'] as String?);
      final dup = widget.repo.dogByName(name);
      final replacingExisting =
          dup != null && (widget.editing == null || dup.id != widget.editing!.id);
      final summary = [
        name,
        ?breed,
        if (height != null) '${height.toStringAsFixed(height == height.toInt() ? 0 : 1)} in',
        if (akcId != null) 'AKC $akcId',
      ].join(' • ');
      final prompt = replacingExisting
          ? "I'll update the existing $name with these details:\n$summary"
          : (widget.editing != null
              ? "Save these changes?\n$summary"
              : "Ready to save?\n$summary");
      return ConvoStep(
        key: 'save',
        prompt: prompt,
        input: ChoiceInput<String>([
          Choice(
              replacingExisting
                  ? 'Update $name'
                  : (widget.editing != null ? 'Save changes' : 'Save'),
              'save'),
          Choice('Start over', 'restart'),
        ]),
      );
    }
    return null;
  }

  Future<void> _complete(BuildContext _, Map<String, Object?> a) async {
    if (a['save'] == 'restart') {
      _ctrl.rewindTo(0);
      return;
    }
    final base = widget.editing;
    final newAkcId = _nonEmpty(a['akcId'] as String?);
    final dog = (base ?? Dog.create(callName: a['callName'] as String)).copyWith(
      callName: a['callName'] as String,
      breed: _nonEmpty(a['breed'] as String?),
      heightInches: (a['heightInches'] as num?)?.toDouble(),
      notes: _nonEmpty(a['notes'] as String?),
      akcId: newAkcId,
      clearAkcId: newAkcId == null,
    );
    final result = await widget.repo.upsertDog(dog);
    // Backfill for this dog whenever it's saved with an AKC ID, even
    // on no-op edits — re-saving is the user-visible way to pull
    // fresh Qs from the deployed dataset. The fetch is async and
    // best-effort; the repo notifies listeners when new Qs land.
    if (newAkcId != null) {
      unawaited(widget.repo.backfillForDog(result.dog));
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  static String? _nonEmpty(String? s) =>
      (s == null || s.isEmpty) ? null : s;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing != null ? 'Edit dog' : 'New dog'),
      ),
      body: ConvoView(controller: _ctrl),
    );
  }
}
