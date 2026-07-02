# ローカライズ残項目クリーンアップ

## 反映内容

- 記録タブ内のサブタイトルで `.gameLocalized` が付いていなかった箇所を修正。
  - `RecordRadarSection`
  - `RecordGridSection`
- バトル上部・終了表示・マップノードの短い状態表示を追加ローカライズ。
  - `地図`
  - `CLEAR`
  - `DEFEAT`
  - `OPEN`
  - `LOCK`
  - `LEVEL UP`
- 日本語 `Localizable.strings` の値側に、韓国語・英語が混入していた項目を修正。
  - 日本語ファイルは原則として `key = key` に戻した。
- 響き辞典の「読み」欄で、日本語の音訳・カタカナ読みが英語／韓国語側に不自然に反映されていた項目を修正。
  - 英語は `Add Nine`, `Minor Seven`, `Major Seven` などの英語音楽表記へ整理。
  - 韓国語は `애드 나인`, `마이너 세븐`, `5도 베이스` などの韓国語表記へ整理。
- 韓国語の響き説明文に残っていた英語混じりの説明文を追加修正。
- 動的生成文のフォールバックを補強。
  - `調律HP +N`
  - `調律MP +N`
  - `CLEAR / DEFEAT / OPEN / LOCK / LEVEL UP`

## 確認

- `plutil -lint` 通過。
- `swiftc -parse IntervalBattleMVP/*.swift` 通過。

## 未確認

- 実機での全画面目視確認。
- App Store Connect 上のメタデータ入力確認。
