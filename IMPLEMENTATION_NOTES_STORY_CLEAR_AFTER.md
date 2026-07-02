# Story / Clear-after Implementation Notes

## Source specs

- 音環島の調律_ストーリー変更点まとめ.docx
- 音環島の調律_クリア後機能仕様まとめ.json

## Implemented story direction

- Reframed the title/prologue around: 見えないまま、戻りながら進む。
- Revised prologue so the protagonist is not treated as gifted or able to see sound.
- Adjusted father dialogue toward 戻る・数える・選び直す.
- Adjusted old friend dialogue so he first assumes the protagonist is one of the 見える者, then realizes the protagonist is 見えていない.
- Revised final core map text, battle story text, mid-fight intermission text, and ending text.
- Removed final-core gem reward expectation; final core now unlocks clear-after features.

## Implemented clear-after direction

- Added post-clear map buttons:
  - 無音稽古
  - 音環譜庫
- These buttons appear after final_core is cleared.
- Added lightweight info screens for both features.
- These screens are currently specification/direction screens, not the full training/archive implementations.

## Compile check

- `swiftc -parse IntervalBattleMVP/GameModel.swift IntervalBattleMVP/ContentView.swift IntervalBattleMVP/IntervalBattleMVPApp.swift` succeeded in the sandbox.
