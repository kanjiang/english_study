# 小词星 MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 做出可在 Android/iOS 运行的第一期：家长登录并创建一个孩子，三款主题记忆游戏赚金币，换装商店，以及 Firebase 云端每日时长锁（可远程改限额）。

**Architecture:** Flutter 三层：`lib/domain` 纯规则（QuizEngine / TimeQuota / Wallet / PIN），`lib/data` 负责 Firestore + `shared_preferences` 缓存，`lib/features` 只通过 Riverpod 调前两层。界面禁止直接读写 Firestore。三款游戏共用 QuizEngine，主题只做动画外壳。

**Tech Stack:** Flutter, Riverpod, Firebase Auth, Cloud Firestore, just_audio, shared_preferences, crypto, timezone

## Global Constraints

- 工作名：小词星；Flutter 包名：`english_app`；界面简体中文，游戏内容英语
- Android 最低 8.0（API 26），iOS 最低 13
- 时区：所有「今天」按 `Asia/Shanghai` 的日历日计算
- 状态管理：Riverpod；音频：`just_audio`（读音打进安装包，不依赖在线 TTS）
- 一个 Firebase 用户 = 一个家长 + 恰好一个孩子
- 已登录默认进孩子首页，不是家长区
- 家长数字密码 6 位，存储 `SHA-256(uid + pin)`，不明文
- 每日限额只能是 20 / 30 / 45 / 60，默认 30；临时加时每次 +10
- 计时只统计本 App 前台秒数；锁屏文案固定为「今天的学习时间用完了，请爸爸妈妈来帮忙。」
- 第一期不做：动画片、完整家园、多孩子、微信登录、自建服务器、Cloud Functions、防破解硬防

---

## File structure

新建 Flutter 工程后，文件职责如下（按功能内聚，不按技术分层把同一功能拆到天南海北）：

```text
lib/
  main.dart                          # timezone 初始化、ProviderScope、Firebase
  app.dart                           # MaterialApp、AuthGate
  domain/
    shanghai_clock.dart              # Asia/Shanghai 今天 YYYY-MM-DD
    time/time_quota.dart
    quiz/word.dart
    quiz/quiz_engine.dart
    wallet/wallet.dart
    auth/parent_pin.dart
    user/user_snapshot.dart          # 与 Firestore 字段一一对应
    user/sync_merge.dart             # 金币/时长合并
  data/
    local_cache.dart                 # shared_preferences
    user_repository.dart             # 抽象 + Firestore 实现
    word_bank.dart                   # 48 词
    just_audio_player.dart           # WordAudioPlayer 实现
  features/
    auth/login_page.dart
    auth/onboarding_page.dart
    auth/auth_gate.dart
    home/child_home_page.dart
    lock/time_lock_page.dart
    parental/parent_gate.dart        # 6 位密码 + 5 次锁定
    parental/parent_zone_page.dart
    shop/shop_page.dart
    games/game_session.dart          # 一局生命周期：引擎 + 中途锁
    games/treasure_page.dart
    games/firefighter_page.dart
    games/monster_page.dart
    avatar/kid_avatar.dart           # 固定形象 + 已穿戴
  app/providers.dart
test/
  domain/time/time_quota_test.dart
  domain/quiz/quiz_engine_test.dart
  domain/wallet/wallet_test.dart
  domain/auth/parent_pin_test.dart
  domain/user/sync_merge_test.dart
  widget/auth_gate_test.dart
  widget/time_lock_test.dart
  widget/game_session_test.dart
assets/audio/beep.mp3                # 第一期 48 词共用占位读音，之后可按词替换
firebase/firestore.rules
```

词的「图片」第一期用 Material `IconData` 映射（不阻塞等插画）。音频第一期全部指向 `assets/audio/beep.mp3`，播放接口可测。

---

### Task 1: Flutter 工程 + TimeQuota

**Files:**
- Create: `pubspec.yaml`（由 `flutter create` 生成后改）
- Create: `lib/domain/time/time_quota.dart`
- Create: `lib/domain/shanghai_clock.dart`
- Test: `test/domain/time/time_quota_test.dart`

**Interfaces:**
- Consumes: 无
- Produces: `TimeQuota`（字段 `dailyLimitMinutes`, `bonusMinutes`, `usedSeconds`, `usedOnDate`）；`int remainingSeconds`；`int remainingMinutesDisplay`；`bool isLocked`；`TimeQuota tick({required int deltaSeconds, required String todayYyyyMmDd})`；`TimeQuota addBonusMinutes()`；`TimeQuota setDailyLimitMinutes(int minutes)`；`TimeQuota rollTo(String todayYyyyMmDd)`；`String shanghaiDateString(DateTime utcOrLocalConverted)` via `ShanghaiClock`

- [ ] **Step 1: 创建 Flutter 工程并改显示名**

在仓库根目录（保留已有 `docs/`）：

```bash
flutter create --org com.xiaocixing --project-name english_app --platforms=android,ios .
```

若因已有 `docs/` 失败：在临时目录 create，再把 `lib/` `test/` `android/` `ios/` `pubspec.yaml` `analysis_options.yaml` 移回根目录。

把 Android 标签和 iOS `CFBundleDisplayName` 改成 `小词星`。`android/app/build.gradle.kts`（或 `.gradle`）中 `minSdk = 26`。

`pubspec.yaml` 依赖加入：

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  firebase_core: ^3.8.1
  firebase_auth: ^5.3.4
  cloud_firestore: ^5.6.0
  just_audio: ^0.9.42
  shared_preferences: ^2.3.4
  crypto: ^3.0.6
  timezone: ^0.10.0
