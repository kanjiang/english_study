import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromMap uses TimeQuota constructor validation', () {
    expect(
      () => UserSnapshot.fromMap('u1', {
        'parentPinHash': 'abc',
        'child': {
          'name': '豆豆',
          'avatarId': 'avatar_1',
          'coins': 40,
          'ownedItemIds': <String>[],
          'equipped': {'hat': null, 'glasses': null, 'clothes': null},
        },
        'time': {
          'dailyLimitMinutes': 15,
          'bonusMinutes': 0,
          'usedSeconds': 0,
          'usedOnDate': '2026-08-25',
        },
      }),
      throwsArgumentError,
    );
  });

  test('fromMap builds wallet through constructor isolation', () {
    final snapshot = UserSnapshot.fromMap('u1', {
      'parentPinHash': 'abc',
      'child': {
        'name': '豆豆',
        'avatarId': 'avatar_1',
        'coins': 40,
        'ownedItemIds': <String>['hat_20'],
        'equipped': {'hat': 'hat_20', 'glasses': null, 'clothes': null},
      },
      'time': {
        'dailyLimitMinutes': 30,
        'bonusMinutes': 0,
        'usedSeconds': 0,
        'usedOnDate': '2026-08-25',
      },
    });

    expect(
      () => snapshot.child.wallet.ownedItemIds.add('glasses_20'),
      throwsUnsupportedError,
    );
  });
}
