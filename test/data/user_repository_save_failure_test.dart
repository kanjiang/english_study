// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_app/data/local_cache.dart';
import 'package:english_app/data/user_repository.dart';
import 'package:english_app/domain/time/time_quota.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/seed.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('save keeps increased usedSeconds in local cache when firestore write fails', () async {
    final cache = LocalCache();
    final repo = FirestoreUserRepository(
      auth: _FakeFirebaseAuth(uid: 'u1'),
      db: _ThrowingFirebaseFirestore(),
      cache: cache,
    );

    await repo.createInitial(seed());

    final updated = seed().copyWith(
      time: TimeQuota(
        dailyLimitMinutes: 30,
        bonusMinutes: 0,
        usedSeconds: 45,
        usedOnDate: '2026-08-25',
      ),
    );

    await repo.save(updated);

    final cached = await cache.loadSnapshot();
    expect(cached, isNotNull);
    expect(cached!.time.usedSeconds, 45);
    expect(await cache.loadUsedSeconds(), 45);
  });
}

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth({this.uid});

  final String? uid;

  @override
  User? get currentUser => uid == null ? null : _FakeUser(uid!);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingFirebaseFirestore implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _ThrowingCollectionReference();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingCollectionReference
    implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _ThrowingDocumentReference();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingDocumentReference
    implements DocumentReference<Map<String, dynamic>> {
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      message: 'network unavailable',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  _FakeUser(this._uid);

  final String _uid;

  @override
  String get uid => _uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
