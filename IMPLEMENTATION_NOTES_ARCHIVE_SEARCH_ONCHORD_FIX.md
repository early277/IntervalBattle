# 書庫検索・オンコード・MapInfoPanel修正メモ

## 修正内容

- `MapInfoPanel` で `game` がスコープ外になる問題を修正
  - `@ObservedObject var game: GameModel` を追加
- 書庫のコード・スケール表示に分類検索を追加
  - 左側分類（マイナス側）を `指定なし / 0 / -1 ... -6` で検索
  - 右側分類（プラス側）を `指定なし / 0 / +1 ... +6` で検索
  - 両方を指定すると完全一致検索
- オンコード・転回形を追加
  - C/E, C/G, Cm/E♭, C7/B♭ など、選択中オーラに応じて表記が変わる
- トライトーン分類ロジックは前回方針を維持
  - トライトーン以外でプラス/マイナスを比較し、優勢側に±6を寄せる
  - 同数の場合は±6両方扱い

## 確認

- `swiftc -parse GameModel.swift ContentView.swift IntervalBattleMVPApp.swift` 通過
