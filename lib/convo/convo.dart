import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A single step in a conversation. Has a stable [key] used to identify
/// it in the history, a [prompt] message from the bot, and an [input]
/// that captures the user's response.
class ConvoStep {
  ConvoStep({required this.key, required this.prompt, required this.input});
  final String key;
  final String prompt;
  final ConvoInput input;
}

/// Strategy for capturing input on a single conversation step.
abstract class ConvoInput {
  Widget build(BuildContext context, ValueChanged<Object?> onAnswer);
  Widget renderAnswer(BuildContext context, Object? value);
}

class Choice<T> {
  Choice(this.label, this.value);
  final String label;
  final T value;
}

class ChoiceInput<T> extends ConvoInput {
  ChoiceInput(this.choices, {this.extraActions = const [], this.initialValue});
  final List<Choice<T>> choices;

  /// Extra actions rendered alongside the regular choices. Tapping one
  /// runs the action; the action decides whether to call onAnswer.
  final List<ChoiceAction> extraActions;

  /// Optional carry-over from a prior answer to the same step. The
  /// matching choice (by value) is rendered with primary tint so the
  /// user sees what they had selected last time, even though they
  /// still have to tap to confirm.
  final T? initialValue;

  @override
  Widget build(BuildContext context, ValueChanged<Object?> onAnswer) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        for (final c in choices)
          ActionChip(
            label: Text(c.label),
            onPressed: () => onAnswer(c.value),
            backgroundColor:
                initialValue != null && c.value == initialValue
                    ? cs.primaryContainer
                    : null,
            side: initialValue != null && c.value == initialValue
                ? BorderSide(color: cs.primary, width: 1.5)
                : null,
          ),
        for (final a in extraActions)
          ActionChip(
            label: Text(a.label),
            avatar: a.icon != null ? Icon(a.icon, size: 16) : null,
            onPressed: () => a.run(context, onAnswer),
          ),
      ],
    );
  }

  @override
  Widget renderAnswer(BuildContext context, Object? value) {
    final c = choices.firstWhere(
      (c) => c.value == value,
      orElse: () => Choice('${value ?? '?'}', value as T),
    );
    return _AnswerPill(text: c.label);
  }
}

class ChoiceAction {
  ChoiceAction({required this.label, this.icon, required this.run});
  final String label;
  final IconData? icon;
  final Future<void> Function(
    BuildContext context,
    ValueChanged<Object?> onAnswer,
  ) run;
}

class TextInputStep extends ConvoInput {
  TextInputStep({
    this.hint,
    this.allowSkip = false,
    this.skipLabel = 'Skip',
    this.initial,
  });
  final String? hint;
  final bool allowSkip;
  final String skipLabel;

  /// Pre-fills the text field. Used during edit flows so the previously
  /// recorded value is already there when the user reaches the step.
  final String? initial;

  @override
  Widget build(BuildContext context, ValueChanged<Object?> onAnswer) {
    return _TextField(
      hint: hint,
      allowSkip: allowSkip,
      skipLabel: skipLabel,
      initial: initial,
      onAnswer: onAnswer,
    );
  }

  @override
  Widget renderAnswer(BuildContext context, Object? value) {
    final s = value as String?;
    return _AnswerPill(text: (s == null || s.isEmpty) ? '(skipped)' : s);
  }
}

class NumberInputStep extends ConvoInput {
  NumberInputStep({
    this.hint,
    this.allowSkip = true,
    this.suffix,
    this.initial,
  });
  final String? hint;
  final bool allowSkip;
  final String? suffix;

  /// Pre-fills the field with this number's string form.
  final num? initial;

  @override
  Widget build(BuildContext context, ValueChanged<Object?> onAnswer) {
    return _TextField(
      hint: hint,
      allowSkip: allowSkip,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      initial: initial == null ? null : _fmtNum(initial!),
      onAnswer: (raw) {
        if (raw == null || (raw as String).isEmpty) {
          onAnswer(null);
          return;
        }
        final n = double.tryParse(raw);
        onAnswer(n);
      },
    );
  }

  @override
  Widget renderAnswer(BuildContext context, Object? value) {
    if (value == null) return const _AnswerPill(text: '(skipped)');
    final n = value as num;
    return _AnswerPill(text: '${_fmtNum(n)}${suffix ?? ''}');
  }

  String _fmtNum(num n) {
    if (n == n.toInt()) return n.toInt().toString();
    // Up to 2 decimal places — agility times are commonly recorded to
    // hundredths (e.g. 41.23s). Trim trailing zeros so 41.20 → "41.2".
    var s = n.toStringAsFixed(2);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }
}

class DateInputStep extends ConvoInput {
  DateInputStep({this.initial});
  final DateTime? initial;

  @override
  Widget build(BuildContext context, ValueChanged<Object?> onAnswer) {
    return _DateField(initial: initial, onAnswer: onAnswer);
  }

  @override
  Widget renderAnswer(BuildContext context, Object? value) {
    final d = value as DateTime;
    return _AnswerPill(text: DateFormat.yMMMd().format(d));
  }
}

