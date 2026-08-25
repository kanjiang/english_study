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
