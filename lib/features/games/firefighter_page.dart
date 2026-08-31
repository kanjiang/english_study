import 'package:english_app/domain/quiz/quiz_engine.dart';
import 'package:english_app/features/games/game_session.dart';
import 'package:flutter/material.dart';

class FirefighterPage extends StatelessWidget {
  const FirefighterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const GameSession(
      kind: QuizKind.listenPickPicture,
      theme: GameThemeSpec(
        title: '消防员灭火',
        backgroundColor: Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        correctText: '灭火！',
        wrongText: '火没灭！',
        emptyPromptIcon: Icons.local_fire_department,
      ),
    );
  }
}
