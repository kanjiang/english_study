# Word Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 48 word-bank placeholder icons and shared beep audio with per-word image and speech assets.

**Architecture:** Keep word metadata in the existing `Word` and `kWordBank` flow. Move from Material icon code points to asset paths, and let game widgets render `Image.asset` through one helper.

**Tech Stack:** Flutter, Riverpod, `just_audio`, Windows `System.Speech` for MVP WAV generation, local generated PNG flashcard assets for the first MVP pass.

## Global Constraints

- UI remains Simplified Chinese; game content remains English.
- Android package remains `com.xiaocixing.english_app`; iOS bundle remains `com.xiaocixing.englishApp`.
- The word bank remains 48 words, 4 categories, 12 words per category.
- Images use `assets/images/words/<word_id>.png`.
- Audio uses `assets/audio/words/<word_id>.wav`.
- No inline imports.

---

### Task 1: Word Asset Metadata

**Files:**
- Modify: `lib/domain/quiz/word.dart`
- Modify: `lib/data/word_bank.dart`
- Modify: `test/data/word_bank_test.dart`
- Modify: `pubspec.yaml`

**Interfaces:**
- Consumes: `Word.id`, `Word.en`, `Word.zh`, `Word.category`, `Word.audioAsset`.
- Produces: `Word.imageAsset`.

- [x] **Step 1: Write failing tests**

Update `test/data/word_bank_test.dart` to assert unique `imageAsset` and `audioAsset` paths, no `beep.mp3`, and path names derived from `word.id`.

- [x] **Step 2: Run test to verify failure**

Run: `flutter test test/data/word_bank_test.dart`
Expected: fail because `Word.imageAsset` does not exist and all audio still points at `beep.mp3`.

- [x] **Step 3: Implement metadata**

Change `Word` to require `imageAsset`; update every `Word` entry with:

```dart
imageAsset: 'assets/images/words/<word_id>.png',
audioAsset: 'assets/audio/words/<word_id>.wav',
```

Update `pubspec.yaml` to include:

```yaml
assets:
  - assets/audio/
  - assets/audio/words/
  - assets/images/words/
```

- [x] **Step 4: Verify**

Run: `flutter test test/data/word_bank_test.dart`
Expected: pass after resources exist or test only verifies metadata paths.

### Task 2: Game Image Rendering

**Files:**
- Modify: `lib/features/games/game_session.dart`
- Modify: `test/widget/game_session_test.dart`

**Interfaces:**
- Consumes: `Word.imageAsset`.
- Produces: word prompts and treasure image cards rendered with `Image.asset`.

- [x] **Step 1: Write failing widget assertions**

Update tests to look for `Image` widgets inside revealed treasure image cards and picture prompts.

- [x] **Step 2: Run test to verify failure**

Run: `flutter test test/widget/game_session_test.dart`
Expected: fail because current code uses `Icon`.

- [x] **Step 3: Implement `Image.asset` rendering**

Replace `_materialIconData` usage for word images with a helper that returns:

```dart
Image.asset(word.imageAsset, fit: BoxFit.contain)
```

- [x] **Step 4: Verify**

Run: `flutter test test/widget/game_session_test.dart`
Expected: pass.

### Task 3: Generate and Register Assets

**Files:**
- Create: `assets/images/words/*.png`
- Create: `assets/audio/words/*.wav`

**Interfaces:**
- Consumes: `kWordBank` paths.
- Produces: 48 image files and 48 WAV files.

- [x] **Step 1: Generate audio**

Use Microsoft Zira Desktop to generate one WAV per word at the exact `audioAsset` path.

- [x] **Step 2: Generate images**

Generate one 1:1 PNG per word using the approved children illustration style.

Completion note: the first MVP pass uses locally generated children's flashcard-style PNGs. These files satisfy the per-word asset contract and can later be replaced in place by refined AI or designer illustrations.

- [x] **Step 3: Verify asset existence**

Run an asset audit to assert all `imageAsset` and `audioAsset` files exist.

### Task 4: Full Validation

**Files:**
- All files touched above.

- [x] **Step 1: Static and unit verification**

Run: `flutter analyze`
Expected: no issues.

Run: `flutter test`
Expected: all tests pass.

- [x] **Step 2: Android build**

Run: `flutter build apk --debug`
Expected: `build/app/outputs/flutter-apk/app-debug.apk` is built.
