import 'package:english_app/domain/time/time_quota.dart';
import 'package:english_app/domain/wallet/wallet.dart';

class GameStats {
  const GameStats({
    this.treasureLastScore = 0,
    this.firefighterLastScore = 0,
    this.monsterLastScore = 0,
  });

  final int treasureLastScore;
  final int firefighterLastScore;
  final int monsterLastScore;

  GameStats copyWith({
    int? treasureLastScore,
    int? firefighterLastScore,
    int? monsterLastScore,
  }) {
    return GameStats(
      treasureLastScore: treasureLastScore ?? this.treasureLastScore,
      firefighterLastScore: firefighterLastScore ?? this.firefighterLastScore,
      monsterLastScore: monsterLastScore ?? this.monsterLastScore,
    );
  }
}

class ChildProfile {
  const ChildProfile({
    required this.name,
    required this.avatarId,
    required this.wallet,
  });

  final String name;
  final String avatarId;
  final Wallet wallet;
}

class UserSnapshot {
  const UserSnapshot({
    required this.uid,
    required this.parentPinHash,
    required this.child,
    required this.time,
    this.email,
    this.phone,
    this.gameStats = const GameStats(),
  });

  static const avatarIds = ['avatar_1', 'avatar_2', 'avatar_3', 'avatar_4'];

  final String uid;
  final String? email;
  final String? phone;
  final String parentPinHash;
  final ChildProfile child;
  final TimeQuota time;
  final GameStats gameStats;

  UserSnapshot copyWith({
    String? parentPinHash,
    ChildProfile? child,
    TimeQuota? time,
    GameStats? gameStats,
    String? email,
    String? phone,
  }) {
    return UserSnapshot(
      uid: uid,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      parentPinHash: parentPinHash ?? this.parentPinHash,
      child: child ?? this.child,
      time: time ?? this.time,
      gameStats: gameStats ?? this.gameStats,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phone': phone,
      'parentPinHash': parentPinHash,
      'child': {
        'name': child.name,
        'avatarId': child.avatarId,
        'coins': child.wallet.coins,
        'ownedItemIds': child.wallet.ownedItemIds.toList(),
        'equipped': {
          'hat': child.wallet.equipped.hat,
          'glasses': child.wallet.equipped.glasses,
          'clothes': child.wallet.equipped.clothes,
        },
      },
      'time': {
        'dailyLimitMinutes': time.dailyLimitMinutes,
        'bonusMinutes': time.bonusMinutes,
        'usedSeconds': time.usedSeconds,
        'usedOnDate': time.usedOnDate,
      },
      'gameStats': {
        'treasureLastScore': gameStats.treasureLastScore,
        'firefighterLastScore': gameStats.firefighterLastScore,
        'monsterLastScore': gameStats.monsterLastScore,
      },
    };
  }

  factory UserSnapshot.fromMap(String uid, Map<String, dynamic> map) {
    final childMap = map['child'] as Map<String, dynamic>;
    final equippedMap = childMap['equipped'] as Map<String, dynamic>;
    final timeMap = map['time'] as Map<String, dynamic>;
    final gameStatsMap = map['gameStats'] as Map<String, dynamic>? ?? {};

    return UserSnapshot(
      uid: uid,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      parentPinHash: map['parentPinHash'] as String,
      child: ChildProfile(
        name: childMap['name'] as String,
        avatarId: childMap['avatarId'] as String,
        wallet: Wallet(
          coins: childMap['coins'] as int,
          ownedItemIds: {...(childMap['ownedItemIds'] as List).cast<String>()},
          equipped: Equipped(
            hat: equippedMap['hat'] as String?,
            glasses: equippedMap['glasses'] as String?,
            clothes: equippedMap['clothes'] as String?,
          ),
        ),
      ),
      time: TimeQuota(
        dailyLimitMinutes: timeMap['dailyLimitMinutes'] as int,
        bonusMinutes: timeMap['bonusMinutes'] as int,
        usedSeconds: timeMap['usedSeconds'] as int,
        usedOnDate: timeMap['usedOnDate'] as String,
      ),
      gameStats: GameStats(
        treasureLastScore: gameStatsMap['treasureLastScore'] as int? ?? 0,
        firefighterLastScore: gameStatsMap['firefighterLastScore'] as int? ?? 0,
        monsterLastScore: gameStatsMap['monsterLastScore'] as int? ?? 0,
      ),
    );
  }
}
