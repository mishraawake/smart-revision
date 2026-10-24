import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/scheduler.dart';
import '../models/deck.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'session_complete_screen.dart';

void startReview(
  BuildContext context,
  List<Flashcard> cards, {
  bool practice = false,
}) {
  if (cards.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReviewScreen(cards: cards, practice: practice),
    ),
  );
}

/// Flashcard session: front → "Show answer" → back → "Knew it" / "Didn't know".
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.cards, this.practice = false});

  final List<Flashcard> cards;

  /// Practice runs do not change scheduling, stars or streaks.
  final bool practice;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  var _index = 0;
  var _revealed = false;
  var _knew = 0;
  final _missed = <Flashcard>[];
  final _started = DateTime.now();
  late final int _goalDoneBefore;
  var _busy = false;

  Flashcard get _card => widget.cards[_index];

  @override
  void initState() {
    super.initState();
    // Captured before the first answer counts towards today's goal.
    _goalDoneBefore = AppScope.read(context).goalDoneToday;
  }

  Future<void> _answer(bool knew) async {
    if (_busy) return;
    _busy = true;
    final state = AppScope.read(context);
    SpeakerScope.of(context).stop();
    // The card is graded straight away; only the save to disk is slow, so
    // the next card shows without waiting for it.
    final saved = state.answer(_card, knew: knew, practice: widget.practice);
    if (knew) {
      _knew++;
    } else {
      _missed.add(_card);
    }
    if (_index + 1 < widget.cards.length) {
      setState(() {
        _index++;
        _revealed = false;
      });
      _busy = false;
      unawaited(saved);
      return;
    }
    await saved;
    final summary = await state.finishSession(
      knew: _knew,
      missed: _missed,
      duration: DateTime.now().difference(_started),
      goalDoneBefore: _goalDoneBefore,
      practice: widget.practice,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SessionCompleteScreen(summary: summary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final junior = Tier.of(context).isJunior;
    final subject = state.subjectById(_card.subjectId)!;
    final chapter = subject.chapters.firstWhere((c) => c.id == _card.chapterId);
    final style = SubjectStyle.of(subject.id);

    return Scaffold(
      backgroundColor: junior ? style.background : AppColors.ground,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, junior ? 16 : 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                junior: junior,
                index: _index,
                total: widget.cards.length,
                label: junior
                    ? 'Card ${_index + 1} of ${widget.cards.length} · ${subject.name}'
                    : '${subject.name} · Ch ${chapter.number}',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _revealed
                    ? _Back(card: _card, junior: junior)
                    : _Front(card: _card, junior: junior),
              ),
              const SizedBox(height: 16),
              if (!_revealed)
                PrimaryButton(
                  label: 'Show answer',
                  icon: junior ? Icons.flip_rounded : null,
                  onPressed: () => setState(() => _revealed = true),
                )
              else
                _AnswerButtons(
                  junior: junior,
                  practice: widget.practice,
                  next: Scheduler.nextInterval(state.stateOf(_card)),
                  onAnswer: _answer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.junior,
    required this.index,
    required this.total,
    required this.label,
  });

  final bool junior;
  final int index;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final close = Semantics(
      label: 'Stop and go home',
      button: true,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).pop(),
          child: SizedBox.square(
            dimension: junior ? 56 : 44,
            child: const Icon(Icons.close_rounded, color: AppColors.inkMuted),
          ),
        ),
      ),
    );

    if (!junior) {
      return Row(
        children: [
          close,
          const SizedBox(width: 12),
          Text(
            '${index + 1}/$total',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 10),
          Expanded(child: ProgressBar((index + 1) / total, height: 6)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        close,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: 'Card ${index + 1} of $total',
                child: Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (var i = 0; i < total; i++)
                      i == index
                          ? Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 4,
                                ),
                              ),
                            )
                          : Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < index
                                    ? AppColors.primary
                                    : AppColors.progressTrack,
                              ),
                            ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3B1D8F),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

BoxDecoration _cardDecoration(bool junior) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(junior ? 32 : 20),
  boxShadow: junior
      ? const [BoxShadow(color: Color(0xFFD6CCF3), offset: Offset(0, 8))]
      : const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
);

class _Front extends StatelessWidget {
  const _Front({required this.card, required this.junior});
  final Flashcard card;
  final bool junior;

