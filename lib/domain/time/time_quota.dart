class TimeQuota {
  static const allowedDailyLimitMinutes = [20, 30, 45, 60];
  static const defaultDailyLimitMinutes = 30;
  static const bonusStepMinutes = 10;

  TimeQuota({
    required int dailyLimitMinutes,
    required this.bonusMinutes,
    required this.usedSeconds,
    required this.usedOnDate,
  }) : dailyLimitMinutes = _validateDailyLimitMinutes(dailyLimitMinutes);

  final int dailyLimitMinutes;
  final int bonusMinutes;
  final int usedSeconds;
  final String usedOnDate;

  static int _validateDailyLimitMinutes(int minutes) {
    if (!allowedDailyLimitMinutes.contains(minutes)) {
      throw ArgumentError.value(minutes, 'dailyLimitMinutes');
    }
    return minutes;
  }

  int get _capacitySeconds => (dailyLimitMinutes + bonusMinutes) * 60;

  int get remainingSeconds {
    final rem = _capacitySeconds - usedSeconds;
    return rem < 0 ? 0 : rem;
  }

  int get remainingMinutesDisplay {
    if (remainingSeconds == 0) return 0;
    return (remainingSeconds + 59) ~/ 60;
  }

  bool get isLocked => remainingSeconds <= 0;

  TimeQuota rollTo(String todayYyyyMmDd) {
    if (todayYyyyMmDd == usedOnDate) return this;
    return TimeQuota(
      dailyLimitMinutes: dailyLimitMinutes,
      bonusMinutes: 0,
      usedSeconds: 0,
      usedOnDate: todayYyyyMmDd,
    );
  }

  TimeQuota tick({required int deltaSeconds, required String todayYyyyMmDd}) {
    final rolled = rollTo(todayYyyyMmDd);
    final delta = deltaSeconds < 0 ? 0 : deltaSeconds;
    return TimeQuota(
      dailyLimitMinutes: rolled.dailyLimitMinutes,
      bonusMinutes: rolled.bonusMinutes,
      usedSeconds: rolled.usedSeconds + delta,
      usedOnDate: rolled.usedOnDate,
    );
  }

  TimeQuota addBonusMinutes() {
    return TimeQuota(
      dailyLimitMinutes: dailyLimitMinutes,
      bonusMinutes: bonusMinutes + bonusStepMinutes,
      usedSeconds: usedSeconds,
      usedOnDate: usedOnDate,
    );
  }

  TimeQuota setDailyLimitMinutes(int minutes) {
    if (!allowedDailyLimitMinutes.contains(minutes)) {
      throw ArgumentError.value(minutes, 'minutes');
    }
    return TimeQuota(
      dailyLimitMinutes: minutes,
      bonusMinutes: bonusMinutes,
      usedSeconds: usedSeconds,
      usedOnDate: usedOnDate,
    );
  }
}
