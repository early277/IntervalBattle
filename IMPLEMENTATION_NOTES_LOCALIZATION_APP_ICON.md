# Localization and App Icon Implementation

- 添付画像を `Assets.xcassets/AppIcon.appiconset` に登録した。
- ターゲットの `ASSETCATALOG_COMPILER_APPICON_NAME` を `AppIcon` に設定した。
- ホーム画面名を言語別に設定した。
  - ja: `音環島`
  - en: `Soundring`
  - ko: `소리고리섬`
- App Store名の採用案を整理した。
  - ja: `音環島の調律`
  - en: `Tuning Soundring Isle`
  - ko: `소리고리섬의 조율`
- `Localizable.strings` を `ja/en/ko` に追加した。
- 主要な固定UI、プロローグ、旧友イベント、最終イベント、基本ボタン、主要ゲーム用語を英語・韓国語へ一次ローカライズした。
- 動的に表示される一部の `String` について `gameLocalized` を通して翻訳されるようにした。

注意:
- 響き辞典・宝玉詳細・一部の自動生成文は、完全翻訳ではなく日本語フォールバックを残している。
- 今後、`Localizable.strings` にキーを追加・上書きすれば翻訳範囲を広げられる。
