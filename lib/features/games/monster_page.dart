import 'package:english_app/domain/quiz/quiz_engine.dart';
import 'package:english_app/features/games/game_session.dart';
import 'package:flutter/material.dart';

class MonsterPage extends StatelessWidget {
  const MonsterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const GameSession(
      kind: QuizKind.picturePickWord,
      theme: GameThemeSpec(
        title: '打怪兽',
        backgroundColor: Color(0xFF311B92),
        foregroundColor: Colors.white,
        correctText: '击中！',
        wrongText: '落空！',
        emptyPromptIcon: Icons.cruelty_free,
      ),
    );
  }
}
