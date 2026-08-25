import 'dart:math';

import 'package:english_app/domain/quiz/word.dart';

enum QuizKind { listenPickPicture, picturePickWord, flipMatch }

class QuizQuestion {
  const QuizQuestion({required this.prompt, required this.choices});

  final Word prompt;
  final List<Word> choices;
}

class EngineFeedback {
  const EngineFeedback({
    required this.correct,
    required this.coinsDelta,
    required this.roundComplete,
  });

  final bool correct;
  final int coinsDelta;
  final bool roundComplete;
}

class FlipCard {
  const FlipCard({
    required this.index,
    required this.wordId,
    required this.isImage,
    required this.faceUp,
    required this.matched,
  });

  final int index;
  final String wordId;
  final bool isImage;
  final bool faceUp;
  final bool matched;

  FlipCard copyWith({bool? faceUp, bool? matched}) => FlipCard(
        index: index,
        wordId: wordId,
        isImage: isImage,
        faceUp: faceUp ?? this.faceUp,
        matched: matched ?? this.matched,
      );
}

class QuizEngine {
  QuizEngine._({
    required this.kind,
    required List<QuizQuestion> questions,
    required List<FlipCard> cards,
  })  : _questions = questions,
        _cards = cards;

  factory QuizEngine.start({
    required QuizKind kind,
    required List<Word> bank,
    required Random random,
  }) {
    if (kind == QuizKind.flipMatch) {
      if (bank.length < 6) {
        throw ArgumentError('flipMatch needs 6 words');
      }
      final picked = [...bank]..shuffle(random);
      final six = picked.take(6).toList();
      final cards = <FlipCard>[];
      var i = 0;
      for (final word in six) {
        cards.add(FlipCard(
          index: i++,
          wordId: word.id,
          isImage: true,
          faceUp: false,
          matched: false,
        ));
        cards.add(FlipCard(
          index: i++,
          wordId: word.id,
          isImage: false,
          faceUp: false,
          matched: false,
        ));
      }
      cards.shuffle(random);
      final numbered = [
        for (var n = 0; n < cards.length; n++)
          FlipCard(
            index: n,
            wordId: cards[n].wordId,
            isImage: cards[n].isImage,
            faceUp: false,
            matched: false,
          ),
      ];
      return QuizEngine._(kind: kind, questions: const [], cards: numbered);
    }

    if (bank.length < 10) {
      throw ArgumentError('pick modes need 10 words');
    }
    final picked = [...bank]..shuffle(random);
    final ten = picked.take(10).toList();
    final questions = ten.map((prompt) {
      final others = bank.where((word) => word.id != prompt.id).toList()
        ..shuffle(random);
      final choices = [prompt, ...others.take(3)]..shuffle(random);
      return QuizQuestion(prompt: prompt, choices: choices);
    }).toList();
    return QuizEngine._(kind: kind, questions: questions, cards: const []);
  }

  final QuizKind kind;
  final List<QuizQuestion> _questions;
  final List<FlipCard> _cards;
  int? _openIndex;
  int index = 0;
  int coinsEarned = 0;
  int streak = 0;
  bool isComplete = false;

  List<FlipCard> get cards => List.unmodifiable(_cards);

  int get total => kind == QuizKind.flipMatch ? 6 : _questions.length;

  QuizQuestion get currentQuestion {
    if (kind == QuizKind.flipMatch) {
      throw StateError('flipMatch has no currentQuestion');
    }
    if (isComplete || index >= _questions.length) {
      throw StateError('round already complete');
    }
    return _questions[index];
  }

  EngineFeedback submitAnswer(String wordId) {
    if (kind == QuizKind.flipMatch) {
      throw StateError('use flip()');
    }
    if (isComplete) {
      throw StateError('round already complete');
    }

    final correct = wordId == currentQuestion.prompt.id;
    var delta = 0;
    if (correct) {
      streak += 1;
      delta = 3 + (streak >= 3 ? 1 : 0);
      coinsEarned += delta;
    } else {
      streak = 0;
    }

    index += 1;
    if (index >= _questions.length) {
      isComplete = true;
    }

    return EngineFeedback(
      correct: correct,
      coinsDelta: delta,
      roundComplete: isComplete,
    );
  }

  EngineFeedback flip(int cardIndex) {
    if (kind != QuizKind.flipMatch) {
      throw StateError('use submitAnswer()');
    }
    if (isComplete) {
      throw StateError('round already complete');
    }

    final card = _cards[cardIndex];
    if (card.matched || card.faceUp) {
      return const EngineFeedback(
        correct: false,
        coinsDelta: 0,
        roundComplete: false,
      );
    }

    _cards[cardIndex] = card.copyWith(faceUp: true);
    if (_openIndex == null) {
      _openIndex = cardIndex;
      return const EngineFeedback(
        correct: false,
        coinsDelta: 0,
        roundComplete: false,
      );
    }

    final first = _cards[_openIndex!];
    final second = _cards[cardIndex];
    final matched = first.wordId == second.wordId;
    var delta = 0;
    if (matched) {
      _cards[_openIndex!] = first.copyWith(matched: true, faceUp: true);
      _cards[cardIndex] = second.copyWith(matched: true, faceUp: true);
      streak += 1;
      delta = 3 + (streak >= 3 ? 1 : 0);
      coinsEarned += delta;
    } else {
      _cards[_openIndex!] = first.copyWith(faceUp: false);
      _cards[cardIndex] = second.copyWith(faceUp: false);
      streak = 0;
    }
    _openIndex = null;

    final done = _cards.every((c) => c.matched);
    if (done) {
      isComplete = true;
    }

    return EngineFeedback(
      correct: matched,
      coinsDelta: delta,
      roundComplete: done,
    );
  }
}
