import 'package:english_app/domain/time/time_quota.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TimeQuota q({
    int limit = 30,
    int bonus = 0,
    int used = 0,
    String date = '2026-08-25',
  }) =>
      TimeQuota(
        dailyLimitMinutes: limit,
        bonusMinutes: bonus,
        usedSeconds: used,
        usedOnDate: date,
      );

  test('default 30 minutes is 1800 seconds capacity', () {
    expect(q().remainingSeconds, 1800);
    expect(q().isLocked, isFalse);
    expect(q().remainingMinutesDisplay, 30);
  });

  test('locks when usedSeconds reaches capacity', () {
    expect(q(used: 1800).isLocked, isTrue);
    expect(q(used: 1800).remainingSeconds, 0);
    expect(q(used: 1800).remainingMinutesDisplay, 0);
  });

  test('display minutes uses ceil of remaining seconds', () {
    expect(q(used: 1800 - 1).remainingMinutesDisplay, 1);
    expect(q(used: 1800 - 61).remainingMinutesDisplay, 2);
  });

  test('tick accumulates foreground seconds', () {
    final next = q(used: 10).tick(deltaSeconds: 5, todayYyyyMmDd: '2026-08-25');
    expect(next.usedSeconds, 15);
  });

  test('new calendar day resets usedSeconds and bonusMinutes', () {
    final next = q(bonus: 10, used: 100).tick(
      deltaSeconds: 3,
      todayYyyyMmDd: '2026-08-26',
    );
    expect(next.usedOnDate, '2026-08-26');
    expect(next.usedSeconds, 3);
    expect(next.bonusMinutes, 0);
  });

  test('addBonusMinutes adds 10 and can be called twice', () {
    final next = q().addBonusMinutes().addBonusMinutes();
    expect(next.bonusMinutes, 20);
    expect(next.remainingSeconds, 1800 + 1200);
  });

  test('setDailyLimitMinutes only allows 20/30/45/60', () {
    expect(q().setDailyLimitMinutes(20).dailyLimitMinutes, 20);
    expect(() => q().setDailyLimitMinutes(15), throwsArgumentError);
  });

  test('reducing limit below used locks', () {
    final next = q(limit: 60, used: 30 * 60).setDailyLimitMinutes(20);
    expect(next.isLocked, isTrue);
  });
}
