# 本実装フェーズ開始メモ

## 現状
MVPとして以下は確認済み。
- ルートオーラ × インターバル敵の基本戦闘
- 地図進行
- 宝玉による技・特性
- 武器カスタム
- 平均調律による潜在解放
- 無音の核の3段階演出
- エリア説明画面
- 特訓・攻略の分離

## 本実装で優先する順序

### 1. ビルド安定化
- `private` 参照、SwiftUI型推論、Assets保存エラーを潰す
- XcodeのSigning Team設定
- DerivedData削除とディスク空き容量確保

### 2. 画面構成の固定
- タイトル
- プロローグ
- マップ
- エリア説明
- 武器カスタム
- 戦闘
- クリア結果
- 無音の核イベント

### 3. ゲームデータの整理
技・特性・宝玉・エリア報酬を、将来的にはSwiftコード直書きからデータ定義へ分離する。

候補:
- `GemData.swift`
- `AreaData.swift`
- `StoryData.swift`

### 4. 戦闘ロジックの整理
- 出題デッキ
- 平均調律
- 潜在解放
- 技効果
- 特性効果
- 無音の核3段階

### 5. アセット整理
- 敵画像
- マップ背景
- 戦闘背景
- 宝玉アイコン
- UI効果音
- BGM

### 6. App Store提出前整理
- アプリ名・サブタイトル
- 概要文
- スクリーンショット
- プライバシーポリシー
- TestFlight確認

## 今回の修正
- `ContentView.swift` から `private clearedFinalCore` を直接参照していたためビルドエラー。
- `GameModel` に読み取り専用の `isFinalCoreClearedForView` を追加。
- `ContentView.swift` 側は `game.isFinalCoreClearedForView` を参照するよう修正。
