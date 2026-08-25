import 'package:english_app/data/local_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/seed.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saveSnapshot and loadSnapshot round-trip seed user', () async {
    final cache = LocalCache();

    await cache.saveSnapshot(seed());
    await cache.savePendingReward(20);

    final loaded = await cache.loadSnapshot();

    expect(loaded, isNotNull);
    expect(loaded!.child.name, '豆豆');
    expect(await cache.loadPendingReward(), 20);
  });

  test('loadSnapshot restores higher persisted used seconds', () async {
    final cache = LocalCache();
    final snapshot = seed();

    await cache.saveSnapshot(snapshot);
    await cache.saveUsedSeconds(80);

    final loaded = await cache.loadSnapshot();

    expect(loaded, isNotNull);
    expect(loaded!.time.usedSeconds, 80);
  });

  test('saveUsedSeconds persists foreground seconds', () async {
    final cache = LocalCache();

    await cache.saveUsedSeconds(123);

    expect(await cache.loadUsedSeconds(), 123);
  });
}
