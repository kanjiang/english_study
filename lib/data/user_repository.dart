import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_app/data/local_cache.dart';
import 'package:english_app/domain/shanghai_clock.dart';
import 'package:english_app/domain/user/sync_merge.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/domain/wallet/wallet.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class UserRepository {
  Stream<UserSnapshot?> watch();

  Future<UserSnapshot?> load();

  Future<void> createInitial(UserSnapshot snapshot);

  Future<void> save(UserSnapshot snapshot);

  Future<void> purchase(ShopItem item);

  Future<void> addPendingCoins(int coins);

  Future<void> flushPendingCoins();
}

class ShopPurchaseException implements Exception {
  const ShopPurchaseException(this.errorKey);

  final String errorKey;

  @override
  String toString() => 'ShopPurchaseException($errorKey)';
}

UserSnapshot _copySnapshotWithCoins(UserSnapshot snapshot, int coins) {
  return snapshot.copyWith(
    child: ChildProfile(
      name: snapshot.child.name,
      avatarId: snapshot.child.avatarId,
      wallet: Wallet(
        coins: coins,
        ownedItemIds: snapshot.child.wallet.ownedItemIds,
        equipped: snapshot.child.wallet.equipped,
      ),
    ),
  );
}

UserSnapshot _mergePendingIntoSnapshot(UserSnapshot snapshot, int pendingCoins) {
  final mergedCoins = mergeCoins(
    cloudCoins: snapshot.child.wallet.coins,
    pendingLegalReward: pendingCoins,
  );
  return _copySnapshotWithCoins(snapshot, mergedCoins);
}

UserSnapshot _stripPendingFromSnapshot(UserSnapshot snapshot, int pendingCoins) {
  final pending = pendingCoins < 0 ? 0 : pendingCoins;
  final cloudCoins = snapshot.child.wallet.coins - pending;
  return _copySnapshotWithCoins(snapshot, cloudCoins < 0 ? 0 : cloudCoins);
}

class FakeUserRepository implements UserRepository {
  FakeUserRepository([UserSnapshot? initialSnapshot, this.online = true])
    : _snapshot = initialSnapshot;

  FakeUserRepository.empty([this.online = true]) : _snapshot = null;

  final bool online;
  final StreamController<UserSnapshot?> _controller =
      StreamController<UserSnapshot?>.broadcast(sync: true);

  UserSnapshot? _snapshot;
  int _pendingCoins = 0;

