# IMPLEMENTATION_NOTES_GENERATED_BGM

## 実装概要

音声ファイルを追加せず、Swift側で短い単音を生成するBGM機能を追加した。
BGMは小音量・低密度を前提とし、戦闘中のインターバル判断を妨げにくい設計にしている。

## 追加・変更点

- `GeneratedBGMMode` を追加
  - `map`
  - `event`
  - `battle`
  - `silentCore`
- `GeneratedBGMContext` を追加
- `GeneratedBGMManager` を追加
  - `AVAudioEngine` + `AVAudioPlayerNode` で単音バッファを生成
  - 外部音源ファイル不要
  - 根音へ戻りやすい重みづけランダム
  - 前回音が根音から離れている場合、次に根音・五度へ戻りやすくする
  - 休符を多めに入れる
  - 長めの音価を中心にする
  - 戦闘中は特に小音量・低密度
  - 無音の核ではほぼ無音に近い疎な音にする
- `ContentView` に画面ごとのBGM切替を追加
  - タイトル・マップ・詳細・カスタム・書庫: map BGM
  - プロローグ・旧友イベント: event BGM
  - 通常戦闘: battle BGM
  - 無音の核: silentCore BGM
  - 無音稽古: BGM停止
- マップ画面に `BGM ON/OFF` ボタンを追加
  - `@AppStorage("IntervalRouteMVP.generatedBGMEnabled.v1")` で保存

## 音量方針

- マップ: `0.030`
- イベント: `0.022`
- 戦闘: `0.014`
- 無音の核: `0.010`

かなり小さめに設定している。

## 注意

この環境では `swiftc -parse` による構文チェックのみ実施。
Xcode / 実機での音量バランス確認は別途必要。
