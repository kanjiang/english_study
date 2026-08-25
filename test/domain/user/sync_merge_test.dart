import 'package:english_app/domain/time/time_quota.dart';
import 'package:english_app/domain/user/sync_merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merge coins cloud 100 + pending 20 = 120', () {
    expect(mergeCoins(cloudCoins: 100, pendingLegalReward: 20), 120);
  });

  test('same day usedSeconds takes max', () {
    final local = TimeQuota(
      dailyLimitMinutes: 30,
      bonusMinutes: 0,
      usedSeconds: 80,
      usedOnDate: '2026-08-25',
    );
    final remote = TimeQuota(
      dailyLimitMinutes: 20,
      bonusMinutes: 10,
      usedSeconds: 50,
      usedOnDate: '2026-08-25',
    );

    final merged = mergeTimeQuota(
      local: local,
      remote: remote,
      todayYyyyMmDd: '2026-08-25',
    );

    expect(merged.usedSeconds, 80);
    expect(merged.dailyLimitMinutes, 20);
    expect(merged.bonusMinutes, 10);
  });

  test('new day resets both before merge', () {
    final local = TimeQuota(
      dailyLimitMinutes: 30,
      bonusMinutes: 10,
      usedSeconds: 80,
      usedOnDate: '2026-08-24',
    );
    final remote = TimeQuota(
      dailyLimitMinutes: 30,
      bonusMinutes: 0,
      usedSeconds: 999,
      usedOnDate: '2026-08-24',
    );

    final merged = mergeTimeQuota(
      local: local,
      remote: remote,
      todayYyyyMmDd: '2026-08-25',
    );

    expect(merged.usedSeconds, 0);
    expect(merged.bonusMinutes, 0);
    expect(merged.usedOnDate, '2026-08-25');
  });
}
