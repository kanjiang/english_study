// ignore_for_file: non_const_argument_for_const_parameter

import 'dart:async';
import 'dart:math';

import 'package:english_app/app/providers.dart';
import 'package:english_app/domain/quiz/quiz_engine.dart';
import 'package:english_app/domain/quiz/word.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GameThemeSpec {
  const GameThemeSpec({
    required this.title,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.correctText,
    required this.wrongText,
    required this.emptyPromptIcon,
  });

  final String title;
  final Color backgroundColor;
  final Color foregroundColor;
  final String correctText;
  final String wrongText;
  final IconData emptyPromptIcon;
}

class GameSession extends ConsumerStatefulWidget {
  const GameSession({required this.kind, required this.theme, super.key});

  final QuizKind kind;
  final GameThemeSpec theme;

  @override
  ConsumerState<GameSession> createState() => _GameSessionState();
}

class _GameSessionState extends ConsumerState<GameSession> {
  late final QuizEngine _engine;
  late final Map<String, Word> _wordsById;
  bool _settling = false;
  _VisibleGameFeedback? _visibleFeedback;
  Timer? _feedbackTimer;
  int _feedbackSerial = 0;

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final bank = ref.read(wordBankProvider);
    _wordsById = {for (final word in bank) word.id: word};
    _engine = QuizEngine.start(kind: widget.kind, bank: bank, random: Random());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_playCurrentPromptIfNeeded());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.theme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.theme.title),
        backgroundColor: widget.theme.backgroundColor,
        foregroundColor: widget.theme.foregroundColor,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: widget.kind == QuizKind.flipMatch
                  ? _buildFlipMatch(context)
                  : _buildPickQuestion(context),
            ),
            if (_visibleFeedback case final feedback?)
              Positioned(
                top: 24,
                left: 20,
                right: 20,
                child: _GameFeedbackEffect(feedback: feedback),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlipMatch(BuildContext context) {
    return Column(
      children: [
        Text(
          '找到图标和英文单词',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: widget.theme.foregroundColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.count(
            crossAxisCount: 4,
            childAspectRatio: 1.2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final card in _engine.cards)
                KeyedSubtree(
                  key: ValueKey('card_${card.index}_${card.wordId}'),
                  child: _TreasureCard(
                    key: ValueKey('card_${card.index}'),
                    card: card,
                    word: _wordsById[card.wordId]!,
                    onTap: _settling ? null : () => _flip(card.index),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPickQuestion(BuildContext context) {
    final question = _engine.currentQuestion;
    final isListening = widget.kind == QuizKind.listenPickPicture;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isListening)
                  FilledButton.icon(
                    key: const ValueKey('prompt_replay_button'),
                    onPressed: _settling ? null : _playCurrentPromptIfNeeded,
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.theme.foregroundColor,
                      foregroundColor: widget.theme.backgroundColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('再听一次'),
                  )
                else
                  _WordImage(
                    key: const ValueKey('prompt_image'),
                    word: question.prompt,
                    size: 96,
                  ),
                if (isListening) ...[
                  const SizedBox(height: 16),
                  Text(
                    '听一听，选择正确图片',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: widget.theme.foregroundColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        for (final choice in question.choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton(
              key: Key('choice_${choice.id}'),
              onPressed: _settling ? null : () => _submit(choice.id),
              style: FilledButton.styleFrom(
                backgroundColor: widget.theme.foregroundColor,
                foregroundColor: widget.theme.backgroundColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: isListening
                  ? _WordImage(word: choice, size: 48)
                  : Text(
                      choice.en,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: widget.theme.backgroundColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
      ],
    );
  }

  Future<void> _submit(String wordId) async {
    final feedback = _engine.submitAnswer(wordId);
    await _afterFeedback(feedback);
  }

  Future<void> _flip(int cardIndex) async {
    final feedback = _engine.flip(cardIndex);
    setState(() {});
    await _afterFeedback(feedback);
  }

  Future<void> _afterFeedback(EngineFeedback feedback) async {
    if (feedback.judged) {
      if (feedback.correct) {
        _showFeedback(widget.theme.correctText, correct: true);
      } else {
        _showFeedback(widget.theme.wrongText, correct: false);
      }
      unawaited(_playFeedbackSound(correct: feedback.correct));
    }

    if (widget.kind == QuizKind.flipMatch &&
        feedback.judged &&
        !feedback.correct &&
        !feedback.roundComplete) {
      _settling = true;
      if (mounted) {
        setState(() {});
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
      _engine.hideUnmatchedFaceUpCards();
      _settling = false;
      if (mounted) {
        setState(() {});
      }
    }

    final foreground = ref.read(foregroundUserSnapshotProvider);
    final lockedForeground = foreground != null && foreground.time.isLocked
        ? foreground
        : null;

    if (feedback.roundComplete) {
      await _settleAndPop(lockedSnapshot: lockedForeground);
      return;
    }

    if (feedback.judged && (foreground?.time.isLocked ?? false)) {
      await _settleAndPop(lockedSnapshot: foreground);
      return;
    }

    if (mounted) {
      setState(() {});
      await _playCurrentPromptIfNeeded();
    }
  }

  void _showFeedback(String text, {required bool correct}) {
    if (!mounted) {
      return;
    }
    final feedback = _VisibleGameFeedback(
      text: text,
      correct: correct,
      serial: ++_feedbackSerial,
    );
    setState(() {
      _visibleFeedback = feedback;
    });
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted || _visibleFeedback?.serial != feedback.serial) {
        return;
      }
      setState(() {
        _visibleFeedback = null;
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(milliseconds: 600),
      ),
    );
  }

  Future<void> _playFeedbackSound({required bool correct}) async {
    final asset = correct
        ? 'assets/audio/sfx/correct.wav'
        : 'assets/audio/sfx/wrong.wav';
    try {
      await ref.read(soundEffectPlayerProvider).play(asset);
    } catch (_) {
      // Feedback sounds should not block game progress if an asset is missing.
    }
  }

  Future<void> _playCurrentPromptIfNeeded() async {
    if (widget.kind != QuizKind.listenPickPicture || _engine.isComplete) {
      return;
    }
    await ref
        .read(wordAudioPlayerProvider)
        .play(_engine.currentQuestion.prompt.audioAsset);
  }

  Future<void> _settleAndPop({UserSnapshot? lockedSnapshot}) async {
    if (_settling) {
      return;
    }
    _settling = true;

    final repository = ref.read(userRepositoryProvider);
    final score = _engine.coinsEarned;
    await repository.addPendingCoins(score);
    await repository.flushPendingCoins();

    final snapshot = await repository.load();
    if (snapshot != null) {
      await repository.save(
        _withScore(_mergeLockedTime(snapshot, lockedSnapshot), score),
      );
    }

    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    }

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  UserSnapshot _withScore(UserSnapshot snapshot, int score) {
    switch (widget.kind) {
      case QuizKind.flipMatch:
        return snapshot.copyWith(
          gameStats: snapshot.gameStats.copyWith(treasureLastScore: score),
        );
      case QuizKind.listenPickPicture:
        return snapshot.copyWith(
          gameStats: snapshot.gameStats.copyWith(firefighterLastScore: score),
        );
      case QuizKind.picturePickWord:
        return snapshot.copyWith(
          gameStats: snapshot.gameStats.copyWith(monsterLastScore: score),
        );
    }
  }

  UserSnapshot _mergeLockedTime(
    UserSnapshot snapshot,
    UserSnapshot? lockedSnapshot,
  ) {
    if (lockedSnapshot == null ||
        lockedSnapshot.uid != snapshot.uid ||
        !lockedSnapshot.time.isLocked) {
      return snapshot;
    }

    return snapshot.copyWith(time: lockedSnapshot.time);
  }
}

class _VisibleGameFeedback {
  const _VisibleGameFeedback({
    required this.text,
    required this.correct,
    required this.serial,
  });

  final String text;
  final bool correct;
  final int serial;
}

class _GameFeedbackEffect extends StatelessWidget {
  const _GameFeedbackEffect({required this.feedback});

  final _VisibleGameFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final background = feedback.correct
        ? Colors.greenAccent.shade400
        : Colors.orangeAccent.shade400;
    final icon = feedback.correct
        ? Icons.stars_rounded
        : Icons.sentiment_satisfied_alt_rounded;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.82, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Opacity(opacity: scale.clamp(0.0, 1.0), child: child),
        );
      },
      child: Material(
        key: const ValueKey('game_feedback_effect'),
        elevation: 8,
        color: background,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(width: 8),
              Text(
                feedback.text,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TreasureCard extends StatelessWidget {
  const _TreasureCard({
    required this.card,
    required this.word,
    required this.onTap,
    super.key,
  });

  final FlipCard card;
  final Word word;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isRevealed = card.faceUp || card.matched;
    final Widget content;
    if (!isRevealed) {
      content = const SizedBox(width: 42, height: 42);
    } else if (card.isImage) {
      content = _WordImage(word: word, size: 54);
    } else {
      content = Text(
        word.en,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      );
    }

    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: card.matched ? Colors.white70 : Colors.white,
        foregroundColor: Colors.brown.shade800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: AnimatedOpacity(
        opacity: card.matched ? 0.45 : 1,
        duration: const Duration(milliseconds: 150),
        child: content,
      ),
    );
  }
}

class _WordImage extends StatelessWidget {
  const _WordImage({required this.word, required this.size, super.key});

  final Word word;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        word.imageAsset,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.image_outlined,
          size: size * 0.72,
          color: Colors.black45,
        ),
      ),
    );
  }
}
