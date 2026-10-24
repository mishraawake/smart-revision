import 'dart:async';

import 'package:flutter/material.dart';

import '../../logic/levels.dart';
import '../../logic/quiz.dart';
import '../../models/deck.dart';
import '../../state/account_state.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import 'quiz_intro_screen.dart';
import 'quiz_results_screen.dart';

const _lilac = Color(0xFFEDE9FE);
const _lilacBorder = Color(0xFFD6CCF3);
const _lilacTrack = Color(0xFFCFC6EE);
const _deepPurple = Color(0xFF3B1D8F);
const _knewBg = Color(0xFFDCFCE7);

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.questions,
    this.chapter,
    this.timed = false,
  });

  final List<QuizQuestion> questions;

  /// Null for a mixed quiz.
  final Chapter? chapter;

  /// Senior timed mode: 60 seconds per question.
  final bool timed;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const _secondsPerQuestion = 60;

  late final _session = QuizSession(widget.questions);
  final _started = DateTime.now();

  /// The answer just given; while set, the feedback panel shows.
  QuizAnswer? _feedback;

  // Per-question input.
  int? _choice;
  String? _tile;
  final _typed = TextEditingController();
  var _hint = false;
  int? _matchLeft;
  final _matched = <int>{};
  var _slips = 0;
  int? _shake;

  Timer? _timer;
  var _secondsLeft = _secondsPerQuestion;
  var _finishing = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _typed.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (!widget.timed) return;
    _secondsLeft = _secondsPerQuestion;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _feedback != null) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _submit(QuizAnswer(_session.current, correct: false, timedOut: true));
      }
    });
  }

  /// The question on screen: the one just answered while its feedback
  /// shows, otherwise the next one.
  QuizQuestion get _q => _feedback?.question ?? _session.current;

  void _submit(QuizAnswer a) {
    _timer?.cancel();
    SpeakerScope.of(context).stop();
    _session.record(a);
    setState(() => _feedback = a);
  }

  void _check() {
    switch (_q) {
      case McqQuestion(:final options, :final correctIndex):
        if (_choice == null) return;
        _submit(
          QuizAnswer(
            _q,
            correct: _choice == correctIndex,
            given: options[_choice!],
          ),
        );
      case final FillBlankQuestion q when !q.typed:
        if (_tile == null) return;
        _submit(QuizAnswer(q, correct: _tile == q.answer, given: _tile));
      case final FillBlankQuestion q:
        final given = _typed.text.trim();
        if (given.isEmpty) return;
        final r = q.check(given);
        _submit(
          QuizAnswer(
            q,
            correct: r != TypedResult.wrong,
            close: r == TypedResult.close,
            hintUsed: _hint,
            given: given,
          ),
        );
      default:
        break;
    }
  }

  void _trueFalse(bool value) {
    final q = _q as TrueFalseQuestion;
    _submit(
      QuizAnswer(
        q,
        correct: value == q.isTrue,
        given: value ? 'True' : 'False',
      ),
    );
  }

  void _tapMatch({int? left, int? right}) {
    final q = _q as MatchQuestion;
    if (left != null) {
      if (_matched.contains(left)) return;
      setState(() => _matchLeft = left);
      return;
    }
    final pairIndex = q.rightOrder[right!];
    if (_matchLeft == null || _matched.contains(pairIndex)) return;
    if (_matchLeft == pairIndex) {
      setState(() {
        _matched.add(pairIndex);
        _matchLeft = null;
      });
      if (_matched.length == q.pairs.length) {
        _submit(
          QuizAnswer(
            q,
            correct: _slips <= MatchQuestion.allowedSlips,
            slips: _slips,
            given: _slips == 0
                ? 'All pairs'
                : '$_slips slip${_slips == 1 ? '' : 's'}',
          ),
        );
      }
    } else {
      setState(() {
        _slips++;
        _shake = right;
      });
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _shake = null);
      });
    }
  }

  Future<void> _next() async {
    if (_session.finished) {
      if (_finishing) return;
      _finishing = true;
      final summary = await AppScope.read(context).finishQuiz(
        _session,
        duration: DateTime.now().difference(_started),
        chapter: widget.chapter,
      );
      if (!mounted) return;
      // Hands it in if a teacher set a quiz on this chapter.
      if (widget.chapter case final ch?) {
        AccountScope.maybeOf(context)?.submitQuiz(
          AppScope.read(context).current!.id,
          ch.id,
          score: _session.score,
          total: _session.total,
          answers: [
            for (final a in _session.answers)
              {
                'cardId': a.question.card?.id,
                'right': a.correct,
                'given': a.given,
              },
          ],
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              QuizResultsScreen(summary: summary, chapter: widget.chapter),
        ),
      );
      return;
    }
    setState(() {
      _feedback = null;
      _choice = null;
      _tile = null;
      _typed.clear();
      _hint = false;
      _matchLeft = null;
      _matched.clear();
      _slips = 0;
    });
    _startTimer();
  }

  Future<void> _confirmQuit() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop the quiz?'),
        content: const Text("Answers so far won't be saved."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if ((quit ?? false) && mounted) Navigator.of(context).pop();
  }

  bool get _canCheck => switch (_q) {
    McqQuestion() => _choice != null,
    FillBlankQuestion(:final typed) =>
      typed ? _typed.text.trim().isNotEmpty : _tile != null,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final junior = Tier.of(context).isJunior;
    final q = _q;
    final showsCheck = q is McqQuestion || q is FillBlankQuestion;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit();
      },
      child: Scaffold(
        backgroundColor: junior ? _lilac : AppColors.ground,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, junior ? 20 : 12, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      junior: junior,
                      index: _session.index - (_feedback != null ? 1 : 0),
                      total: _session.total,
                      label: _typeLabel(q),
                      secondsLeft: widget.timed ? _secondsLeft : null,
                      onClose: _confirmQuit,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: switch (q) {
                          final McqQuestion q => _Mcq(
                            q: q,
                            junior: junior,
                            choice: _choice,
                            onChoose: _feedback != null
                                ? null
                                : (i) => setState(() => _choice = i),
                          ),
                          final TrueFalseQuestion q => _TrueFalse(
                            q: q,
                            junior: junior,
                            onAnswer: _feedback != null ? null : _trueFalse,
                          ),
                          final FillBlankQuestion q => _FillBlank(
                            q: q,
                            junior: junior,
                            tile: _tile,
                            onTile: (t) => setState(() => _tile = t),
                            typed: _typed,
                            onTyped: () => setState(() {}),
                            hint: _hint,
                            onHint: () => setState(() => _hint = true),
                          ),
                          final MatchQuestion q => _Match(
                            q: q,
                            junior: junior,
                            selectedLeft: _matchLeft,
                            matched: _matched,
                            slips: _slips,
                            shaking: _shake,
                            onLeft: (i) => _tapMatch(left: i),
                            onRight: (i) => _tapMatch(right: i),
                          ),
                        },
                      ),
                    ),
                    if (showsCheck && _feedback == null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (!junior) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _submit(QuizAnswer(q, correct: false)),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Skip',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            flex: 2,
                            child: PrimaryButton(
                              label: 'Check',
                              onPressed: _canCheck ? _check : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (_feedback != null) ...[
                const Positioned.fill(
                  child: ColoredBox(color: Color(0x6B1F1A33)),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _Feedback(
                    answer: _feedback!,
                    junior: junior,
                    last: _session.finished,
                    onNext: _next,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _typeLabel(QuizQuestion q) => switch (q) {
    McqQuestion() => 'Multiple choice',
    TrueFalseQuestion() => 'True or false',
    FillBlankQuestion() => 'Fill the blank',
    MatchQuestion() => 'Match the pairs',
  };
}

class _Header extends StatelessWidget {
  const _Header({
    required this.junior,
    required this.index,
    required this.total,
    required this.label,
    required this.secondsLeft,
    required this.onClose,
  });

  final bool junior;
  final int index;
  final int total;
  final String label;
  final int? secondsLeft;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final close = Semantics(
      button: true,
      label: 'Stop quiz',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onClose,
          child: SizedBox.square(
            dimension: junior ? 56 : 44,
            child: const Icon(Icons.close_rounded, color: AppColors.inkMuted),
          ),
        ),
      ),
    );
    if (junior) {
      return Row(
        children: [
          close,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: 'Question ${index + 1} of $total',
                  child: Row(
                    children: [
                      for (var i = 0; i < total; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 16,
                            decoration: BoxDecoration(
                              color: i <= index
                                  ? AppColors.primary
                                  : _lilacTrack,
                              borderRadius: BorderRadius.circular(99),
                              border: i == index
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Question ${index + 1} of $total',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _deepPurple,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            close,
            const SizedBox(width: 12),
            Text(
              '${index + 1}/$total',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 10),
            Expanded(child: ProgressBar((index + 1) / total, height: 6)),
            if (secondsLeft != null) ...[
              const SizedBox(width: 10),
              Icon(
                Icons.timer_outlined,
                size: 18,
                color: secondsLeft! <= 10
                    ? AppColors.againBorder
                    : AppColors.inkMuted,
              ),
              Text(
                ' ${secondsLeft}s',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: secondsLeft! <= 10
                      ? AppColors.againInk
                      : AppColors.inkMuted,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 1,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

BoxDecoration _juniorCard() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(32),
  boxShadow: const [BoxShadow(color: _lilacBorder, offset: Offset(0, 8))],
);

/// Question text with a read-aloud button (Junior) or plain (Senior).
class _Prompt extends StatelessWidget {
  const _Prompt(this.text, {required this.junior, this.spoken});

  final String text;
  final bool junior;
  final String? spoken;

  @override
  Widget build(BuildContext context) => junior
      ? Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ReadAloudButton(spoken ?? text, size: 64, filled: true),
          ],
        )
      : Text(
          text,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        );
}

class _Mcq extends StatelessWidget {
  const _Mcq({
    required this.q,
    required this.junior,
    required this.choice,
    required this.onChoose,
  });

  final McqQuestion q;
  final bool junior;
  final int? choice;
  final ValueChanged<int>? onChoose;

  @override
  Widget build(BuildContext context) {
    if (junior) {
      final big = q.options.every((o) => o.length <= 4);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _juniorCard(),
            child: _Prompt(q.card.front, junior: true),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: big ? 2 : 1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: big ? 1.4 : 4.2,
            children: [
              for (var i = 0; i < q.options.length; i++)
                _ChoiceTile(
                  text: q.options[i],
                  selected: choice == i,
                  fontSize: big ? 48 : 22,
                  onTap: onChoose == null ? null : () => onChoose!(i),
                ),
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Prompt(q.card.front, junior: false),
        const SizedBox(height: 6),
        const Text(
          'Choose one answer',
          style: TextStyle(fontSize: 14, color: AppColors.inkMuted),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < q.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LetterOption(
              letter: String.fromCharCode(65 + i),
              text: q.options[i],
              selected: choice == i,
              onTap: onChoose == null ? null : () => onChoose!(i),
            ),
          ),
      ],
    );
  }
}

/// Junior answer tile; selected tiles get the indigo ring and tick.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.text,
    required this.selected,
    required this.fontSize,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final double fontSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: selected ? AppColors.primary : _lilacBorder,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: selected ? AppColors.primaryTint : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(
            color: selected ? AppColors.primary : _lilacBorder,
            width: selected ? 4 : 3,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: Fonts.display,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
                        color: selected ? AppColors.primaryDark : AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
              if (selected)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary,
                    child: Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LetterOption extends StatelessWidget {
  const _LetterOption({
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, border, ink) = selected
        ? (AppColors.primaryTint, AppColors.primary, AppColors.primaryDark)
        : (Colors.white, AppColors.groundBorder, AppColors.ink);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: selected ? 2.5 : 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: selected ? border : AppColors.chip,
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : AppColors.inkMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrueFalse extends StatelessWidget {
  const _TrueFalse({
    required this.q,
    required this.junior,
    required this.onAnswer,
  });

  final TrueFalseQuestion q;
  final bool junior;
  final ValueChanged<bool>? onAnswer;

  @override
  Widget build(BuildContext context) {
    final claim = q.claim == null
        ? null
        : Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(junior ? 20 : 12),
            ),
            child: Text(
              'Answer: ${q.claim}',
              style: TextStyle(
                fontFamily: junior ? Fonts.display : Fonts.body,
                fontSize: junior ? 24 : 17,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          );
    final spoken = q.claim == null
        ? '${q.statement} True or false?'
        : '${q.statement} Answer: ${q.claim}. True or false?';

    Widget choice(bool value) {
      final icon = value ? Icons.check_rounded : Icons.close_rounded;
      final text = value ? 'True' : 'False';
      return Expanded(
        child: Container(
          decoration: junior
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(color: AppColors.primary, offset: Offset(0, 7)),
                  ],
                )
              : null,
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(junior ? 30 : 16),
              side: BorderSide(
                color: junior ? AppColors.primary : AppColors.groundBorder,
                width: junior ? 3 : 1.5,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(junior ? 30 : 16),
              onTap: onAnswer == null ? null : () => onAnswer!(value),
              child: SizedBox(
                height: junior ? 176 : 64,
                child: junior
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: AppColors.primaryTint,
                            child: Icon(
                              icon,
                              size: 46,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            text,
                            style: const TextStyle(
                              fontFamily: Fonts.display,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            text,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      );
    }

    final buttons = Row(
      children: [choice(true), const SizedBox(width: 12), choice(false)],
    );

    if (junior) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _juniorCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _lilac,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'True or false?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _deepPurple,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _Prompt(q.statement, junior: true, spoken: spoken),
                ?claim,
              ],
            ),
          ),
          const SizedBox(height: 20),
          buttons,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Prompt(q.statement, junior: false),
        ?claim,
        const SizedBox(height: 24),
        buttons,
      ],
    );
  }
}

class _FillBlank extends StatelessWidget {
  const _FillBlank({
    required this.q,
    required this.junior,
    required this.tile,
    required this.onTile,
    required this.typed,
    required this.onTyped,
    required this.hint,
    required this.onHint,
  });

  final FillBlankQuestion q;
  final bool junior;
  final String? tile;
  final ValueChanged<String?> onTile;
  final TextEditingController typed;
  final VoidCallback onTyped;
  final bool hint;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    final gapStyle = TextStyle(
      fontFamily: junior ? Fonts.display : Fonts.body,
      fontSize: junior ? 28 : 18,
      fontWeight: FontWeight.w800,
      height: junior ? 1.6 : 1.4,
    );
    final gap = junior
        ? WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: tile == null ? null : () => onTile(null),
              child: Semantics(
                button: tile != null,
                label: tile == null
                    ? 'Empty gap'
                    : 'Gap filled with $tile. Tap to take it out',
                excludeSemantics: true,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 96,
                    minHeight: 52,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tile == null ? Colors.white : AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    border: tile == null
                        ? Border.all(color: const Color(0xFFB8ADE6), width: 3)
                        : null,
                  ),
                  child: Text(
                    tile ?? '',
                    style: gapStyle.copyWith(color: Colors.white, height: 1),
                  ),
                ),
              ),
            ),
          )
        : TextSpan(
            text: ' ______ ',
            style: gapStyle.copyWith(color: AppColors.primary),
          );

    final (before, after) = q.parts;
    final sentence = q.sentence == null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(q.card.front, style: gapStyle),
              const SizedBox(height: 8),
              Text.rich(TextSpan(children: [gap])),
            ],
          )
        : Text.rich(
            TextSpan(
              style: gapStyle,
              children: [
                TextSpan(text: before),
                gap,
                TextSpan(text: after),
              ],
            ),
          );

    if (junior) {
      final spoken = (q.sentence ?? q.card.front).replaceAll('___', 'blank');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _juniorCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _lilac,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'Fill the gap',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _deepPurple,
                        ),
                      ),
                    ),
                    const Spacer(),
                    ReadAloudButton(spoken, size: 64, filled: true),
                  ],
                ),
                const SizedBox(height: 12),
                sentence,
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tap a word to put it in the gap',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _deepPurple,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              for (final t in q.tiles)
                t == tile
                    ? Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFFB8ADE6),
                            width: 3,
                          ),
                        ),
                      )
                    : _ChoiceTile(
                        text: t,
                        selected: false,
                        fontSize: 26,
                        onTap: () => onTile(t),
                      ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sentence,
        const SizedBox(height: 20),
        TextField(
          controller: typed,
          onChanged: (_) => onTyped(),
          autocorrect: false,
          textCapitalization: TextCapitalization.none,
          decoration: InputDecoration(
            labelText: 'Your answer',
            hintText: hint ? '${q.answer.characters.first}…' : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          "Capitals don't matter. Small spelling slips are marked "
          '"close" and still count.',
          style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: hint
              ? Text(
                  'Starts with "${q.answer.characters.first.toUpperCase()}"',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                )
              : TextButton.icon(
                  onPressed: onHint,
                  icon: const Icon(Icons.lightbulb_outline_rounded),
                  label: const Text('Show first letter (−5 XP)'),
                ),
        ),
      ],
    );
  }
}

