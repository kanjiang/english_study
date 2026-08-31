// ignore_for_file: must_be_immutable, prefer_initializing_formals, subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_app/data/local_cache.dart';
import 'package:english_app/data/user_repository.dart';
import 'package:english_app/domain/time/time_quota.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/domain/wallet/wallet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/seed.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('watch emits null when fake repository is empty', () async {
    final repo = FakeUserRepository();

    await expectLater(
      repo.watch().first.timeout(const Duration(seconds: 1)),
      completion(isNull),
    );
  });

  test('watch emits null when signed out even with cached snapshot', () async {
    final cache = LocalCache();
    await cache.saveSnapshot(seed());

    final repo = FirestoreUserRepository(
      auth: _FakeFirebaseAuth(),
      db: _FakeFirebaseFirestore(),
      cache: cache,
    );

    await expectLater(
      repo.watch().first.timeout(const Duration(seconds: 1)),
      completion(isNull),
    );
  });

  test(
    'watch and load ignore cached snapshot for a different signed-in uid',
    () async {
      final cache = LocalCache();
      await cache.saveSnapshot(seed());

      final repo = FirestoreUserRepository(
        auth: _FakeFirebaseAuth(uid: 'u2'),
        db: _FakeFirebaseFirestore.missingUser(),
        cache: cache,
      );

      await expectLater(
        repo.watch().first.timeout(const Duration(seconds: 1)),
        completion(isNull),
      );
      expect(await repo.load(), isNull);
    },
  );

  test('firestore watch follows auth state after later sign-in', () async {
    final cache = LocalCache();
    final auth = _FakeFirebaseAuth();
    final document = _FakeDocumentReference();
    final repo = FirestoreUserRepository(
      auth: auth,
      db: _FakeFirebaseFirestore(document: document),
      cache: cache,
    );
    final events = <UserSnapshot?>[];

    final subscription = repo.watch().listen(events.add);
    await Future<void>.delayed(Duration.zero);

    auth.signIn('u1');
    await Future<void>.delayed(Duration.zero);
    document.emit(seed().toMap());
    await Future<void>.delayed(Duration.zero);

    expect(events, contains(isNull));
    expect(events.whereType<UserSnapshot>().single.uid, 'u1');

    await subscription.cancel();
    auth.dispose();
    document.dispose();
  });

  test('createInitial and save update load and watch', () async {
    final repo = FakeUserRepository();
    final updated = seed().copyWith(
      time: TimeQuota(
        dailyLimitMinutes: 30,
        bonusMinutes: 10,
        usedSeconds: 12,
        usedOnDate: '2026-08-25',
      ),
    );

    expect(await repo.load(), isNull);

    final events = <int>[];
    final subscription = repo.watch().listen((snapshot) {
      if (snapshot != null) {
        events.add(snapshot.time.usedSeconds);
      }
    });

    await repo.createInitial(seed());
    await repo.save(updated);
    await Future<void>.delayed(Duration.zero);

    final loaded = await repo.load();

    expect(loaded, isNotNull);
    expect(loaded!.time.usedSeconds, 12);
    expect(loaded.time.bonusMinutes, 10);
    expect(events, [0, 12]);

    await subscription.cancel();
  });

  test('saveTimeQuota preserves wallet and daily limit fields', () async {
    final repo = FakeUserRepository(seed());

    await repo.saveTimeQuota(
      TimeQuota(
        dailyLimitMinutes: 20,
        bonusMinutes: 10,
        usedSeconds: 45,
        usedOnDate: '2026-08-26',
      ),
    );

    final loaded = await repo.load();

    expect(loaded!.child.wallet.coins, 40);
    expect(loaded.time.dailyLimitMinutes, 30);
    expect(loaded.time.bonusMinutes, 10);
    expect(loaded.time.usedSeconds, 45);
    expect(loaded.time.usedOnDate, '2026-08-26');
  });

  test('purchase deducts coins and failed purchase leaves coins', () async {
    final repo = FakeUserRepository(seed());
    final cheapItem = ShopCatalog.items.firstWhere((item) => item.price == 20);
    final expensiveItem = ShopCatalog.items.firstWhere(
      (item) => item.price == 60,
    );

    await repo.purchase(cheapItem);

    expect((await repo.load())!.child.wallet.coins, 20);

    final before = await repo.load();

    await expectLater(
      repo.purchase(expensiveItem),
      throwsA(
        isA<ShopPurchaseException>().having(
          (error) => error.errorKey,
          'errorKey',
          'insufficient_coins',
        ),
      ),
    );

    expect((await repo.load())!.child.wallet.coins, before!.child.wallet.coins);
  });

  test('purchase throws already_owned when item is already owned', () async {
    final item = ShopCatalog.items.first;
    final snapshot = seed().copyWith(
      child: ChildProfile(
        name: seed().child.name,
        avatarId: seed().child.avatarId,
        wallet: Wallet(
          coins: 40,
          ownedItemIds: {item.id},
          equipped: const Equipped(),
        ),
      ),
    );
    final repo = FakeUserRepository(snapshot);

    await expectLater(
      repo.purchase(item),
      throwsA(
        isA<ShopPurchaseException>().having(
          (error) => error.errorKey,
          'errorKey',
          'already_owned',
        ),
      ),
    );
  });

  test('purchase throws offline when fake repository is offline', () async {
    final repo = FakeUserRepository(seed(), false);

    await expectLater(
      repo.purchase(ShopCatalog.items.first),
      throwsA(
        isA<ShopPurchaseException>().having(
          (error) => error.errorKey,
          'errorKey',
          'offline',
        ),
      ),
    );
  });

  test('addPendingCoins then flushPendingCoins adds to cloud coins', () async {
    final repo = FakeUserRepository(seed());

    await repo.addPendingCoins(20);
    expect((await repo.load())!.child.wallet.coins, 60);

    await repo.flushPendingCoins();

    expect((await repo.load())!.child.wallet.coins, 60);
  });

  test(
    'save persists cloud coins without double-counting pending coins',
    () async {
      final repo = FakeUserRepository(seed());

      await repo.addPendingCoins(20);

      final loaded = await repo.load();
      expect(loaded, isNotNull);
      expect(loaded!.child.wallet.coins, 60);

      await repo.save(
        loaded.copyWith(
          time: TimeQuota(
            dailyLimitMinutes: loaded.time.dailyLimitMinutes,
            bonusMinutes: loaded.time.bonusMinutes,
            usedSeconds: loaded.time.usedSeconds + 5,
            usedOnDate: loaded.time.usedOnDate,
          ),
        ),
      );

      expect((await repo.load())!.child.wallet.coins, 60);

      await repo.flushPendingCoins();

      expect((await repo.load())!.child.wallet.coins, 60);
    },
  );
}

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth({String? uid}) : _uid = uid;

  final StreamController<User?> _controller = StreamController<User?>.broadcast(
    sync: true,
  );
  String? _uid;

  @override
  User? get currentUser => _uid == null ? null : _FakeUser(_uid!);

  @override
  Stream<User?> authStateChanges() {
    return Stream<User?>.multi((controller) {
      controller.add(currentUser);
      final subscription = _controller.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  void signIn(String uid) {
    _uid = uid;
    _controller.add(currentUser);
  }

  void dispose() {
    _controller.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseFirestore implements FirebaseFirestore {
  _FakeFirebaseFirestore({_FakeDocumentReference? document})
    : _document = document ?? _FakeDocumentReference();

  _FakeFirebaseFirestore.missingUser() : _document = _FakeDocumentReference();

  final _FakeDocumentReference _document;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _FakeCollectionReference(_document);
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

class _FakeCollectionReference
    implements CollectionReference<Map<String, dynamic>> {
  _FakeCollectionReference(this._document);

  final _FakeDocumentReference _document;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _document;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocumentReference
    implements DocumentReference<Map<String, dynamic>> {
  final StreamController<DocumentSnapshot<Map<String, dynamic>>> _controller =
      StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast(
        sync: true,
      );
  DocumentSnapshot<Map<String, dynamic>> _snapshot = _FakeDocumentSnapshot();

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    return _snapshot;
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    return Stream<DocumentSnapshot<Map<String, dynamic>>>.multi((controller) {
      controller.add(_snapshot);
      final subscription = _controller.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  void emit(Map<String, dynamic> data) {
    _snapshot = _FakeDocumentSnapshot(data: data);
    _controller.add(_snapshot);
  }

  void dispose() {
    _controller.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocumentSnapshot({Map<String, dynamic>? data}) : _data = data;

  final Map<String, dynamic>? _data;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