```

- [ ] **Step 2: Write the failing test**

Create `test/domain/time/time_quota_test.dart`:

```dart
import 'package:english_app/domain/time/time_quota.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TimeQuota q({
    int limit = 30,
    int bonus = 0,
    int used = 0,
    String date = '2026-08-25',
  }) =>
      TimeQuota(
        dailyLimitMinutes: limit,
        bonusMinutes: bonus,
        usedSeconds: used,
        usedOnDate: date,
      );

  test('default 30 minutes is 1800 seconds capacity', () {
    expect(q().remainingSeconds, 1800);
    expect(q().isLocked, isFalse);
    expect(q().remainingMinutesDisplay, 30);
  });

  test('locks when usedSeconds reaches capacity', () {
    expect(q(used: 1800).isLocked, isTrue);
    expect(q(used: 1800).remainingSeconds, 0);
    expect(q(used: 1800).remainingMinutesDisplay, 0);
  });

  test('display minutes uses ceil of remaining seconds', () {
    expect(q(used: 1800 - 1).remainingMinutesDisplay, 1);
    expect(q(used: 1800 - 61).remainingMinutesDisplay, 2);
  });

  test('tick accumulates foreground seconds', () {
    final next = q(used: 10).tick(deltaSeconds: 5, todayYyyyMmDd: '2026-08-25');
    expect(next.usedSeconds, 15);
  });

  test('new calendar day resets usedSeconds and bonusMinutes', () {
    final next = q(bonus: 10, used: 100).tick(
      deltaSeconds: 3,
      todayYyyyMmDd: '2026-08-26',
    );
    expect(next.usedOnDate, '2026-08-26');
    expect(next.usedSeconds, 3);
    expect(next.bonusMinutes, 0);
  });

  test('addBonusMinutes adds 10 and can be called twice', () {
    final next = q().addBonusMinutes().addBonusMinutes();
    expect(next.bonusMinutes, 20);
    expect(next.remainingSeconds, 1800 + 1200);
  });

  test('setDailyLimitMinutes only allows 20/30/45/60', () {
    expect(q().setDailyLimitMinutes(20).dailyLimitMinutes, 20);
    expect(() => q().setDailyLimitMinutes(15), throwsArgumentError);
  });

  test('reducing limit below used locks', () {
    final next = q(limit: 60, used: 30 * 60).setDailyLimitMinutes(20);
    expect(next.isLocked, isTrue);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/domain/time/time_quota_test.dart`

Expected: FAIL — `TimeQuota` not found.

- [ ] **Step 4: Write minimal implementation**

Create `lib/domain/time/time_quota.dart`:

```dart
class TimeQuota {
  static const allowedDailyLimitMinutes = [20, 30, 45, 60];
  static const defaultDailyLimitMinutes = 30;
  static const bonusStepMinutes = 10;

  const TimeQuota({
    required this.dailyLimitMinutes,
    required this.bonusMinutes,
    required this.usedSeconds,
    required this.usedOnDate,
  });

  final int dailyLimitMinutes;
  final int bonusMinutes;
  final int usedSeconds;
  final String usedOnDate;

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
```

Create `lib/domain/shanghai_clock.dart`:

```dart
import 'package:timezone/timezone.dart' as tz;

class ShanghaiClock {
  const ShanghaiClock();

  tz.TZDateTime now() => tz.TZDateTime.now(tz.getLocation('Asia/Shanghai'));

  String todayYyyyMmDd() {
    final n = now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }
}
```

`main.dart` 里初始化放到 Task 7；本任务测试不依赖 timezone 数据。

- [ ] **Step 5: Run tests and commit**

Run: `flutter test test/domain/time/time_quota_test.dart`

Expected: PASS

```bash
git add pubspec.yaml lib/domain/time/time_quota.dart lib/domain/shanghai_clock.dart test/domain/time/time_quota_test.dart android ios
git commit -m "feat: add Flutter app shell and TimeQuota rules"
```

---

### Task 2: QuizEngine（听音选图 / 看图选词）

**Files:**
- Create: `lib/domain/quiz/word.dart`
- Create: `lib/domain/quiz/quiz_engine.dart`
- Test: `test/domain/quiz/quiz_engine_test.dart`

**Interfaces:**
- Consumes: 无
- Produces: `enum QuizKind { listenPickPicture, picturePickWord, flipMatch }`；`class Word { id, en, zh, category, iconCodePoint, audioAsset }`；`class QuizQuestion { Word prompt; List<Word> choices; }`；`class EngineFeedback { bool correct; int coinsDelta; bool roundComplete; }`；`class QuizEngine { factory QuizEngine.start({required QuizKind kind, required List<Word> bank, required Random random}); int coinsEarned; int streak; int index; int total; bool isComplete; QuizQuestion get currentQuestion; EngineFeedback submitAnswer(String wordId); }`。听音/看图 `total == 10`。答对 +3，连对 ≥ 3 再 +1；答错 0 分、连对清零、进入下一题。

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:math';

import 'package:english_app/domain/quiz/quiz_engine.dart';
import 'package:english_app/domain/quiz/word.dart';
import 'package:flutter_test/flutter_test.dart';

Word w(String id) => Word(
      id: id,
      en: id,
      zh: id,
      category: 'animals',
      iconCodePoint: 0xe91d,
      audioAsset: 'assets/audio/beep.mp3',
    );

List<Word> bank10() => List.generate(10, (i) => w('w$i'));

void main() {
  test('listen mode starts with 10 questions and 4 choices', () {
    final e = QuizEngine.start(
      kind: QuizKind.listenPickPicture,
      bank: bank10(),
      random: Random(1),
    );
    expect(e.total, 10);
    expect(e.currentQuestion.choices, hasLength(4));
    expect(e.currentQuestion.choices.map((c) => c.id),
        contains(e.currentQuestion.prompt.id));
  });

  test('correct answer awards 3 coins and advances', () {
    final e = QuizEngine.start(
      kind: QuizKind.picturePickWord,
      bank: bank10(),
      random: Random(1),
    );
    final id = e.currentQuestion.prompt.id;
    final fb = e.submitAnswer(id);
    expect(fb.correct, isTrue);
    expect(fb.coinsDelta, 3);
    expect(e.coinsEarned, 3);
    expect(e.index, 1);
  });

  test('wrong answer awards 0, resets streak, still advances', () {
    final e = QuizEngine.start(
      kind: QuizKind.listenPickPicture,
      bank: bank10(),
      random: Random(1),
    );
    final correct = e.currentQuestion.prompt.id;
    final wrong = e.currentQuestion.choices.firstWhere((c) => c.id != correct).id;
    final fb = e.submitAnswer(wrong);
    expect(fb.correct, isFalse);
    expect(fb.coinsDelta, 0);
    expect(e.streak, 0);
    expect(e.index, 1);
  });

  test('streak of 3 adds bonus coin on the third correct', () {
    final e = QuizEngine.start(
      kind: QuizKind.picturePickWord,
      bank: bank10(),
      random: Random(2),
    );
    var lastDelta = 0;
    for (var i = 0; i < 3; i++) {
      lastDelta = e.submitAnswer(e.currentQuestion.prompt.id).coinsDelta;
    }
    expect(lastDelta, 4);
    expect(e.coinsEarned, 3 + 3 + 4);
  });

  test('cannot retry same question after wrong answer', () {
    final e = QuizEngine.start(
      kind: QuizKind.listenPickPicture,
      bank: bank10(),
      random: Random(1),
    );
    final firstPrompt = e.currentQuestion.prompt.id;
    final wrong = e.currentQuestion.choices
        .firstWhere((c) => c.id != firstPrompt)
        .id;
    e.submitAnswer(wrong);
    expect(e.currentQuestion.prompt.id, isNot(firstPrompt));
  });

  test('tenth answer completes the round', () {
    final e = QuizEngine.start(
      kind: QuizKind.listenPickPicture,
      bank: bank10(),
      random: Random(1),
    );
    EngineFeedback? fb;
    while (!e.isComplete) {
      fb = e.submitAnswer(e.currentQuestion.prompt.id);
    }
    expect(fb!.roundComplete, isTrue);
    expect(e.isComplete, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/quiz/quiz_engine_test.dart`

Expected: FAIL — library not found.

- [ ] **Step 3: Write minimal implementation**

`lib/domain/quiz/word.dart`:

```dart
class Word {
  const Word({
    required this.id,
    required this.en,
    required this.zh,
    required this.category,
    required this.iconCodePoint,
    required this.audioAsset,
  });

  final String id;
  final String en;
  final String zh;
  final String category;
  final int iconCodePoint;
  final String audioAsset;
}
```

`lib/domain/quiz/quiz_engine.dart`（本任务实现 listen/picture；`flipMatch` 在 Task 3 同一文件扩展）：

```dart
import 'dart:math';

import 'package:english_app/domain/quiz/word.dart';

enum QuizKind { listenPickPicture, picturePickWord, flipMatch }

class QuizQuestion {
  const QuizQuestion({required this.prompt, required this.choices});
  final Word prompt;
  final List<Word> choices;
}

class EngineFeedback {
  const EngineFeedback({
    required this.correct,
    required this.coinsDelta,
    required this.roundComplete,
  });
  final bool correct;
  final int coinsDelta;
  final bool roundComplete;
}

class FlipCard {
  const FlipCard({
    required this.index,
    required this.wordId,
    required this.isImage,
    required this.faceUp,
    required this.matched,
  });
  final int index;
  final String wordId;
  final bool isImage;
  final bool faceUp;
  final bool matched;

  FlipCard copyWith({bool? faceUp, bool? matched}) => FlipCard(
        index: index,
        wordId: wordId,
        isImage: isImage,
        faceUp: faceUp ?? this.faceUp,
        matched: matched ?? this.matched,
      );
}

class QuizEngine {
  QuizEngine._({
    required this.kind,
    required List<QuizQuestion> questions,
    required List<FlipCard> cards,
  })  : _questions = questions,
        _cards = cards;

  factory QuizEngine.start({
    required QuizKind kind,
    required List<Word> bank,
    required Random random,
  }) {
    if (kind == QuizKind.flipMatch) {
      if (bank.length < 6) {
        throw ArgumentError('flipMatch needs 6 words');
      }
      final picked = [...bank]..shuffle(random);
      final six = picked.take(6).toList();
      final cards = <FlipCard>[];
      var i = 0;
      for (final word in six) {
        cards.add(FlipCard(
          index: i++,
          wordId: word.id,
          isImage: true,
          faceUp: false,
          matched: false,
        ));
        cards.add(FlipCard(
          index: i++,
          wordId: word.id,
          isImage: false,
          faceUp: false,
          matched: false,
        ));
      }
      cards.shuffle(random);
      final numbered = [
        for (var n = 0; n < cards.length; n++)
          FlipCard(
            index: n,
            wordId: cards[n].wordId,
            isImage: cards[n].isImage,
            faceUp: false,
            matched: false,
          ),
      ];
      return QuizEngine._(kind: kind, questions: const [], cards: numbered);
    }
    if (bank.length < 10) {
      throw ArgumentError('pick modes need 10 words');
    }
    final picked = [...bank]..shuffle(random);
    final ten = picked.take(10).toList();
    final questions = ten.map((prompt) {
      final others = bank.where((w) => w.id != prompt.id).toList()
        ..shuffle(random);
      final choices = [prompt, ...others.take(3)]..shuffle(random);
      return QuizQuestion(prompt: prompt, choices: choices);
    }).toList();
    return QuizEngine._(kind: kind, questions: questions, cards: const []);
  }

  final QuizKind kind;
  final List<QuizQuestion> _questions;
  List<FlipCard> _cards;
  int index = 0;
  int coinsEarned = 0;
  int streak = 0;
  bool isComplete = false;

  List<FlipCard> get cards => List.unmodifiable(_cards);
  int get total => kind == QuizKind.flipMatch ? 6 : _questions.length;

  QuizQuestion get currentQuestion {
    if (kind == QuizKind.flipMatch) {
      throw StateError('flipMatch has no currentQuestion');
    }
    return _questions[index];
  }

  EngineFeedback submitAnswer(String wordId) {
    if (kind == QuizKind.flipMatch) {
      throw StateError('use flip()');
    }
    if (isComplete) {
      throw StateError('round already complete');
    }
    final correct = wordId == currentQuestion.prompt.id;
    var delta = 0;
    if (correct) {
      streak += 1;
      delta = 3 + (streak >= 3 ? 1 : 0);
      coinsEarned += delta;
    } else {
      streak = 0;
    }
    index += 1;
    if (index >= _questions.length) {
      isComplete = true;
      index = _questions.length - 1;
    }
    return EngineFeedback(
      correct: correct,
      coinsDelta: delta,
      roundComplete: isComplete,
    );
  }

  EngineFeedback flip(int cardIndex) {
    throw UnimplementedError('Task 3');
  }
}
```

本任务测试不调用 `flip`。保留方法签名，实现放到 Task 3。

- [ ] **Step 4: Run tests**

Run: `flutter test test/domain/quiz/quiz_engine_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/domain/quiz test/domain/quiz
git commit -m "feat: add QuizEngine for listen and picture quizzes"
```

---

### Task 3: QuizEngine 翻牌配对

**Files:**
- Modify: `lib/domain/quiz/quiz_engine.dart`
- Modify: `test/domain/quiz/quiz_engine_test.dart`

**Interfaces:**
- Consumes: `QuizEngine.start(kind: QuizKind.flipMatch, ...)` from Task 2
- Produces: `EngineFeedback flip(int cardIndex)`；12 张牌、6 对；两张 `wordId` 相同则 `matched=true` 并按答对计金币；不同则翻回（`faceUp=false`），连对清零；牌留在场上。`isComplete` 当 6 对都 matched。

- [ ] **Step 1: Write the failing tests (append to existing file)**

```dart
  test('flipMatch deals 12 cards from 6 words', () {
    final e = QuizEngine.start(
      kind: QuizKind.flipMatch,
      bank: bank10(),
      random: Random(1),
    );
    expect(e.cards, hasLength(12));
    expect(e.total, 6);
  });

  test('matching image and text pair awards coins', () {
    final e = QuizEngine.start(
      kind: QuizKind.flipMatch,
      bank: bank10(),
      random: Random(1),
    );
    final first = e.cards.first;
    final match = e.cards.firstWhere(
      (c) => c.wordId == first.wordId && c.index != first.index,
    );
    e.flip(first.index);
    final fb = e.flip(match.index);
    expect(fb.correct, isTrue);
    expect(fb.coinsDelta, 3);
    expect(e.cards[first.index].matched, isTrue);
  });

  test('mismatch flips both back and resets streak', () {
    final e = QuizEngine.start(
      kind: QuizKind.flipMatch,
      bank: bank10(),
      random: Random(1),
    );
    final a = e.cards[0];
    final b = e.cards.firstWhere((c) => c.wordId != a.wordId);
    e.flip(a.index);
    final fb = e.flip(b.index);
    expect(fb.correct, isFalse);
    expect(e.streak, 0);
    expect(e.cards[a.index].faceUp, isFalse);
    expect(e.cards[b.index].faceUp, isFalse);
  });
```

- [ ] **Step 2: Run test to verify mismatch/match tests fail**

Run: `flutter test test/domain/quiz/quiz_engine_test.dart`

Expected: FAIL on `UnimplementedError` or `flip` not matching.

- [ ] **Step 3: Implement `flip`**

Replace `flip` with:

```dart
  int? _openIndex;

  EngineFeedback flip(int cardIndex) {
    if (kind != QuizKind.flipMatch) {
      throw StateError('use submitAnswer()');
    }
    if (isComplete) {
      throw StateError('round already complete');
    }
    final card = _cards[cardIndex];
    if (card.matched || card.faceUp) {
      return const EngineFeedback(
        correct: false,
        coinsDelta: 0,
        roundComplete: false,
      );
    }
    _cards[cardIndex] = card.copyWith(faceUp: true);
    if (_openIndex == null) {
      _openIndex = cardIndex;
      return const EngineFeedback(
        correct: false,
        coinsDelta: 0,
        roundComplete: false,
      );
    }
    final first = _cards[_openIndex!];
    final second = _cards[cardIndex];
    final matched = first.wordId == second.wordId;
    var delta = 0;
    if (matched) {
      _cards[_openIndex!] = first.copyWith(matched: true, faceUp: true);
      _cards[cardIndex] = second.copyWith(matched: true, faceUp: true);
      streak += 1;
      delta = 3 + (streak >= 3 ? 1 : 0);
      coinsEarned += delta;
    } else {
      _cards[_openIndex!] = first.copyWith(faceUp: false);
      _cards[cardIndex] = second.copyWith(faceUp: false);
      streak = 0;
    }
    _openIndex = null;
    final done = _cards.every((c) => c.matched);
    if (done) isComplete = true;
    return EngineFeedback(
      correct: matched,
      coinsDelta: delta,
      roundComplete: done,
    );
  }
```

把 `_openIndex` 做成字段，与 `QuizEngine._` 构造函数一起初始化为 `null`。

- [ ] **Step 4: Run tests**

Run: `flutter test test/domain/quiz/quiz_engine_test.dart`

Expected: PASS（含 Task 2 全部用例）

- [ ] **Step 5: Commit**

```bash
git add lib/domain/quiz/quiz_engine.dart test/domain/quiz/quiz_engine_test.dart
git commit -m "feat: add flip-match mode to QuizEngine"
```

---

### Task 4: Wallet 与 9 件换装

**Files:**
- Create: `lib/domain/wallet/wallet.dart`
- Test: `test/domain/wallet/wallet_test.dart`

**Interfaces:**
- Consumes: 无
- Produces: `enum ShopSlot { hat, glasses, clothes }`；`class ShopItem { String id; ShopSlot slot; int price; String nameZh; }`；`class Equipped { String? hat; String? glasses; String? clothes; }`；`class Wallet { int coins; Set<String> ownedItemIds; Equipped equipped; Wallet addCoins(int amount); WalletBuyResult buy(ShopItem item, {required bool online}); Wallet equip(String itemId); Wallet unequip(ShopSlot slot); }`；`class WalletBuyResult { bool ok; Wallet wallet; String? errorKey; }`。`errorKey` 只能是 `insufficient_coins` / `already_owned` / `offline`。`ShopCatalog.items` 恰好 9 件，价格 20/40/60 各档每槽一位。`equip` 未拥有则 `throw StateError('not_owned')`。

- [ ] **Step 1: Write the failing test**

```dart
import 'package:english_app/domain/wallet/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog has 9 items with 20/40/60 per slot', () {
    expect(ShopCatalog.items, hasLength(9));
    for (final slot in ShopSlot.values) {
      final prices = ShopCatalog.items
          .where((i) => i.slot == slot)
          .map((i) => i.price)
          .toList()
        ..sort();
      expect(prices, [20, 40, 60]);
    }
  });

  test('buy succeeds online when coins are enough', () {
    final hat = ShopCatalog.items.firstWhere((i) => i.price == 20);
    final w = Wallet(
      coins: 20,
      ownedItemIds: {},
      equipped: const Equipped(),
    );
    final r = w.buy(hat, online: true);
    expect(r.ok, isTrue);
    expect(r.wallet.coins, 0);
    expect(r.wallet.ownedItemIds, contains(hat.id));
  });

  test('buy fails offline without changing coins', () {
    final hat = ShopCatalog.items.first;
    final w = Wallet(coins: 100, ownedItemIds: {}, equipped: const Equipped());
    final r = w.buy(hat, online: false);
    expect(r.ok, isFalse);
    expect(r.errorKey, 'offline');
    expect(r.wallet.coins, 100);
  });

  test('buy fails if already owned', () {
    final hat = ShopCatalog.items.first;
    final w = Wallet(
      coins: 100,
      ownedItemIds: {hat.id},
      equipped: const Equipped(),
    );
    final r = w.buy(hat, online: true);
    expect(r.errorKey, 'already_owned');
    expect(r.wallet.coins, 100);
  });

  test('buy fails if not enough coins', () {
    final hat = ShopCatalog.items.firstWhere((i) => i.price == 60);
    final w = Wallet(coins: 20, ownedItemIds: {}, equipped: const Equipped());
    expect(w.buy(hat, online: true).errorKey, 'insufficient_coins');
  });

  test('cannot equip item not owned', () {
    final w = Wallet(coins: 0, ownedItemIds: {}, equipped: const Equipped());
    expect(() => w.equip(ShopCatalog.items.first.id), throwsStateError);
  });

  test('equip and unequip hat', () {
    final hat = ShopCatalog.items.firstWhere((i) => i.slot == ShopSlot.hat);
    final w = Wallet(
      coins: 0,
      ownedItemIds: {hat.id},
      equipped: const Equipped(),
    ).equip(hat.id);
    expect(w.equipped.hat, hat.id);
    expect(w.unequip(ShopSlot.hat).equipped.hat, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/wallet/wallet_test.dart`

Expected: FAIL — `wallet.dart` not found.

- [ ] **Step 3: Write implementation**

```dart
enum ShopSlot { hat, glasses, clothes }

class ShopItem {
  const ShopItem({
    required this.id,
    required this.slot,
    required this.price,
    required this.nameZh,
  });
  final String id;
  final ShopSlot slot;
  final int price;
  final String nameZh;
}

class ShopCatalog {
  static const items = <ShopItem>[
    ShopItem(id: 'hat_20', slot: ShopSlot.hat, price: 20, nameZh: '红帽子'),
    ShopItem(id: 'hat_40', slot: ShopSlot.hat, price: 40, nameZh: '探险帽'),
    ShopItem(id: 'hat_60', slot: ShopSlot.hat, price: 60, nameZh: '皇冠'),
    ShopItem(
        id: 'glasses_20',
        slot: ShopSlot.glasses,
        price: 20,
        nameZh: '圆眼镜'),
    ShopItem(
        id: 'glasses_40',
        slot: ShopSlot.glasses,
        price: 40,
        nameZh: '太阳镜'),
    ShopItem(
        id: 'glasses_60',
        slot: ShopSlot.glasses,
        price: 60,
        nameZh: '星星眼镜'),
    ShopItem(
        id: 'clothes_20',
        slot: ShopSlot.clothes,
        price: 20,
        nameZh: '蓝T恤'),
    ShopItem(
        id: 'clothes_40',
        slot: ShopSlot.clothes,
        price: 40,
        nameZh: '消防员外套'),
    ShopItem(
        id: 'clothes_60',
        slot: ShopSlot.clothes,
        price: 60,
        nameZh: '勇者披风'),
  ];

  static ShopItem byId(String id) => items.firstWhere((i) => i.id == id);
}

class Equipped {
  const Equipped({this.hat, this.glasses, this.clothes});
  final String? hat;
  final String? glasses;
  final String? clothes;

  Equipped withSlot(ShopSlot slot, String? id) {
    switch (slot) {
      case ShopSlot.hat:
        return Equipped(hat: id, glasses: glasses, clothes: clothes);
      case ShopSlot.glasses:
        return Equipped(hat: hat, glasses: id, clothes: clothes);
      case ShopSlot.clothes:
        return Equipped(hat: hat, glasses: glasses, clothes: id);
    }
  }
}

class WalletBuyResult {
  const WalletBuyResult({required this.ok, required this.wallet, this.errorKey});
  final bool ok;
  final Wallet wallet;
  final String? errorKey;
}

class Wallet {
  const Wallet({
    required this.coins,
    required this.ownedItemIds,
    required this.equipped,
  });

  final int coins;
  final Set<String> ownedItemIds;
  final Equipped equipped;

  Wallet addCoins(int amount) {
    if (amount < 0) throw ArgumentError.value(amount);
    return Wallet(
      coins: coins + amount,
      ownedItemIds: ownedItemIds,
      equipped: equipped,
    );
  }

  WalletBuyResult buy(ShopItem item, {required bool online}) {
    if (!online) {
      return WalletBuyResult(ok: false, wallet: this, errorKey: 'offline');
    }
    if (ownedItemIds.contains(item.id)) {
      return WalletBuyResult(
          ok: false, wallet: this, errorKey: 'already_owned');
    }
    if (coins < item.price) {
      return WalletBuyResult(
          ok: false, wallet: this, errorKey: 'insufficient_coins');
    }
    return WalletBuyResult(
      ok: true,
      wallet: Wallet(
        coins: coins - item.price,
        ownedItemIds: {...ownedItemIds, item.id},
        equipped: equipped,
      ),
    );
  }

  Wallet equip(String itemId) {
    if (!ownedItemIds.contains(itemId)) {
      throw StateError('not_owned');
    }
    final item = ShopCatalog.byId(itemId);
    return Wallet(
      coins: coins,
      ownedItemIds: ownedItemIds,
      equipped: equipped.withSlot(item.slot, itemId),
    );
  }

  Wallet unequip(ShopSlot slot) {
    return Wallet(
      coins: coins,
      ownedItemIds: ownedItemIds,
      equipped: equipped.withSlot(slot, null),
    );
  }
}
```

`Equipped.withSlot` 必须 `switch` 穷尽 `ShopSlot`，不要 `default`。

- [ ] **Step 4: Run tests**

Run: `flutter test test/domain/wallet/wallet_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/domain/wallet test/domain/wallet
git commit -m "feat: add wallet, shop catalog, and equip rules"
```

---

### Task 5: PIN、UserSnapshot、同步合并、本地缓存

**Files:**
- Create: `lib/domain/auth/parent_pin.dart`
- Create: `lib/domain/user/user_snapshot.dart`
- Create: `lib/domain/user/sync_merge.dart`
- Create: `lib/data/local_cache.dart`
- Test: `test/domain/auth/parent_pin_test.dart`
- Test: `test/domain/user/sync_merge_test.dart`
- Test: `test/data/local_cache_test.dart`

**Interfaces:**
- Consumes: `TimeQuota`, `Wallet` / `Equipped`
- Produces: `String hashParentPin({required String uid, required String pin})`；`bool verifyParentPin({required String uid, required String pin, required String hash})`；`bool isSixDigitPin(String pin)`；`class PinGate { PinTryResult tryPin({required String uid, required String pin, required String hash, required DateTime now}); }` 连续错 5 次则 `lockedUntil = now + 1 minute`；`class UserSnapshot` 字段与 spec 的 `users/{uid}` 一致；`TimeQuota mergeTimeQuota({required TimeQuota local, required TimeQuota remote, required String todayYyyyMmDd})`：先 `rollTo(today)`，`usedSeconds` 取较大，`bonusMinutes` 取较大，`dailyLimitMinutes` 用 remote；`int mergeCoins({required int cloudCoins, required int pendingLegalReward})` 返回 `cloudCoins + pendingLegalReward`（pending < 0 当 0）；`class LocalCache { Future<void> saveSnapshot(UserSnapshot s); Future<UserSnapshot?> loadSnapshot(); Future<void> savePendingReward(int coins); Future<int> loadPendingReward(); Future<void> saveUsedSeconds(int seconds); }` 全部走 `SharedPreferences`。

- [ ] **Step 1: Write failing PIN + merge tests**

`test/domain/auth/parent_pin_test.dart`:

```dart
import 'package:english_app/domain/auth/parent_pin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hash is not the raw pin', () {
    final h = hashParentPin(uid: 'u1', pin: '123456');
    expect(h, isNot('123456'));
    expect(verifyParentPin(uid: 'u1', pin: '123456', hash: h), isTrue);
    expect(verifyParentPin(uid: 'u1', pin: '000000', hash: h), isFalse);
  });

  test('same pin different uid does not verify', () {
    final h = hashParentPin(uid: 'u1', pin: '123456');
    expect(verifyParentPin(uid: 'u2', pin: '123456', hash: h), isFalse);
  });

  test('isSixDigitPin', () {
    expect(isSixDigitPin('123456'), isTrue);
    expect(isSixDigitPin('12345'), isFalse);
    expect(isSixDigitPin('12345a'), isFalse);
  });

  test('five wrong tries lock for 60 seconds', () {
    final hash = hashParentPin(uid: 'u1', pin: '123456');
    final gate = PinGate();
    final t0 = DateTime.utc(2026, 8, 25, 12);
    for (var i = 0; i < 5; i++) {
      gate.tryPin(uid: 'u1', pin: '000000', hash: hash, now: t0);
    }
    final locked = gate.tryPin(
      uid: 'u1',
      pin: '123456',
      hash: hash,
      now: t0.add(const Duration(seconds: 30)),
    );
    expect(locked.ok, isFalse);
    expect(locked.errorKey, 'locked');
    final after = gate.tryPin(
      uid: 'u1',
      pin: '123456',
      hash: hash,
      now: t0.add(const Duration(seconds: 61)),
    );
    expect(after.ok, isTrue);
  });
}
```

`test/domain/user/sync_merge_test.dart`:

```dart
import 'package:english_app/domain/time/time_quota.dart';
import 'package:english_app/domain/user/sync_merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merge coins cloud 100 + pending 20 = 120', () {
    expect(mergeCoins(cloudCoins: 100, pendingLegalReward: 20), 120);
  });

  test('same day usedSeconds takes max', () {
    const local = TimeQuota(
      dailyLimitMinutes: 30,
      bonusMinutes: 0,
      usedSeconds: 80,
      usedOnDate: '2026-08-25',
    );
    const remote = TimeQuota(
      dailyLimitMinutes: 20,
      bonusMinutes: 10,
      usedSeconds: 50,
      usedOnDate: '2026-08-25',
    );
    final m = mergeTimeQuota(
      local: local,
      remote: remote,
      todayYyyyMmDd: '2026-08-25',
    );
    expect(m.usedSeconds, 80);
    expect(m.dailyLimitMinutes, 20);
    expect(m.bonusMinutes, 10);
  });

  test('new day resets both before merge', () {
    const local = TimeQuota(
      dailyLimitMinutes: 30,
      bonusMinutes: 10,
      usedSeconds: 80,
      usedOnDate: '2026-08-24',
    );
    const remote = TimeQuota(
      dailyLimitMinutes: 30,
      bonusMinutes: 0,
      usedSeconds: 999,
      usedOnDate: '2026-08-24',
    );
    final m = mergeTimeQuota(
      local: local,
      remote: remote,
      todayYyyyMmDd: '2026-08-25',
    );
    expect(m.usedSeconds, 0);
    expect(m.bonusMinutes, 0);
    expect(m.usedOnDate, '2026-08-25');
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/domain/auth/parent_pin_test.dart test/domain/user/sync_merge_test.dart`

Expected: FAIL — files missing.

- [ ] **Step 3: Implement**

`lib/domain/auth/parent_pin.dart`:

```dart
import 'dart:convert';

import 'package:crypto/crypto.dart';

bool isSixDigitPin(String pin) => RegExp(r'^\d{6}$').hasMatch(pin);

String hashParentPin({required String uid, required String pin}) {
  return sha256.convert(utf8.encode('$uid$pin')).toString();
}

bool verifyParentPin({
  required String uid,
  required String pin,
  required String hash,
}) {
  return hashParentPin(uid: uid, pin: pin) == hash;
}

class PinTryResult {
  const PinTryResult({required this.ok, this.errorKey});
  final bool ok;
  final String? errorKey;
}

class PinGate {
  int _failures = 0;
  DateTime? _lockedUntil;

  PinTryResult tryPin({
    required String uid,
    required String pin,
    required String hash,
    required DateTime now,
  }) {
    if (_lockedUntil != null && now.isBefore(_lockedUntil!)) {
      return const PinTryResult(ok: false, errorKey: 'locked');
    }
    if (_lockedUntil != null && !now.isBefore(_lockedUntil!)) {
      _failures = 0;
      _lockedUntil = null;
    }
    if (verifyParentPin(uid: uid, pin: pin, hash: hash)) {
      _failures = 0;
      return const PinTryResult(ok: true);
    }
    _failures += 1;
    if (_failures >= 5) {
      _lockedUntil = now.add(const Duration(minutes: 1));
    }
    return const PinTryResult(ok: false, errorKey: 'wrong');
  }
}
```

`lib/domain/user/sync_merge.dart`:

```dart
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
  final l = local.rollTo(todayYyyyMmDd);
  final r = remote.rollTo(todayYyyyMmDd);
  return TimeQuota(
    dailyLimitMinutes: r.dailyLimitMinutes,
    bonusMinutes:
        l.bonusMinutes > r.bonusMinutes ? l.bonusMinutes : r.bonusMinutes,
    usedSeconds: l.usedSeconds > r.usedSeconds ? l.usedSeconds : r.usedSeconds,
    usedOnDate: todayYyyyMmDd,
  );
}
```

`lib/domain/user/user_snapshot.dart`:

```dart
import 'package:english_app/domain/time/time_quota.dart';
import 'package:english_app/domain/wallet/wallet.dart';

class GameStats {
  const GameStats({
    this.treasureLastScore = 0,
    this.firefighterLastScore = 0,
    this.monsterLastScore = 0,
  });
  final int treasureLastScore;
  final int firefighterLastScore;
  final int monsterLastScore;

  GameStats copyWith({
    int? treasureLastScore,
    int? firefighterLastScore,
    int? monsterLastScore,
  }) =>
      GameStats(
        treasureLastScore: treasureLastScore ?? this.treasureLastScore,
        firefighterLastScore:
            firefighterLastScore ?? this.firefighterLastScore,
        monsterLastScore: monsterLastScore ?? this.monsterLastScore,
      );
}

class ChildProfile {
  const ChildProfile({
    required this.name,
    required this.avatarId,
    required this.wallet,
  });
  final String name;
  final String avatarId;
  final Wallet wallet;
}

class UserSnapshot {
  const UserSnapshot({
    required this.uid,
    required this.parentPinHash,
    required this.child,
    required this.time,
    this.email,
    this.phone,
    this.gameStats = const GameStats(),
  });

  final String uid;
  final String? email;
  final String? phone;
  final String parentPinHash;
  final ChildProfile child;
  final TimeQuota time;
  final GameStats gameStats;

  static const avatarIds = ['avatar_1', 'avatar_2', 'avatar_3', 'avatar_4'];

  UserSnapshot copyWith({
    String? parentPinHash,
    ChildProfile? child,
    TimeQuota? time,
    GameStats? gameStats,
    String? email,
    String? phone,
  }) =>
      UserSnapshot(
        uid: uid,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        parentPinHash: parentPinHash ?? this.parentPinHash,
        child: child ?? this.child,
        time: time ?? this.time,
        gameStats: gameStats ?? this.gameStats,
      );

  Map<String, dynamic> toMap() => {
        'email': email,
        'phone': phone,
        'parentPinHash': parentPinHash,
        'child': {
          'name': child.name,
          'avatarId': child.avatarId,
          'coins': child.wallet.coins,
          'ownedItemIds': child.wallet.ownedItemIds.toList(),
          'equipped': {
            'hat': child.wallet.equipped.hat,
            'glasses': child.wallet.equipped.glasses,
            'clothes': child.wallet.equipped.clothes,
          },
        },
        'time': {
          'dailyLimitMinutes': time.dailyLimitMinutes,
          'bonusMinutes': time.bonusMinutes,
          'usedSeconds': time.usedSeconds,
          'usedOnDate': time.usedOnDate,
        },
        'gameStats': {
          'treasureLastScore': gameStats.treasureLastScore,
          'firefighterLastScore': gameStats.firefighterLastScore,
          'monsterLastScore': gameStats.monsterLastScore,
        },
      };

  factory UserSnapshot.fromMap(String uid, Map<String, dynamic> map) {
    final child = map['child'] as Map<String, dynamic>;
    final equipped = child['equipped'] as Map<String, dynamic>;
    final time = map['time'] as Map<String, dynamic>;
    final stats = map['gameStats'] as Map<String, dynamic>? ?? {};
    return UserSnapshot(
      uid: uid,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      parentPinHash: map['parentPinHash'] as String,
      child: ChildProfile(
        name: child['name'] as String,
        avatarId: child['avatarId'] as String,
        wallet: Wallet(
          coins: child['coins'] as int,
          ownedItemIds: {...(child['ownedItemIds'] as List).cast<String>()},
          equipped: Equipped(
            hat: equipped['hat'] as String?,
            glasses: equipped['glasses'] as String?,
            clothes: equipped['clothes'] as String?,
          ),
        ),
      ),
      time: TimeQuota(
        dailyLimitMinutes: time['dailyLimitMinutes'] as int,
        bonusMinutes: time['bonusMinutes'] as int,
        usedSeconds: time['usedSeconds'] as int,
        usedOnDate: time['usedOnDate'] as String,
      ),
      gameStats: GameStats(
        treasureLastScore: (stats['treasureLastScore'] as int?) ?? 0,
        firefighterLastScore: (stats['firefighterLastScore'] as int?) ?? 0,
        monsterLastScore: (stats['monsterLastScore'] as int?) ?? 0,
      ),
    );
  }
}
```

`lib/data/local_cache.dart`：用 `SharedPreferences` 三个 key：`snapshot_json`、`pending_reward`、`used_seconds`。`saveSnapshot` 写 `jsonEncode(s.toMap())` 外加 `uid` 字段。测试用 `SharedPreferences.setMockInitialValues({})`。

`lib/data/local_cache.dart`:

```dart
import 'dart:convert';

import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  static const _snapshotKey = 'snapshot_json';
  static const _uidKey = 'snapshot_uid';
  static const _pendingKey = 'pending_reward';
  static const _usedKey = 'used_seconds';

  Future<void> saveSnapshot(UserSnapshot s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uidKey, s.uid);
    await prefs.setString(_snapshotKey, jsonEncode(s.toMap()));
  }

  Future<UserSnapshot?> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_uidKey);
    final raw = prefs.getString(_snapshotKey);
    if (uid == null || raw == null) return null;
    return UserSnapshot.fromMap(uid, jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> savePendingReward(int coins) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pendingKey, coins);
  }

  Future<int> loadPendingReward() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pendingKey) ?? 0;
  }

  Future<void> saveUsedSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_usedKey, seconds);
  }

  Future<int?> loadUsedSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_usedKey);
  }
}
```

`test/data/local_cache_test.dart`：`SharedPreferences.setMockInitialValues({})`，构造与 `seed()` 相同的 `UserSnapshot`（名字「豆豆」），`saveSnapshot` + `savePendingReward(20)` 后 `loadSnapshot()!.child.name == '豆豆'` 且 `loadPendingReward() == 20`。

- [ ] **Step 4: Run tests**

Run: `flutter test test/domain/auth test/domain/user test/data/local_cache_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/domain/auth lib/domain/user lib/data/local_cache.dart test/domain/auth test/domain/user test/data
git commit -m "feat: add PIN, user snapshot, sync merge, and local cache"
```

---

### Task 6: UserRepository 抽象 + 内存假实现（Firestore 真实现同文件后半）

**Files:**
- Create: `lib/data/user_repository.dart`
- Create: `test/helpers/seed.dart`
- Test: `test/data/user_repository_test.dart`

**Interfaces:**
- Consumes: `UserSnapshot`, `LocalCache`, `mergeTimeQuota`, `mergeCoins`
- Produces: `abstract class UserRepository { Stream<UserSnapshot?> watch(); Future<UserSnapshot?> load(); Future<void> createInitial(UserSnapshot snapshot); Future<void> save(UserSnapshot snapshot); Future<void> purchase(ShopItem item); Future<void> addPendingCoins(int coins); Future<void> flushPendingCoins(); }`。`FakeUserRepository` 给 widget 测试用，数据放内存。`FirestoreUserRepository`：文档 `users/{uid}`；`purchase` 用 `FirebaseFirestore.runTransaction` 读 coins、按 `Wallet.buy(online: true)` 写回，失败不改文档。`watch()` 映射 snapshot；本地先 `LocalCache.saveSnapshot`。无网络时 `save` 只写 cache，并把时长 `usedSeconds` 写入 cache；`load` 返回 cache。禁止 UI import `cloud_firestore`。

- [ ] **Step 1: Write failing test against FakeUserRepository**

```dart
import 'package:english_app/data/user_repository.dart';
import 'package:english_app/domain/time/time_quota.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/domain/wallet/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

UserSnapshot seed() => UserSnapshot(
      uid: 'u1',
      parentPinHash: 'abc',
      child: ChildProfile(
        name: '豆豆',
        avatarId: 'avatar_1',
        wallet: const Wallet(coins: 40, ownedItemIds: {}, equipped: Equipped()),
      ),
      time: const TimeQuota(
        dailyLimitMinutes: 30,
        bonusMinutes: 0,
        usedSeconds: 0,
        usedOnDate: '2026-08-25',
      ),
    );

void main() {
  test('purchase deducts coins; failed purchase leaves coins', () async {
    final repo = FakeUserRepository(seed());
    await repo.purchase(ShopCatalog.items.firstWhere((i) => i.price == 20));
    expect((await repo.load())!.child.wallet.coins, 20);
    final before = await repo.load();
    await repo.purchase(ShopCatalog.items.firstWhere((i) => i.price == 60));
    expect((await repo.load())!.child.wallet.coins, before!.child.wallet.coins);
  });

  test('addPendingCoins then flushPendingCoins adds to cloud coins', () async {
    final repo = FakeUserRepository(seed());
    await repo.addPendingCoins(20);
    await repo.flushPendingCoins();
    expect((await repo.load())!.child.wallet.coins, 60);
  });
}
```

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/data/user_repository_test.dart`

Expected: FAIL

- [ ] **Step 3: Implement FakeUserRepository 完整行为；FirestoreUserRepository 按同一接口写**

`FakeUserRepository.purchase`：`online` 由构造参数 `bool online` 控制，默认 `true`。`flushPendingCoins` 调用 `mergeCoins`。`watch()` 用 `StreamController.broadcast`。

`FirestoreUserRepository` 构造：`FirestoreUserRepository({required FirebaseAuth auth, required FirebaseFirestore db, required LocalCache cache})`。`uid` 来自 `auth.currentUser`；未登录 `watch` 发 `null`。

购买失败（不够/已拥有）`throw ShopPurchaseException(errorKey)`，UI 显示「现在买不了，稍后再试」当 errorKey 不是 `insufficient_coins`/`already_owned` 时；那两个用中文：「金币不够」「已经买过了」。

- [ ] **Step 4: Run tests**

Run: `flutter test test/data/user_repository_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/user_repository.dart test/data/user_repository_test.dart
git commit -m "feat: add user repository with purchase and pending coins"
```

---

### Task 7: 登录、注册、建档、AuthGate

**Files:**
- Create: `lib/app/providers.dart`
- Create: `lib/features/auth/login_page.dart`
- Create: `lib/features/auth/onboarding_page.dart`
- Create: `lib/features/auth/auth_gate.dart`
- Create: `lib/app.dart`
- Modify: `lib/main.dart`
- Test: `test/widget/auth_gate_test.dart`

**Interfaces:**
- Consumes: `UserRepository.watch/createInitial`，`hashParentPin`，`UserSnapshot.avatarIds`
- Produces: 文案「登录 / 注册」「邮箱」「密码」「手机号」「验证码」「给孩子起个名字」「设置家长密码（6位）」。未登录 → `LoginPage`；已登录但 `load()==null` → `OnboardingPage`；已有档案 → `ChildHomePage`（Task 8 先放占位 `Scaffold(body: Text('首页'))`）。登录失败留在登录页，显示 Firebase 错误的中文：`user-not-found`→「账号不存在」，`wrong-password`→「密码不对」，`invalid-verification-code`→「验证码不对」，其它→「登录失败，请稍后重试」。

- [ ] **Step 1: Write widget test**

```dart
import 'package:english_app/app.dart';
import 'package:english_app/app/providers.dart';
import 'package:english_app/data/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('signed out shows login', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(FakeUserRepository.empty()),
        ],
        child: const XiaoCiXingApp(),
      ),
    );
    expect(find.text('登录'), findsWidgets);
  });
}
```

`FakeUserRepository.empty()`：`watch()` 一直 `null`。

- [ ] **Step 2: Run to verify fail**

Run: `flutter test test/widget/auth_gate_test.dart`

Expected: FAIL

- [ ] **Step 3: Implement AuthGate + LoginPage + OnboardingPage**

`main.dart`：

```dart
WidgetsFlutterBinding.ensureInitialized();
await tz.initializeTimeZones();
tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
runApp(const ProviderScope(child: XiaoCiXingApp()));
```

登录页两个 Tab：邮箱密码、手机号验证码（`FirebaseAuth.verifyPhoneNumber` / `signInWithEmailAndPassword` / `createUserWithEmailAndPassword`）。

Onboarding：`TextField` 名字；4 个头像 `ChoiceChip`（id `avatar_1`…`avatar_4`）；PIN `TextField` `keyboardType: number`，`maxLength: 6`；提交时 `isSixDigitPin` 否则提示「请输入6位数字」。`createInitial` 写入默认 `TimeQuota(dailyLimitMinutes: 30, bonusMinutes: 0, usedSeconds: 0, usedOnDate: ShanghaiClock().todayYyyyMmDd())`，`Wallet(coins: 0, ownedItemIds: {}, equipped: Equipped())`。

`userRepositoryProvider` 在 `providers.dart` 里提供 `FirestoreUserRepository`；测试 override Fake。

Firebase 配置：运行 `dart pub global activate flutterfire_cli` 然后 `flutterfire configure`，提交生成的 `lib/firebase_options.dart`、`android/app/google-services.json`、`ios/Runner/GoogleService-Info.plist`。控制台打开 Email/Password 与 Phone。Android 加入 debug SHA-1 才能测手机号。

- [ ] **Step 4: Run widget test**

Run: `flutter test test/widget/auth_gate_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart lib/app.dart lib/app/providers.dart lib/features/auth test/widget/auth_gate_test.dart lib/firebase_options.dart
git commit -m "feat: add login, onboarding, and auth gate"
```

---

### Task 8: 孩子首页、前台计时、时长锁

**Files:**
- Create: `lib/features/home/child_home_page.dart`
- Create: `lib/features/lock/time_lock_page.dart`
- Create: `lib/features/avatar/kid_avatar.dart`
- Create: `lib/app/foreground_ticker.dart`
- Test: `test/widget/time_lock_test.dart`

**Interfaces:**
- Consumes: `UserSnapshot.time`，`TimeQuota.tick`，`UserRepository.save`，`ShanghaiClock`
- Produces: 首页显示金币、`还剩 N 分钟`（`remainingMinutesDisplay`；0 秒显示「时间到了」）、三个按钮「寻宝翻牌」「消防员灭火」「打怪兽」、形象可点（进商店，Task 11 先 `Navigator` 占位页）。角落「家长」进 Task 12。`ForegroundTicker`：`AppLifecycleState.resumed` 每 1 秒 `tick(deltaSeconds: 1)`；`paused/inactive/hidden` 停表并 `save` 一次。有网每 30 秒 `save`。`isLocked` 时 `AuthGate` 叠 `TimeLockPage`（文案精确为 spec 那句），游戏和商店 `onPressed: null` 或直接不导航。时间到时若正在一局游戏：由 Task 10 的 `allowFinishCurrentPrompt` 处理；首页锁定立即生效。

- [ ] **Step 1: Widget test**

`test/widget/time_lock_test.dart` 使用 Task 6 的 `seed()` 拷贝（可抽到 `test/helpers/seed.dart` 避免复制字段）：

```dart
import 'package:english_app/app.dart';
import 'package:english_app/app/providers.dart';
import 'package:english_app/data/user_repository.dart';
import 'package:english_app/domain/time/time_quota.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/seed.dart';