class _Match extends StatelessWidget {
  const _Match({
    required this.q,
    required this.junior,
    required this.selectedLeft,
    required this.matched,
    required this.slips,
    required this.shaking,
    required this.onLeft,
    required this.onRight,
  });

  final MatchQuestion q;
  final bool junior;
  final int? selectedLeft;
  final Set<int> matched;
  final int slips;
  final int? shaking;
  final ValueChanged<int> onLeft;
  final ValueChanged<int> onRight;

  @override
  Widget build(BuildContext context) {
    final n = q.pairs.length;
    Widget item(
      String text, {
      required bool done,
      required bool selected,
      required bool shake,
      required VoidCallback onTap,
    }) {
      final (bg, border) = done
          ? (_knewBg, AppColors.knew)
          : shake
          ? (AppColors.again, AppColors.againBorder)
          : selected
          ? (AppColors.primaryTint, AppColors.primary)
          : (Colors.white, junior ? _lilacBorder : AppColors.groundBorder);
      return AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(shake ? 6 : 0, 0, 0),
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(junior ? 24 : 14),
            side: BorderSide(color: border, width: selected || done ? 3.5 : 2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(junior ? 24 : 14),
            onTap: done ? null : onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: junior ? 88 : 56),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    if (done)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.knew,
                          size: 20,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: junior ? Fonts.display : Fonts.body,
                          fontSize: junior ? 22 : 15,
                          fontWeight: FontWeight.w800,
                          color: done ? AppColors.knewInk : AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final instructions = junior
        ? 'Tap one on the left, then its pair on the right'
        : 'Tap an item, then its pair. A wrong pair counts as one slip.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (junior)
          Row(
            children: [
              Expanded(
                child: Text(
                  instructions,
                  style: const TextStyle(
                    fontFamily: Fonts.display,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
              ReadAloudButton(instructions),
            ],
          )
        else
          Text(
            instructions,
            style: const TextStyle(fontSize: 15, color: AppColors.inkMuted),
          ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (var i = 0; i < n; i++)
                    item(
                      q.pairs[i].left,
                      done: matched.contains(i),
                      selected: selectedLeft == i,
                      shake: false,
                      onTap: () => onLeft(i),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  for (var r = 0; r < n; r++)
                    item(
                      q.pairs[q.rightOrder[r]].right,
                      done: matched.contains(q.rightOrder[r]),
                      selected: false,
                      shake: shaking == r,
                      onTap: () => onRight(r),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(junior ? 24 : 14),
          ),
          child: Row(
            children: [
              for (var i = 0; i < n; i++)
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < matched.length ? AppColors.knew : null,
                    border: i < matched.length
                        ? null
                        : Border.all(color: const Color(0xFFB8ADE6), width: 3),
                  ),
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${matched.length} of $n pairs matched',
                  style: TextStyle(
                    fontSize: junior ? 18 : 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!junior && slips > 0)
                Text(
                  '$slips slip${slips == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.againInk,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom panel after each answer: right/wrong, the explanation, and Next.
class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.answer,
    required this.junior,
    required this.last,
    required this.onNext,
  });

  final QuizAnswer answer;
  final bool junior;
  final bool last;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final q = answer.question;
    final right = answer.correct;
    final card = q.card;
    final why = card?.explain;
    final correct = correctText(q);
    final xp = right
        ? Xp.perRightAnswer - (answer.hintUsed ? Xp.hintCost : 0)
        : 0;

    final title = junior
        ? (right ? 'Yes! Right!' : 'Almost!')
        : (right ? 'Correct' : (answer.timedOut ? "Time's up" : 'Not quite'));
    final titleColor = right ? AppColors.knewInk : AppColors.againInk;
    final badge = CircleAvatar(
      radius: junior ? 32 : 22,
      backgroundColor: right ? AppColors.knew : AppColors.againBorder,
      child: Icon(
        right ? Icons.check_rounded : Icons.replay_rounded,
        color: Colors.white,
        size: junior ? 38 : 26,
      ),
    );

    final children = <Widget>[
      Center(
        child: Container(
          width: 48,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFFE3D8C6),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          badge,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: junior ? Fonts.display : Fonts.body,
                fontSize: junior ? 32 : 22,
                fontWeight: FontWeight.w800,
                height: 1,
                color: titleColor,
              ),
            ),
          ),
          if (junior && right) const MyOwl(size: 64),
          if (!junior && right && q is! MatchQuestion)
            Text(
              '+$xp XP',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    ];

    if (answer.close) {
      children.addAll([
        const SizedBox(height: 10),
        Text(
          'Close! It is spelt "$correct".',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ]);
    }

    if (!right && q is! MatchQuestion) {
      children.add(const SizedBox(height: 12));
      if (junior) {
        children.add(
          Text(
            'The answer is $correct',
            style: const TextStyle(
              fontFamily: Fonts.display,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      } else {
        children.add(
          Row(
            children: [
              Expanded(
                child: _Said('You said', answer.given ?? '—', wrong: true),
              ),
              const SizedBox(width: 10),
              Expanded(child: _Said('Answer', correct, wrong: false)),
            ],
          ),
        );
      }
    }
    if (q is MatchQuestion && !right) {
      children.addAll([
        const SizedBox(height: 10),
        Text(
          '${answer.slips} slips this time. Try for fewer next time!',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ]);
    }

    final explain = why ?? (q is MatchQuestion ? null : '$correct.');
    if (explain != null) {
      children.addAll([
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.ground,
            borderRadius: BorderRadius.circular(junior ? 20 : 12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!junior)
                      const Text(
                        'Why',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    Text(
                      explain,
                      style: TextStyle(
                        fontSize: junior ? 20 : 15,
                        fontWeight: junior ? FontWeight.w700 : FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                    if (!junior && card?.source != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        card!.source!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (junior) ...[
                const SizedBox(width: 8),
                ReadAloudButton(explain),
              ],
            ],
          ),
        ),
      ]);
    }

    if (junior && right && q is! MatchQuestion) {
      children.addAll([
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.starBg,
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StarIcon(size: 22),
                SizedBox(width: 6),
                Text(
                  '+1 star',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.starInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ]);
    }
    if (!right && card != null) {
      children.addAll([
        const SizedBox(height: 10),
        Text(
          junior
              ? "We'll try this one again later."
              : 'Added to your review deck',
          style: TextStyle(
            fontSize: junior ? 18 : 14,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
      ]);
    }

    children.addAll([
      const SizedBox(height: 16),
      PrimaryButton(
        label: last ? 'See results' : 'Next',
        icon: junior ? Icons.arrow_forward_rounded : null,
        onPressed: onNext,
      ),
    ]);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(junior ? 32 : 24),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _Said extends StatelessWidget {
  const _Said(this.label, this.value, {required this.wrong});
  final String label;
  final String value;
  final bool wrong;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: wrong ? AppColors.again : _knewBg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: wrong ? AppColors.againInk : AppColors.knewInk,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
