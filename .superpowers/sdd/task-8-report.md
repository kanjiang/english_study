# Task 8 Report: 孩子首页、前台计时、时长锁

## Status

Completed.

## What Changed

- Added `ChildHomePage` with child avatar, coin balance, remaining time, game entries, and placeholder navigation for games, shop, and parent entry.
- Added `TimeLockPage` with exact required lock copy and wired `AuthGate` to overlay it for locked snapshots.
- Added `KidAvatar` equipment overlays for hat, glasses, and clothes.
- Added app-level `ForegroundTicker` that ticks foreground time while resumed, pauses on lifecycle stop states, saves on stop, saves every 30 seconds, and saves immediately on lock.
- Updated onboarding navigation to the new `ChildHomePage(snapshot: ...)` contract.

## TDD Evidence

- Red: `flutter test test/widget/time_lock_test.dart` failed because lock copy and remaining-time/game UI were missing.
- Green: `flutter test test/widget/time_lock_test.dart` passed after implementation.
- Full verification: `flutter test` passed.

## Notes

- Locked widget test seeds `usedOnDate` with `ShanghaiClock().todayYyyyMmDd()` after timezone initialization so the locked snapshot stays locked.
- `ChildHomePage` hides game buttons while locked so lock assertions do not find game text underneath the overlay.

## Review Follow-up

- Removed onboarding's direct `pushReplacement` to `ChildHomePage`; after `createInitial`, the screen now finishes with `Navigator.maybePop()` so first-run users stay under `ForegroundTicker(child: AuthGate())` and `AuthGate` can rebuild from `watch()`.
- Added a visible `家长` button to `TimeLockPage` that opens the same placeholder parent route as the home page while keeping games blocked behind the lock state.
- Added a widget regression test that proves onboarding returns to its caller after profile creation, and updated the lock-page widget test to assert the exact copy plus the visible parent button while still ensuring `寻宝翻牌` is not available.

## Verification Follow-up

- Red: `flutter test test/widget/time_lock_test.dart test/widget/auth_gate_test.dart` initially failed on the new onboarding regression test and then on test harness gaps around Firebase/timezone setup and the lock-page selector.
- Green: `flutter test test/widget/time_lock_test.dart test/widget/auth_gate_test.dart` passed after the onboarding and lock-page fixes plus the test updates.
- Full verification: `flutter test` passed.