void main() {
  testWidgets('locked snapshot shows lock copy and hides games', (tester) async {
    final locked = seed().copyWith(
      time: const TimeQuota(
        dailyLimitMinutes: 20,
        bonusMinutes: 0,
        usedSeconds: 20 * 60,
        usedOnDate: '2026-08-25',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(FakeUserRepository(locked)),
        ],
        child: const XiaoCiXingApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('今天的学习时间用完了，请爸爸妈妈来帮忙。'), findsOneWidget);
    expect(find.text('寻宝翻牌'), findsNothing);
  });

  testWidgets('unlocked home shows three games', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(FakeUserRepository(seed())),
        ],
        child: const XiaoCiXingApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('寻宝翻牌'), findsOneWidget);
    expect(find.text('消防员灭火'), findsOneWidget);
    expect(find.text('打怪兽'), findsOneWidget);
  });
}
```

`FakeUserRepository` 的 `watch` 发出已建档用户。`AuthGate` 在有 snapshot 且 `time.isLocked` 时叠 `TimeLockPage`。

- [ ] **Step 2: Run to fail**

Run: `flutter test test/widget/time_lock_test.dart`

Expected: FAIL

- [ ] **Step 3: Implement home, lock, ticker**

`KidAvatar`：一个 `Stack`，底图用 `Icons.sentiment_satisfied` 大图标，按 `equipped` 在头/眼/身上叠小 `Icon`（帽 `Icons.forest`、眼镜 `Icons.visibility`、衣 `Icons.checkroom`）。

Ticker 放在 `XiaoCiXingApp` 下的 `ConsumerStatefulWidget`，不要在每个页面各做一份。

- [ ] **Step 4: Run tests**

Run: `flutter test test/widget/time_lock_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/home lib/features/lock lib/features/avatar lib/app/foreground_ticker.dart test/widget/time_lock_test.dart
git commit -m "feat: add child home, foreground timer, and time lock"
```

---

### Task 9: 48 词词库 + 音频口

**Files:**
- Create: `lib/data/word_bank.dart`
- Create: `lib/data/word_audio_player.dart`
- Create: `assets/audio/beep.mp3`（极短占位音，可用任何合法 mp3，体积 < 20KB）
- Modify: `pubspec.yaml` 声明 `assets/audio/`
- Test: `test/data/word_bank_test.dart`

**Interfaces:**
- Consumes: `Word`
- Produces: `List<Word> kWordBank` 长度 48；`category` 只能是 `animals` `food` `colors` `home`，每类 12。`abstract class WordAudioPlayer { Future<void> play(String assetPath); Future<void> dispose(); }`；`SilentWordAudioPlayer` 空实现供测试；`JustAudioWordPlayer` 用 `just_audio` 播 `AssetSource`。

48 词固定如下（id = `{category}_{en}`）：

- animals: cat 猫, dog 狗, bird 鸟, fish 鱼, rabbit 兔子, elephant 大象, monkey 猴子, tiger 老虎, bear 熊, duck 鸭子, frog 青蛙, horse 马
- food: apple 苹果, banana 香蕉, bread 面包, milk 牛奶, egg 鸡蛋, rice 米饭, cake 蛋糕, juice 果汁, chicken 鸡肉, corn 玉米, cheese 奶酪, cookie 饼干
- colors: red 红色, blue 蓝色, yellow 黄色, green 绿色, orange 橙色, purple 紫色, pink 粉色, black 黑色, white 白色, brown 棕色, gray 灰色, gold 金色
- home: bed 床, chair 椅子, table 桌子, door 门, window 窗户, lamp 灯, cup 杯子, book 书, bag 包, shoe 鞋, hat 帽子, clock 钟

`iconCodePoint` 用接近的 Material Icons codePoint（猫 `Icons.pets` 等），允许同类词共用同一 icon。

- [ ] **Step 1: Test**

```dart
test('word bank has 48 words, 12 per category', () {
  expect(kWordBank, hasLength(48));
  for (final c in ['animals', 'food', 'colors', 'home']) {
    expect(kWordBank.where((w) => w.category == c), hasLength(12));
  }
  expect(kWordBank.map((w) => w.id).toSet(), hasLength(48));
});
```

- [ ] **Step 2: Run to fail**

Run: `flutter test test/data/word_bank_test.dart`

Expected: FAIL

- [ ] **Step 3: Implement `kWordBank` 完整 48 条 + audio 接口**

- [ ] **Step 4: Run tests**

Run: `flutter test test/data/word_bank_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/word_bank.dart lib/data/word_audio_player.dart assets pubspec.yaml test/data/word_bank_test.dart
git commit -m "feat: add 48-word bank and audio player port"
```

---

### Task 10: 游戏会话（中途锁）+ 三款主题页

**Files:**
- Create: `lib/features/games/game_session.dart`
- Create: `lib/features/games/treasure_page.dart`
- Create: `lib/features/games/firefighter_page.dart`
- Create: `lib/features/games/monster_page.dart`
- Test: `test/widget/game_session_test.dart`

**Interfaces:**
- Consumes: `QuizEngine.start`，`kWordBank`，`WordAudioPlayer`，`UserRepository.addPendingCoins` / `flushPendingCoins`，`TimeQuota.isLocked`
- Produces: `GameSession` 参数 `QuizKind kind`。开始时 `Random()` 抽题。`submitAnswer`/`flip` 之后：若 `roundComplete` 则 `addPendingCoins(engine.coinsEarned)`，有网则 `flushPendingCoins`，写 `gameStats` 对应 lastScore，`Navigator.pop`。若本则答完后 `time.isLocked` 为 true：**不再出新题**，结算已得金币，然后进锁（pop 回首页由 AuthGate 盖锁）。消防员页：进入每题调用 `play(prompt.audioAsset)`；选项是 4 个图标按钮。打怪兽：大图标 + 4 个英文词。寻宝：12 张 `GridView`，`isImage` 显示 Icon，否则显示 `en`。答对/错用 `SnackBar` 或短动画：消防员答对显示「灭火！」；打怪兽答对显示「击中！」；翻牌配错牌翻回（引擎已处理状态）。

- [ ] **Step 1: Widget test with Fake repo and 10-word bank override**

用 `ProviderScope` 覆盖 `wordBankProvider` 为 Task 2 的 `bank10()`。`FakeUserRepository` 金币 0。pump `TreasurePage`，点两张同 `wordId`（通过 `ValueKey('card_$index')`），直到 `isComplete`，`expect` `load().child.wallet` 经 pending flush 后 coins > 0。听音模式：fake audio 记录 `play` 被调用。另测：`usedSeconds` 已满时进入页，答完当前题（测试里直接 `submitAnswer` 一次）后出现锁屏文案、没有下一题按钮。

实现时给 pick 模式选项 `Key('choice_${word.id}')`。

- [ ] **Step 2: Run to fail**

Run: `flutter test test/widget/game_session_test.dart`

Expected: FAIL

- [ ] **Step 3: Implement three pages + session controller**

首页三个按钮 `Navigator.push` 对应三页。主题背景色不同：翻牌琥珀色、消防红色、怪兽深紫色。不要用 Flame。

- [ ] **Step 4: Run tests including previous widget tests**

Run: `flutter test test/widget`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/games test/widget/game_session_test.dart lib/features/home/child_home_page.dart
git commit -m "feat: add three themed quiz games with mid-round time lock"
```

