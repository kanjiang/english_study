import 'package:timezone/timezone.dart' as tz;

class ShanghaiClock {
  const ShanghaiClock();

  tz.TZDateTime now() => tz.TZDateTime.now(tz.getLocation('Asia/Shanghai'));

  String shanghaiDateString(DateTime utcOrLocalConverted) {
    final n = tz.TZDateTime.from(
      utcOrLocalConverted,
      tz.getLocation('Asia/Shanghai'),
    );
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  String todayYyyyMmDd() {
    final n = now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }
}
