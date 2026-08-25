import 'dart:async';

import 'package:english_app/app/providers.dart';
import 'package:english_app/domain/shanghai_clock.dart';
import 'package:english_app/domain/user/sync_merge.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ForegroundTicker extends ConsumerStatefulWidget {
  const ForegroundTicker({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ForegroundTicker> createState() => _ForegroundTickerState();
}

class _ForegroundTickerState extends ConsumerState<ForegroundTicker>
    with WidgetsBindingObserver {
  static const _saveEverySeconds = 30;

  final ShanghaiClock _clock = const ShanghaiClock();

  StreamSubscription<UserSnapshot?>? _subscription;
  Timer? _timer;
  UserSnapshot? _snapshot;
  int _secondsSinceSave = 0;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribe();
    if (_isResumed) {
      _startTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startTimer();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _stopTimer(save: true);
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  bool get _isResumed {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  void _subscribe() {
    final repository = ref.read(userRepositoryProvider);
    _subscription = repository.watch().listen((snapshot) {
      final next = _mergeRemoteSnapshot(snapshot);
      _publish(next);
      if (next == null || next.time.isLocked) {
        _stopTimer(save: false);
        return;
      }
      if (_isResumed) {
        _startTimer();
      }
    });
  }

  void _startTimer() {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.time.isLocked || _timer != null) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTimer({required bool save}) {
    _timer?.cancel();
    _timer = null;
    if (save) {
      unawaited(_saveIfDirty());
    }
  }

  void _tick() {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.time.isLocked) {
      _stopTimer(save: false);
      return;
    }

    final nextTime = snapshot.time.tick(
      deltaSeconds: 1,
      todayYyyyMmDd: _clock.todayYyyyMmDd(),
    );
    final next = snapshot.copyWith(time: nextTime);
    _publish(next);
    _dirty = true;
    _secondsSinceSave += 1;

    if (nextTime.isLocked) {
      _stopTimer(save: true);
      return;
    }

    if (_secondsSinceSave >= _saveEverySeconds) {
      unawaited(_saveIfDirty());
    }
  }

  Future<void> _saveIfDirty() async {
    if (_saving || !_dirty) {
      return;
    }
    final snapshot = _snapshot;
    if (snapshot == null) {
      return;
    }

    _saving = true;
    try {
      await ref.read(userRepositoryProvider).save(snapshot);
      final current = _snapshot;
      final savedTime = snapshot.time;
      final currentTime = current?.time;
      if (currentTime?.usedOnDate == savedTime.usedOnDate &&
          currentTime?.usedSeconds == savedTime.usedSeconds) {
        _dirty = false;
        _secondsSinceSave = 0;
      }
    } catch (_) {
      // Keep the dirty snapshot in memory; the next interval/lifecycle save retries.
    } finally {
      _saving = false;
    }
  }

  UserSnapshot? _mergeRemoteSnapshot(UserSnapshot? remote) {
    if (remote == null) {
      return null;
    }

    final local = _snapshot;
    if (local == null || local.uid != remote.uid) {
      return remote;
    }

    return remote.copyWith(
      time: mergeTimeQuota(
        local: local.time,
        remote: remote.time,
        todayYyyyMmDd: _clock.todayYyyyMmDd(),
      ),
    );
  }

  void _publish(UserSnapshot? snapshot) {
    _snapshot = snapshot;
    ref.read(foregroundUserSnapshotProvider.notifier).state = snapshot;
  }
}