---

### Task 11: 换装商店

**Files:**
- Create: `lib/features/shop/shop_page.dart`
- Modify: `lib/features/home/child_home_page.dart`（点形象进商店）
- Test: `test/widget/shop_page_test.dart`

**Interfaces:**
- Consumes: `Wallet.buy/equip/unequip`，`UserRepository.purchase`，`FakeUserRepository(online: false)`
- Produces: 列出 9 件，显示 `nameZh` 与价格。购买成功立即 `equip`。失败：offline 或异常 → SnackBar「现在买不了，稍后再试」；`insufficient_coins` →「金币不够」；`already_owned` → 按钮改为「穿上/脱下」不再购买。离线只能穿已拥有的。顶部 `KidAvatar` 即时反映 `equipped`。

- [ ] **Step 1: Widget test**

金币 40 的用户打开商店，点「红帽子」`Key('buy_hat_20')`，expect 金币 20 且形象侧出现帽子标记。`online: false` 点购买仍 40 金币并出现「现在买不了，稍后再试」。

- [ ] **Step 2: Run to fail**

Run: `flutter test test/widget/shop_page_test.dart`

Expected: FAIL

- [ ] **Step 3: Implement shop page**

- [ ] **Step 4: Run tests**

Run: `flutter test test/widget/shop_page_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/shop test/widget/shop_page_test.dart
git commit -m "feat: add dress-up shop with online purchase"
```

