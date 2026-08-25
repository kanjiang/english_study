# Task 4 Report

## RED
- Added `test/domain/wallet/wallet_test.dart` first, covering the 9-item catalog, buying rules, and equip/unequip behavior.
- Ran `flutter test test/domain/wallet/wallet_test.dart` and confirmed the expected failure: `lib/domain/wallet/wallet.dart` did not exist.

## GREEN
- Implemented `lib/domain/wallet/wallet.dart` with `ShopSlot`, `ShopItem`, `ShopCatalog`, `Equipped`, `Wallet`, and `WalletBuyResult`.
- Kept `Equipped.withSlot` exhaustive over `ShopSlot` with no `default` branch.
- Re-ran `flutter test test/domain/wallet/wallet_test.dart` and it passed.

## Verification
- Ran full `flutter test`.
- Result: all tests passed.

## Concerns
- None at the moment.

## Task 4 Update
- Fixed `Wallet.ownedItemIds` so it no longer aliases caller-owned or sibling-owned mutable sets.
- `Wallet` now copies incoming item ids into a private backing set and exposes an unmodifiable view.
- `addCoins`, `equip`, and `unequip` now forward the private backing set so each `Wallet` stays isolated.
- Added regression tests for constructor isolation and copy isolation.

## Verification Output
```text
$ flutter test test/domain/wallet/wallet_test.dart
00:00 +9: All tests passed!
```

```text
$ flutter test
00:03 +28: All tests passed!
```
