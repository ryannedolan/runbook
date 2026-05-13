import 'package:flutter/material.dart';

import '../models/dog.dart';
import '../repo/repo.dart';
import 'convo.dart';

/// Conversation that adds a new dog. Pops the route with the new Dog when
/// finished.
class AddDogPage extends StatefulWidget {
  const AddDogPage({super.key, required this.repo});
  final Repo repo;

  @override
  State<AddDogPage> createState() => _AddDogPageState();
}

class _AddDogPageState extends State<AddDogPage> {
  late final ConvoController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = ConvoController(
      next: _nextStep,
      onComplete: _complete,
    );
  }

  ConvoStep? _nextStep(Map<String, Object?> a) {
    if (!a.containsKey('callName')) {
      return ConvoStep(
        key: 'callName',
        prompt: "Let's add a new dog. What's their call name?",
        input: TextInputStep(hint: 'e.g. Bandit'),
      );
    }
    if (!a.containsKey('breed')) {
      return ConvoStep(
        key: 'breed',
        prompt: "What breed is ${a['callName']}? (optional)",
        input: TextInputStep(hint: 'e.g. Border Collie', allowSkip: true),
      );
    }
    if (!a.containsKey('heightInches')) {
      return ConvoStep(
        key: 'heightInches',
        prompt: 'Height at the withers? (inches, optional)',
        input: NumberInputStep(hint: 'e.g. 21', suffix: ' in'),
      );
    }
    if (!a.containsKey('notes')) {
      return ConvoStep(
        key: 'notes',
        prompt: 'Anything else worth noting? (optional)',
        input: TextInputStep(hint: 'Anything', allowSkip: true),
      );
    }
    return null;
  }

  Future<void> _complete(BuildContext ctx, Map<String, Object?> answers) async {
    final dog = Dog.create(
      callName: answers['callName'] as String,
      breed: _nonEmpty(answers['breed'] as String?),
      heightInches: (answers['heightInches'] as num?)?.toDouble(),
      notes: _nonEmpty(answers['notes'] as String?),
    );
    await widget.repo.addDog(dog);
    if (ctx.mounted) Navigator.of(ctx).pop(dog);
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
      appBar: AppBar(title: const Text('New dog')),
      body: ConvoView(controller: _ctrl),
    );
  }
}