---

### Task 12: 家长区（PIN、限额、加时、改账号、重置 PIN）

**Files:**
- Create: `lib/features/parental/parent_gate.dart`
- Create: `lib/features/parental/parent_zone_page.dart`
- Modify: `lib/features/home/child_home_page.dart` 角落入口
- Test: `test/widget/parent_zone_test.dart`

**Interfaces:**
- Consumes: `PinGate`，`TimeQuota.setDailyLimitMinutes/addBonusMinutes`，`hashParentPin`，Firebase `reauthenticateWithCredential` / `updateEmail` / `updatePassword` / 手机号换绑走 `verifyBeforeUpdateEmail` 或重新 `verifyPhoneNumber`
- Produces: 入口按钮文案「家长」，`Key('parent_entry')`。先 6 位键盘；错 5 次显示「请 1 分钟后再试」。区内：今日已用「已用 X 分钟」（`usedSeconds ~/ 60`）、限额四个 `ChoiceChip` 20/30/45/60、按钮「加时 10 分钟」、修改邮箱/手机表单、重置 6 位密码（先 Firebase 重新登录：邮箱重输密码或手机重输验证码，再设新 PIN）。加时后 `isLocked` 为 false，锁消失。忘记 PIN：家长区登录页链到「忘记家长密码」→ 同一套 Firebase 再验证 → 设新 PIN。

