# 実装メモ: 旧友イベントと背景付きプロローグ

## 実装日
2026-06-28

## 変更概要
- プロローグ画面に C の灯火港の戦闘背景 `battle_bg_root_c` を表示。
- 中心部へ進む節目で、マップ詳細（戦闘前画面）に入る前に旧友イベントを挿入。
- 旧友イベントの背景には、進入先エリアの戦闘背景を使用。
- 背景には暗幕・ぼかしを追加せず、セリフ枠のみを重ねる。
- 旧友イベントは既読管理し、同じイベントは一度だけ表示。

## 発生タイミング
- 初めて二音エリアへ入る前: `oldFriendFirstContact`
- 初めて四音エリアへ入る前: `oldFriendNotSeeing`
- 初めて六音エリアへ入る前: `oldFriendRepetition`
- 初めて無音の核へ入る前: `oldFriendAbandonedPath`

## 画面遷移
```text
マップでエリア選択
↓
未読イベント判定
↓
未読なら StoryEventPagerView
↓
マップ詳細（戦闘前画面）
↓
戦闘開始
```

## 主な変更ファイル
- `IntervalBattleMVP/ContentView.swift`
  - `StoryEventID`
  - `StoryEvent`
  - `StoryEventPagerView`
  - `openMapDetailWithStory`
  - 既読イベントの `@AppStorage` 管理
- `IntervalBattleMVP/GameModel.swift`
  - `AppScreen.storyEvent` 追加
  - `battleBackgroundAssetName(for:)` 追加
  - 進行状況リセット時に旧友イベント既読もリセット