class _AnswerPill extends StatelessWidget {
  const _AnswerPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _TextField extends StatefulWidget {
  const _TextField({
    this.hint,
    this.allowSkip = false,
    this.skipLabel = 'Skip',
    this.keyboardType,
    this.initial,
    required this.onAnswer,
  });
  final String? hint;
  final bool allowSkip;
  final String skipLabel;
  final TextInputType? keyboardType;
  final String? initial;
  final ValueChanged<Object?> onAnswer;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final TextEditingController _ctrl;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      // Select the prefilled text so the user can either tap to keep
      // it or just start typing to replace it — matches typical edit
      // affordances.
      if (_ctrl.text.isNotEmpty) {
        _ctrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _ctrl.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() => widget.onAnswer(_ctrl.text.trim());

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            keyboardType: widget.keyboardType,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: widget.hint,
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: _submit, child: const Text('OK')),
        if (widget.allowSkip) ...[
          const SizedBox(width: 4),
          TextButton(
            onPressed: () => widget.onAnswer(null),
            child: Text(widget.skipLabel),
          ),
        ],
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.initial, required this.onAnswer});
  final DateTime? initial;
  final ValueChanged<Object?> onAnswer;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final init = initial ?? today;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        ActionChip(
          label: const Text('Today'),
          onPressed: () => onAnswer(DateTime(today.year, today.month, today.day)),
        ),
        ActionChip(
          label: const Text('Yesterday'),
          onPressed: () {
            final d = today.subtract(const Duration(days: 1));
            onAnswer(DateTime(d.year, d.month, d.day));
          },
        ),
        ActionChip(
          label: const Text('Pick date…'),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(today.year - 10),
              lastDate: DateTime(today.year + 1),
              initialDate: init,
            );
            if (picked != null) {
              onAnswer(DateTime(picked.year, picked.month, picked.day));
            }
          },
        ),
      ],
    );
  }
}

/// A turn record — a step the user has answered.
class ConvoTurn {
  ConvoTurn(this.step, this.value);
  final ConvoStep step;
  Object? value;
}

/// Conversation controller. The [next] callback computes the next step
/// based on the accumulated answers; return null when the convo is done,
/// and the controller calls [onComplete].
class ConvoController extends ChangeNotifier {
  ConvoController({
    required this.next,
    required this.onComplete,
  });

  final ConvoStep? Function(Map<String, Object?> answers) next;
  final Future<void> Function(
    BuildContext context,
    Map<String, Object?> answers,
  ) onComplete;

  final List<ConvoTurn> _turns = [];

  /// Sticky memory of every answer the user has produced for a given
  /// step key, surviving rewinds. The `next(answers)` callback can
  /// consult this via [carryoverFor] to pre-fill the input when the
  /// user re-enters a previously-answered step (or when a branch
  /// change re-asks for a value the original record had set, e.g.
  /// date carries from the agility branch into the scentwork branch).
  final Map<String, Object?> _carryover = {};

  Map<String, Object?> get _answers =>
      {for (final t in _turns) t.step.key: t.value};

  /// Step currently waiting on user input (or null if done).
  ConvoStep? pendingStep() => next(_answers);

  /// Returns the answered turns plus the pending step (if any).
  List<ConvoTurn> get turns => List.unmodifiable(_turns);

  /// Previously-answered value for a step key, if the user has touched
  /// that step earlier in this convo (and not since cleared via [reset]).
  Object? carryoverFor(String key) => _carryover[key];

  Future<void> answer(Object? value, BuildContext context) async {
    final pending = pendingStep();
    if (pending == null) return;
    _turns.add(ConvoTurn(pending, value));
    _carryover[pending.key] = value;
    notifyListeners();
    final more = pendingStep();
    if (more == null) {
      await onComplete(context, _answers);
    }
  }

  /// Drop everything from the indexed turn onward — the user wants to
  /// revise. The dropped values stay in [_carryover] so the user can
  /// see their prior choices when they re-encounter a step.
  void rewindTo(int turnIndex) {
    if (turnIndex < 0 || turnIndex >= _turns.length) return;
    _turns.removeRange(turnIndex, _turns.length);
    notifyListeners();
  }

  /// Drop the turn with the given step key (and everything after).
  void rewindToKey(String stepKey) {
    final i = _turns.indexWhere((t) => t.step.key == stepKey);
    if (i < 0) return;
    rewindTo(i);
  }

  /// Resets the conversation.
  void reset() {
    _turns.clear();
    _carryover.clear();
    notifyListeners();
  }
}

/// The conversation widget — a vertical thread of bot prompts and user
/// answers, plus the currently-pending input at the bottom.
class ConvoView extends StatefulWidget {
  const ConvoView({super.key, required this.controller});
  final ConvoController controller;

  @override
  State<ConvoView> createState() => _ConvoViewState();
}

class _ConvoViewState extends State<ConvoView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final turns = widget.controller.turns;
        final pending = widget.controller.pendingStep();
        final items = <Widget>[];
        for (var i = 0; i < turns.length; i++) {
          items.add(_TurnBubble(
            turn: turns[i],
            onEdit: () => widget.controller.rewindTo(i),
          ));
        }
        if (pending != null) {
          items.add(_PendingBubble(
            step: pending,
            controller: widget.controller,
          ));
        }
        return ListView(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: items,
        );
      },
    );
  }
}

class _TurnBubble extends StatelessWidget {
  const _TurnBubble({required this.turn, required this.onEdit});
  final ConvoTurn turn;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BotPrompt(text: turn.step.prompt),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(18),
              child: turn.step.input.renderAnswer(context, turn.value),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingBubble extends StatelessWidget {
  const _PendingBubble({required this.step, required this.controller});
  final ConvoStep step;
  final ConvoController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BotPrompt(text: step.prompt),
          const SizedBox(height: 10),
          step.input
              .build(context, (v) => controller.answer(v, context)),
        ],
      ),
    );
  }
}

class _BotPrompt extends StatelessWidget {
  const _BotPrompt({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Text(text, style: TextStyle(color: cs.onSurface)),
      ),
    );
  }
}