- [ ] **Step 1: Widget test**

未锁用户，点家长，输入错误 PIN 一次仍在门；输入正确 PIN 看到「加时 10 分钟」。第二例：locked snapshot，家长 PIN 通过后点加时，`find.text('今天的学习时间用完了，请爸爸妈妈来帮忙。')` 消失。

- [ ] **Step 2: Run to fail**

Run: `flutter test test/widget/parent_zone_test.dart`

Expected: FAIL

- [ ] **Step 3: Implement gate + zone；限额变更 `save` 到 repository（Firestore 实时，另一设备 `watch` 更新）**

远程改小限额：`watch` 收到新 `dailyLimitMinutes` 后 `mergeTimeQuota`；若 `isLocked` 且正在游戏，GameSession 在当前 `submitAnswer`/`flip` 的配对完成（翻牌要等第二张）后结束。在 `game_session.dart` 里听 `snapshot.time.isLocked`：若 true 且当前题已有反馈，结束回合。

- [ ] **Step 4: Run `flutter test`**

Expected: 全部 PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/parental test/widget/parent_zone_test.dart lib/features/games/game_session.dart
git commit -m "feat: add parent PIN zone, remote time limits, and extra time"
```

---

### Task 13: Firestore 规则 + 离线上报失败行为

**Files:**
- Create: `firebase/firestore.rules`
- Modify: `lib/data/user_repository.dart`（save 失败不抛给孩子改额度：catch 后只保留本地 usedSeconds）
- Test: `test/data/user_repository_save_failure_test.dart`

**Interfaces:**
- Consumes: `UserRepository.save`
- Produces: rules：

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

`FailingSaveRepository` 继承 Fake，`save` throw；`ForegroundTicker` 或 repo 包装后 `usedSeconds` 仍增加。测试：tick 后 load 本地 usedSeconds 变大。

部署规则（需已登录 Firebase CLI）：

```bash
firebase deploy --only firestore:rules
```

未安装 CLI 则在 Firebase 控制台粘贴同一段规则。这一步不阻塞测试。

- [ ] **Step 1: Write save-failure test**

构造 `FakeUserRepository` 带 `saveShouldFail: true`，调用 `save` 后 `LocalCache.load` 仍有新的 `usedSeconds`。

- [ ] **Step 2: Run to fail if cache-on-failure 未写**

Run: `flutter test test/data/user_repository_save_failure_test.dart`

- [ ] **Step 3: Implement cache-first save；catch 网络错误**

- [ ] **Step 4: Run `flutter test`**

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add firebase/firestore.rules lib/data/user_repository.dart test/data/user_repository_save_failure_test.dart
git commit -m "feat: add Firestore rules and offline time save"
```