  @override
  Stream<UserSnapshot?> watch() {
    return Stream<UserSnapshot?>.multi((controller) {
      controller.add(_visibleSnapshot(_snapshot));
      final subscription = _controller.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<UserSnapshot?> load() async => _visibleSnapshot(_snapshot);

  @override
  Future<void> createInitial(UserSnapshot snapshot) async {
    _snapshot = snapshot;
    _controller.add(_visibleSnapshot(_snapshot));
  }

  @override
  Future<void> save(UserSnapshot snapshot) async {
    _snapshot = _stripPendingFromSnapshot(snapshot, _pendingCoins);
    _controller.add(_visibleSnapshot(_snapshot));
  }

  @override
  Future<void> purchase(ShopItem item) async {
    final snapshot = _requireSnapshot();
    final result = snapshot.child.wallet.buy(item, online: online);

    if (!result.ok) {
      throw ShopPurchaseException(result.errorKey ?? 'unknown');
    }

    _snapshot = snapshot.copyWith(
      child: ChildProfile(
        name: snapshot.child.name,
        avatarId: snapshot.child.avatarId,
        wallet: result.wallet,
      ),
    );
    _controller.add(_visibleSnapshot(_snapshot));
  }

  @override
  Future<void> addPendingCoins(int coins) async {
    if (coins <= 0) {
      return;
    }
    _pendingCoins += coins;
  }

  @override
  Future<void> flushPendingCoins() async {
    final snapshot = _requireSnapshot();
    final pendingCoins = _pendingCoins < 0 ? 0 : _pendingCoins;

    _pendingCoins = 0;
    _snapshot = _copySnapshotWithCoins(
      snapshot,
      snapshot.child.wallet.coins + pendingCoins,
    );
    _controller.add(_visibleSnapshot(_snapshot));
  }

  UserSnapshot _requireSnapshot() {
    final snapshot = _snapshot;
    if (snapshot == null) {
      throw StateError('missing_snapshot');
    }
    return snapshot;
  }

  UserSnapshot? _visibleSnapshot(UserSnapshot? snapshot) {
    if (snapshot == null) {
      return null;
    }
    return _mergePendingIntoSnapshot(snapshot, _pendingCoins);
  }
}

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore db,
    required LocalCache cache,
    ShanghaiClock clock = const ShanghaiClock(),
  }) : _auth = auth,
       _db = db,
       _cache = cache,
       _clock = clock;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final LocalCache _cache;
  final ShanghaiClock _clock;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _uid;
    if (uid == null) {
      return null;
    }
    return _db.collection('users').doc(uid);
  }

  @override
  Stream<UserSnapshot?> watch() {
    final uid = _uid;
    final doc = _userDoc;

    if (uid == null || doc == null) {
      return Stream<UserSnapshot?>.value(null);
    }

    return doc.snapshots().asyncMap((snapshot) async {
      if (!snapshot.exists) {
        return _loadDisplayedLocalSnapshotForUid(uid);
      }

      final data = snapshot.data();
      if (data == null) {
        return _loadDisplayedLocalSnapshotForUid(uid);
      }

      final merged = await _mergeRemoteSnapshot(
        UserSnapshot.fromMap(uid, data),
      );
      await _persistLocalDisplayedSnapshot(merged);
      return merged;
    });
  }

  @override
  Future<UserSnapshot?> load() async {
    final uid = _uid;
    final doc = _userDoc;

    if (uid == null || doc == null) {
      return _loadDisplayedLocalSnapshotForUid(uid);
    }

    try {
      final snapshot = await doc.get();
      if (!snapshot.exists) {
        return _loadDisplayedLocalSnapshotForUid(uid);
      }

      final data = snapshot.data();
      if (data == null) {
        return _loadDisplayedLocalSnapshotForUid(uid);
      }

      final merged = await _mergeRemoteSnapshot(
        UserSnapshot.fromMap(uid, data),
      );
      await _persistLocalDisplayedSnapshot(merged);
      return merged;
    } catch (_) {
      return _loadDisplayedLocalSnapshotForUid(uid);
    }
  }

  @override
  Future<void> createInitial(UserSnapshot snapshot) async {
    await _persistLocalCloudSnapshot(snapshot);

    final doc = _userDoc;
    if (doc == null) {
      return;
    }

    try {
      await doc.set(snapshot.toMap());
    } catch (_) {
      await _cache.saveUsedSeconds(snapshot.time.usedSeconds);
    }
  }

  @override
  Future<void> save(UserSnapshot snapshot) async {
    final pendingCoins = await _cache.loadPendingReward();
    final cloudSnapshot = _stripPendingFromSnapshot(snapshot, pendingCoins);
    await _persistLocalCloudSnapshot(cloudSnapshot);

    final doc = _userDoc;
    if (doc == null) {
      return;
    }

    try {
      await doc.set(cloudSnapshot.toMap());
    } catch (_) {
      await _cache.saveUsedSeconds(snapshot.time.usedSeconds);
    }
  }

  @override
  Future<void> purchase(ShopItem item) async {
    final uid = _uid;
    final doc = _userDoc;

    if (uid == null || doc == null) {
      throw const ShopPurchaseException('not_authenticated');
    }

    UserSnapshot? updated;
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(doc);
        final data = snapshot.data();

        if (!snapshot.exists || data == null) {
          throw const ShopPurchaseException('not_found');
        }

        final current = UserSnapshot.fromMap(uid, data);
        final result = current.child.wallet.buy(item, online: true);

        if (!result.ok) {
          throw ShopPurchaseException(result.errorKey ?? 'unknown');
        }

        updated = current.copyWith(
          child: ChildProfile(
            name: current.child.name,
            avatarId: current.child.avatarId,
            wallet: result.wallet,
          ),
        );
        transaction.set(doc, updated!.toMap());
      });
    } on ShopPurchaseException {
      rethrow;
    } catch (_) {
      throw const ShopPurchaseException('unknown');
    }

    if (updated != null) {
      await _persistLocalCloudSnapshot(updated!);
    }
  }

  @override
  Future<void> addPendingCoins(int coins) async {
    if (coins <= 0) {
      return;
    }

    final current = await _cache.loadPendingReward();
    await _cache.savePendingReward(current + coins);
  }

  @override
  Future<void> flushPendingCoins() async {
    final pendingCoins = await _cache.loadPendingReward();
    if (pendingCoins <= 0) {
      return;
    }

    final uid = _uid;
    final doc = _userDoc;

    if (uid == null || doc == null) {
      return;
    }

    UserSnapshot? updated;
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(doc);
        final data = snapshot.data();

        if (!snapshot.exists || data == null) {
          return;
        }

        final current = UserSnapshot.fromMap(uid, data);
        final mergedCoins = mergeCoins(
          cloudCoins: current.child.wallet.coins,
          pendingLegalReward: pendingCoins,
        );
        updated = current.copyWith(
          child: ChildProfile(
            name: current.child.name,
            avatarId: current.child.avatarId,
            wallet: current.child.wallet.addCoins(
              mergedCoins - current.child.wallet.coins,
            ),
          ),
        );
        transaction.set(doc, updated!.toMap());
      });
    } catch (_) {
      return;
    }

    if (updated != null) {
      await _cache.savePendingReward(0);
      await _persistLocalCloudSnapshot(updated!);
    }
  }

  Future<UserSnapshot> _mergeRemoteSnapshot(UserSnapshot remote) async {
    final local = await _loadLocalSnapshotForUid(remote.uid);
    final pendingCoins = await _cache.loadPendingReward();
    final mergedTime = local == null
        ? remote.time
        : mergeTimeQuota(
            local: local.time,
            remote: remote.time,
            todayYyyyMmDd: _clock.todayYyyyMmDd(),
          );
    final mergedCoins = mergeCoins(
      cloudCoins: remote.child.wallet.coins,
      pendingLegalReward: pendingCoins,
    );

    return remote.copyWith(
      child: ChildProfile(
        name: remote.child.name,
        avatarId: remote.child.avatarId,
        wallet: Wallet(
          coins: mergedCoins,
          ownedItemIds: remote.child.wallet.ownedItemIds,
          equipped: remote.child.wallet.equipped,
        ),
      ),
      time: mergedTime,
    );
  }

  Future<UserSnapshot?> _loadDisplayedLocalSnapshotForUid(String? uid) async {
    if (uid == null) {
      return null;
    }

    final local = await _loadLocalSnapshotForUid(uid);
    if (local == null) {
      return null;
    }

    final pendingCoins = await _cache.loadPendingReward();
    return _mergePendingIntoSnapshot(local, pendingCoins);
  }

  Future<UserSnapshot?> _loadLocalSnapshotForUid(String uid) async {
    final local = await _cache.loadSnapshot();
    if (local == null || local.uid != uid) {
      return null;
    }
    return local;
  }

  Future<void> _persistLocalDisplayedSnapshot(UserSnapshot snapshot) async {
    final pendingCoins = await _cache.loadPendingReward();
    await _persistLocalCloudSnapshot(
      _stripPendingFromSnapshot(snapshot, pendingCoins),
    );
  }

  Future<void> _persistLocalCloudSnapshot(UserSnapshot snapshot) async {
    await _cache.saveSnapshot(snapshot);
    await _cache.saveUsedSeconds(snapshot.time.usedSeconds);
  }
}
