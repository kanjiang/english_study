import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_app/data/local_cache.dart';
import 'package:english_app/data/user_repository.dart';
import 'package:english_app/data/word_audio_player.dart';
import 'package:english_app/data/word_bank.dart';
import 'package:english_app/domain/quiz/word.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  try {
    return FirebaseAuth.instance.authStateChanges();
  } catch (_) {
    return Stream<User?>.value(null);
  }
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return FirestoreUserRepository(
    auth: FirebaseAuth.instance,
    db: FirebaseFirestore.instance,
    cache: LocalCache(),
  );
});

final foregroundUserSnapshotProvider = StateProvider<UserSnapshot?>((ref) {
  return null;
});

final wordBankProvider = Provider<List<Word>>((ref) {
  return kWordBank;
});

final wordAudioPlayerProvider = Provider<WordAudioPlayer>((ref) {
  final player = JustAudioWordPlayer();
  ref.onDispose(player.dispose);
  return player;
});
