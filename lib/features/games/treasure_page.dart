import 'package:english_app/domain/quiz/quiz_engine.dart';
import 'package:english_app/features/games/game_session.dart';
import 'package:flutter/material.dart';

class TreasurePage extends StatelessWidget {
  const TreasurePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const GameSession(
      kind: QuizKind.flipMatch,
      theme: GameThemeSpec(
        title: '寻宝翻牌',
        backgroundColor: Color(0xFFFFC107),
        foregroundColor: Color(0xFF5D3A00),
        correctText: '找到宝藏！',
        wrongText: '没配对！',
        emptyPromptIcon: Icons.diamond,
      ),
    );
  }
}
