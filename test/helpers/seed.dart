import 'package:english_app/domain/time/time_quota.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/domain/wallet/wallet.dart';

UserSnapshot seed() => UserSnapshot(
  uid: 'u1',
  parentPinHash: 'abc',
  child: ChildProfile(
    name: '豆豆',
    avatarId: 'avatar_1',
    wallet: Wallet(coins: 40, ownedItemIds: {}, equipped: const Equipped()),
  ),
  time: TimeQuota(
    dailyLimitMinutes: 30,
    bonusMinutes: 0,
    usedSeconds: 0,
    usedOnDate: '2026-08-25',
  ),
);
