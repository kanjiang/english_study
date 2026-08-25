import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_app/data/local_cache.dart';
import 'package:english_app/data/user_repository.dart';
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
