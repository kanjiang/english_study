// ignore_for_file: subtype_of_sealed_class

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

  test('watch and load ignore cached snapshot for a different signed-in uid', () async {
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

  test('save persists cloud coins without double-counting pending coins', () async {
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

class _FakeFirebaseFirestore implements FirebaseFirestore {
  _FakeFirebaseFirestore();

  _FakeFirebaseFirestore.missingUser();

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _FakeCollectionReference();
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
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _FakeDocumentReference();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocumentReference
    implements DocumentReference<Map<String, dynamic>> {
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    return _FakeDocumentSnapshot();
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    return Stream.value(_FakeDocumentSnapshot());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  bool get exists => false;

  @override
  Map<String, dynamic>? data() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
