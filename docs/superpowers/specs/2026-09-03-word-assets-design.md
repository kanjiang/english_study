# 48 词图片与发音替换设计

日期：2026-09-03

## 目标

把小词星 MVP 中 48 个单词的占位图标和统一 `beep.mp3` 替换为逐词图片资源和逐词英语发音资源，使听音选图、看图选词和翻牌配对都使用真实资源路径。

## 资源方案

- 图片：48 张 AI 原创儿童插画，1:1 比例，浅色背景，主体居中，粗轮廓，无文字。
- 图片路径：`assets/images/words/<word_id>.png`。
- 音频：Windows 本机 Microsoft Zira Desktop 美式女声生成，语速略慢。
- 音频路径：`assets/audio/words/<word_id>.wav`。
- 所有资源按现有 `Word.id` 命名，避免在题库和资源文件之间维护额外映射。

## 代码方案

- `Word` 去掉 `iconCodePoint`，新增 `imageAsset`。
- `word_bank.dart` 为每个词绑定自己的 `imageAsset` 和 `audioAsset`。
- 游戏 UI 中所有图片展示改为 `Image.asset`。
- `pubspec.yaml` 增加 `assets/images/words/` 和 `assets/audio/words/`。

## 验收

- 48 个词仍保持 4 类各 12 个，ID 唯一。
- 每个词的图片路径唯一，音频路径唯一。
- 题库不再引用 `assets/audio/beep.mp3`。
- Widget 测试能加载词图，不再查找 Material `Icon` 作为单词图。
- `flutter test` 和 `flutter analyze` 通过。

## 已知限制

- AI 插画仍需要人工复核词义准确性。
- Zira 是系统 TTS 声音，音质可用于 MVP；正式版可替换为真人录音。
