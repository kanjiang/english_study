import 'dart:math';

import 'package:english_app/domain/quiz/quiz_engine.dart';
import 'package:english_app/domain/quiz/word.dart';
import 'package:flutter_test/flutter_test.dart';

Word w(String id) => Word(
      id: id,
      en: id,
      zh: id,
      category: 'animals',
      iconCodePoint: 0xe91d,
      audioAsset: 'assets/audio/beep.mp3',
    );

List<Word> bank10() => List.generate(10, (i) => w('w$i'));

void main() {
  test('listen mode starts with 10 questions and 4 choices', () {
    final e = QuizEngine.start(
      kind: QuizKind.listenPickPicture,
      bank: bank10(),
      random: Random(1),
    );
    expect(e.total, 10);
    expect(e.currentQuestion.choices, hasLength(4));
    expect(e.currentQuestion.choices.map((c) => c.id),
        contains(e.currentQuestion.prompt.id));
  });

  test('correct answer awards 3 coins and advances', () {
    final e = QuizEngine.start(
      kind: QuizKind.picturePickWord,
      bank: bank10(),
      random: Random(1),
    );
    final id = e.currentQuestion.prompt.id;
    final fb = e.submitAnswer(id);
    expect(fb.correct, isTrue);
    expect(fb.coinsDelta, 3);
    expect(e.coinsEarned, 3);
    expect(e.index, 1);
  });

  test('wrong answer awards 0, resets streak, still advances', () {
    final e = QuizEngine.start(
      kind: QuizKind.listenPickPicture,
      bank: bank10(),
      random: Random(1),
    );
    final correct = e.currentQuestion.prompt.id;
    final wrong = e.currentQuestion.choices.firstWhere((c) => c.id != correct).id;
    final fb = e.submitAnswer(wrong);
    expect(fb.correct, isFalse);
    expect(fb.coinsDelta, 0);
    expect(e.streak, 0);
    expect(e.index, 1);
  });

  test('streak of 3 adds bonus coin on the third correct', () {
    final e = QuizEngine.start(
      kind: QuizKind.picturePickWord,
      bank: bank10(),
      random: Random(2),
    );
    var lastDelta = 0;
    for (var i = 0; i < 3; i++) {
      lastDelta = e.submitAnswer(e.currentQuestion.prompt.id).coinsDelta;
    }
    expect(lastDelta, 4);
    expect(e.coinsEarned, 3 + 3 + 4);
  });

  test('cannot retry same question after wrong answer', () {
    final e = QuizEngine.start(
      kind: QuizKind.listenPickPicture,
      bank: bank10(),
      random: Random(1),
    );
    final firstPrompt = e.currentQuestion.prompt.id;
    final wrong =
        e.currentQuestion.choices.firstWhere((c) => c.id != firstPrompt).id;
    e.submitAnswer(wrong);
    expect(e.currentQuestion.prompt.id, isNot(firstPrompt));
  });

  test('tenth answer completes the round', () {
    final e = QuizEngine.start(
      kind: QuizKind.listenPickPicture,
      bank: bank10(),
      random: Random(1),
    );
    EngineFeedback? fb;
    while (!e.isComplete) {
      fb = e.submitAnswer(e.currentQuestion.prompt.id);
    }
    expect(fb!.roundComplete, isTrue);
    expect(e.isComplete, isTrue);
    expect(e.index, 10);
    expect(e.total, 10);
    expect(() => e.currentQuestion, throwsStateError);
  });

  test('flipMatch deals 12 cards from 6 words', () {
    final e = QuizEngine.start(
      kind: QuizKind.flipMatch,
      bank: bank10(),
      random: Random(1),
    );
    expect(e.cards, hasLength(12));
    expect(e.total, 6);
  });

  test('matching image and text pair awards coins', () {
    final e = QuizEngine.start(
      kind: QuizKind.flipMatch,
      bank: bank10(),
      random: Random(1),
    );
    final first = e.cards.first;
    final match = e.cards.firstWhere(
      (c) => c.wordId == first.wordId && c.index != first.index,
    );
    e.flip(first.index);
    final fb = e.flip(match.index);
    expect(fb.correct, isTrue);
    expect(fb.coinsDelta, 3);
    expect(e.cards[first.index].matched, isTrue);
  });

  test('mismatch flips both back and resets streak', () {
    final e = QuizEngine.start(
      kind: QuizKind.flipMatch,
      bank: bank10(),
      random: Random(1),
    );
    final a = e.cards[0];
    final b = e.cards.firstWhere((c) => c.wordId != a.wordId);
    e.flip(a.index);
    final fb = e.flip(b.index);
    expect(fb.correct, isFalse);
    expect(e.streak, 0);
    expect(e.cards[a.index].faceUp, isFalse);
    expect(e.cards[b.index].faceUp, isFalse);
  });
}