  @override
  Widget build(BuildContext context) => Container(
    decoration: _cardDecoration(junior),
    padding: const EdgeInsets.all(20),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  card.front,
                  style: junior
                      ? const TextStyle(
                          fontFamily: Fonts.display,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        )
                      : const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                ),
              ),
              if (junior) ...[
                const SizedBox(width: 10),
                ReadAloudButton(card.front),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (card.hint != null && junior)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.ground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      card.hint!,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ReadAloudButton(card.hint!, size: 48),
                ],
              ),
            )
          else if (!junior)
            Text(
              card.hint ?? 'Think of your answer, then flip the card.',
              style: const TextStyle(fontSize: 16, color: AppColors.inkMuted),
            ),
        ],
      ),
    ),
  );
}

class _Back extends StatelessWidget {
  const _Back({required this.card, required this.junior});
  final Flashcard card;
  final bool junior;

  @override
  Widget build(BuildContext context) {
    if (!junior) {
      return Container(
        decoration: _cardDecoration(false),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.front,
                style: const TextStyle(fontSize: 16, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 16),
              const Text(
                'ANSWER',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                card.back,
                style: const TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              if (card.backWord != null)
                Text(
                  card.backWord!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.inkMuted,
                  ),
                ),
              if (card.explain != null) ...[
                const SizedBox(height: 16),
                Text(
                  card.explain!,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ],
              if (card.source != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      size: 16,
                      color: AppColors.inkMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        card.source!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    final shortAnswer = card.back.length <= 3;
    final spokenAnswer = card.backWord ?? card.back;
    return Container(
      decoration: _cardDecoration(true),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              card.front,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (shortAnswer)
                  Container(
                    width: 128,
                    height: 128,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.starBg,
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: Text(
                      card.back,
                      style: const TextStyle(
                        fontFamily: Fonts.display,
                        fontSize: 80,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: Text(
                      card.back,
                      style: const TextStyle(
                        fontFamily: Fonts.display,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                const SizedBox(width: 18),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (card.backWord != null)
                      Text(
                        card.backWord!,
                        style: const TextStyle(
                          fontFamily: Fonts.display,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    const SizedBox(height: 8),
                    ReadAloudButton(spokenAnswer, size: 72, filled: true),
                  ],
                ),
              ],
            ),
            if (card.explain != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.ground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        card.explain!,
                        style: const TextStyle(
                          fontFamily: Fonts.display,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ReadAloudButton(card.explain!, size: 48),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'Did you know it?',
                    style: TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ReadAloudButton('Did you know it?'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerButtons extends StatelessWidget {
  const _AnswerButtons({
    required this.junior,
    required this.practice,
    required this.next,
    required this.onAnswer,
  });

  final bool junior;
  final bool practice;
  final Duration next;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    final height = junior ? 128.0 : 64.0;
    final radius = BorderRadius.circular(junior ? 28 : 16);
    final labelStyle = junior
        ? const TextStyle(
            fontFamily: Fonts.display,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          )
        : const TextStyle(fontSize: 17, fontWeight: FontWeight.w800);
    const captionStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);

    Widget button({
      required bool knew,
      required String label,
      required String? caption,
    }) => Expanded(
      child: Material(
        color: knew ? AppColors.knew : AppColors.again,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: knew
              ? BorderSide.none
              : BorderSide(color: AppColors.againBorder, width: junior ? 3 : 2),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: () => onAnswer(knew),
          child: SizedBox(
            height: height,
            child: DefaultTextStyle.merge(
              style: TextStyle(color: knew ? Colors.white : AppColors.againInk),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: knew ? Colors.white : AppColors.againInk,
                  size: junior ? 44 : 22,
                ),
                child: junior
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            knew ? Icons.check_rounded : Icons.replay_rounded,
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(label, style: labelStyle),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              children: [
                                Icon(
                                  knew
                                      ? Icons.check_rounded
                                      : Icons.replay_rounded,
                                ),
                                const SizedBox(width: 6),
                                Text(label, style: labelStyle),
                              ],
                            ),
                          ),
                          if (caption != null)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(caption, style: captionStyle),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );

    return Row(
      children: [
        button(
          knew: false,
          label: "Didn't know",
          caption: practice
              ? null
              : 'Again in ${Scheduler.againDelay.inMinutes} min',
        ),
        const SizedBox(width: 12),
        button(
          knew: true,
          label: 'Knew it',
          caption: practice ? null : 'Next ${describeInterval(next)}',
        ),
      ],
    );
  }
}
