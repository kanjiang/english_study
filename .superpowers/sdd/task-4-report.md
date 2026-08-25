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
