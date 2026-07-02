# IMPLEMENTATION NOTES: 無音の核 初回クリアイベント

## 実装日
2026-06-28

## 目的
無音の核を初めてクリアした際に、通常のクリア表示だけで終わらせず、父の言葉を中心にしたエンディングイベントを表示する。

## 仕様

- 対象は `final_core` の初回クリア時のみ。
- 初回クリア時、`GameModel.pendingFinalCoreClearStoryEvent` を `true` にする。
- クリア画面のボタン表示を、通常時は `地図へ戻る`、初回クリアイベント待機時は `先へ進む` に切り替える。
- `先へ進む` 押下で `StoryEvent.finalCoreClearEvent` を表示する。
- 背景は `battle_bg_final` を使用する。
- イベント終了後はタイトル画面へ戻る。
- イベント終了時に、戦闘状態を閉じるため `finishFinalCoreClearStoryReturnToTitle()` を呼ぶ。

## 追加セリフの方向性

- 旧友は、見えない者にも道があったことを受け止める。
- 父は、自分が本当は信じきれていなかったことを認める。
- 主人公が「戻り、数え、選び直して」道を作ってきたことを父が言葉にする。
- 「見えないままでいい」「思うままに鳴らしていい」という解放の方向で締める。

## 変更ファイル

- `IntervalBattleMVP/ContentView.swift`
  - `StoryEventDestination` 追加
  - `StoryEventID.finalCoreClear` 追加
  - `StoryEvent.finalCoreClearEvent` 追加
  - 戦闘終了後の遷移処理 `finishBattleFlow()` 追加
  - 初回無音の核クリア時、イベント後にタイトルへ戻る分岐を追加

- `IntervalBattleMVP/GameModel.swift`
  - `pendingFinalCoreClearStoryEvent` 追加
  - `consumePendingFinalCoreClearStoryEvent()` 追加
  - `finishFinalCoreClearStoryReturnToTitle()` 追加
  - `final_core` 初回クリア時にイベント待機フラグを立てる処理を追加

## 確認

- `swiftc -parse` 通過。
- Xcode 実機ビルドは未確認。
