import 'dart:convert';
import 'dart:math';

import 'package:english_app/domain/time/time_quota.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  static const _snapshotKey = 'snapshot_json';
  static const _uidKey = 'snapshot_uid';
  static const _pendingRewardKey = 'pending_reward';
  static const _usedSecondsKey = 'used_seconds';

  Future<void> saveSnapshot(UserSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uidKey, snapshot.uid);
    await prefs.setString(_snapshotKey, jsonEncode(snapshot.toMap()));
  }

  Future<UserSnapshot?> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_uidKey);
    final rawSnapshot = prefs.getString(_snapshotKey);

    if (uid == null || rawSnapshot == null) {
      return null;
    }

    final snapshot = UserSnapshot.fromMap(
      uid,
      jsonDecode(rawSnapshot) as Map<String, dynamic>,
    );
    final storedUsedSeconds = await loadUsedSeconds();

    if (storedUsedSeconds == null) {
      return snapshot;
    }

    return snapshot.copyWith(
      time: TimeQuota(
        dailyLimitMinutes: snapshot.time.dailyLimitMinutes,
        bonusMinutes: snapshot.time.bonusMinutes,
        usedSeconds: max(snapshot.time.usedSeconds, storedUsedSeconds),
        usedOnDate: snapshot.time.usedOnDate,
      ),
    );
  }

  Future<void> savePendingReward(int coins) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pendingRewardKey, coins);
  }

  Future<int> loadPendingReward() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pendingRewardKey) ?? 0;
  }

  Future<void> saveUsedSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_usedSecondsKey, seconds);
  }

  Future<int?> loadUsedSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_usedSecondsKey);
  }
}
