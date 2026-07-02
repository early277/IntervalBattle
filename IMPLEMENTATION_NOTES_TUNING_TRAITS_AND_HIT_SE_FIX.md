# IMPLEMENTATION_NOTES_TUNING_TRAITS_AND_HIT_SE_FIX

## 実装日
2026-06-29

## 変更内容

### 1. 正解時HP/MP回復特性の復活

過去修正で未使用扱いになっていた以下4つの特性を、正解時に発動する特性として復活した。

- `tune_hp` / 宵雫律: 調律時HP回復
- `tune_mp` / 雷脈律: 調律時MP回復
- `tune_hp_risk` / 血響律: 調律時HP回復、ミス時被害2倍
- `tune_mp_risk` / 魔響律: 調律時MP回復、ミス時被害2倍

通常版は `doublingPower(level)`、リスク版は `largePower(level)` を使用する。

### 2. 正解時処理

正解時に以下を実行するように戻した。

- `recoverMP(traitTuningMPRecovery())`
- `recoverHP(traitTuningHPRecovery())`

ただし、以前のような無条件の `recoverMP(2)` は復活させていない。回復は装備中の特性によるものだけ。

### 3. 被弾時SEの軽量化

被弾時の `SoundPlayer.attack()` を、音量調整できないシステム音から、`TonePlayer` の控えめな短音へ変更した。

- 旧: `AudioServicesPlaySystemSound(1006)`
- 新: `TonePlayer.shared.playSoftHit()`

`playSoftHit()` は低音量・短時間の2音で、戦闘中の注意を奪いすぎないようにした。

## 確認

- `swiftc -parse` による構文チェック通過。
- Xcodeでの実機音量確認は未実施。