---

### Task 14: 手工验收清单（不写代码则勾选执行）

**Files:** 无强制代码。若真机发现缺陷，修在对应模块并补回归测试。

- [ ] **Step 1: Android 真机/模拟器**

登录（邮箱与手机号各一次）→ 建档 → 打完三局游戏 → 金币增加 → 买一件并穿上 → 把限额调到 20 并玩到锁 → 家长加时解锁。

- [ ] **Step 2: 两台设备**

设备 A 家长改 20 分钟；设备 B 孩子端数秒内限额变化。飞行模式玩到锁，恢复网络后 A 看到接近的已用时长。

- [ ] **Step 3: iOS 同一条主路径**

- [ ] **Step 4: 购买失败**

关网点未拥有商品，金币不变，出现「现在买不了，稍后再试」。

- [ ] **Step 5: Commit 仅当有 bugfix**

无代码改动则不空提交。

---

## Self-review notes

规格覆盖：TimeQuota、三种题型与主题外壳、金币与 9 件换装、PIN 与家长区、Firebase 登录与 `users/{uid}`、本地缓存与合并、前台计时、时长锁文案、中途锁、离线玩/不能买、上报失败不加时、规则单测与界面测、真机清单。未做项与 spec 非目标一致。

类型名锁定：`TimeQuota`、`QuizEngine`、`QuizKind`、`Wallet`、`ShopCatalog`、`UserSnapshot`、`UserRepository`、`PinGate`、`mergeCoins`、`mergeTimeQuota`、`LocalCache`。后续任务不得改名。
