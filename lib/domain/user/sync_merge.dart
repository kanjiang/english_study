import 'package:english_app/domain/time/time_quota.dart';

int mergeCoins({required int cloudCoins, required int pendingLegalReward}) {
  final pending = pendingLegalReward < 0 ? 0 : pendingLegalReward;
  return cloudCoins + pending;
}

TimeQuota mergeTimeQuota({
  required TimeQuota local,
  required TimeQuota remote,
  required String todayYyyyMmDd,
}) {
  final rolledLocal = local.rollTo(todayYyyyMmDd);
  final rolledRemote = remote.rollTo(todayYyyyMmDd);

  return TimeQuota(
    dailyLimitMinutes: rolledRemote.dailyLimitMinutes,
    bonusMinutes: rolledLocal.bonusMinutes > rolledRemote.bonusMinutes
        ? rolledLocal.bonusMinutes
        : rolledRemote.bonusMinutes,
    usedSeconds: rolledLocal.usedSeconds > rolledRemote.usedSeconds
        ? rolledLocal.usedSeconds
        : rolledRemote.usedSeconds,
    usedOnDate: todayYyyyMmDd,
  );
}
