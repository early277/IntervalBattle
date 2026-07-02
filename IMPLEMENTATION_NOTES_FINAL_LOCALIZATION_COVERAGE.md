# 最終ローカライズ補強メモ

## 反映内容

- `en.lproj/Localizable.strings` と `ko.lproj/Localizable.strings` の値側に残っていた日本語フォールバックを解消。
- 物語文、父の台詞、旧友イベント、最終イベント、地図・洞窟説明、手帳・記録説明の未翻訳分を追加翻訳。
- 動的生成される文言のローカライズ補強。
  - 「○○：稽古」
  - 「○○：攻略」
  - 「○○ から」
  - 「右へN」「左へN」「右へN / 左へN」
  - 父の助言文
  - 正解／不正解時の戻り指示
  - 五度環距離表示
  - 直前回答秒数
  - HP/MP上昇表示
- `ContentView.swift` 内の主要な直接表示テキストを `gameLocalized` / `GameLocalization.format` に寄せ、SwiftUI任せの箇所を減らした。
- `GameLocalization.swift` に動的フォールバックパターンを追加。
- `.strings` のエスケープを整え、改行・引用符を `plutil` で検査可能な状態に整理。

## 確認

- `plutil -lint` 通過
  - `ja.lproj/Localizable.strings`
  - `en.lproj/Localizable.strings`
  - `ko.lproj/Localizable.strings`
  - 各 `InfoPlist.strings`
- `swiftc -parse IntervalBattleMVP/*.swift` 通過。
- 英語・韓国語の `Localizable.strings` / `InfoPlist.strings` の値側に日本語文字が残っていないことを確認。
- Swift内の日本語文字列リテラルが英語・韓国語の `Localizable.strings` に登録されていることを確認。

## 備考

- App Store表示名の方針は前回どおり。
  - 日本語: `音環島の調律`
  - 英語: `Tuning Soundring Isle`
  - 韓国語: `소리고리섬의 조율`
- ホーム画面名も前回どおり。
  - 日本語: `音環島`
  - 英語: `Soundring`
  - 韓国語: `소리고리섬`
