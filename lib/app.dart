import 'package:english_app/features/auth/auth_gate.dart';
import 'package:flutter/material.dart';

class XiaoCiXingApp extends StatelessWidget {
  const XiaoCiXingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '小词星',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
