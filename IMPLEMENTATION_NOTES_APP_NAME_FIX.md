# App Name Fix

- アプリ表示名から `MVP` を外した。
- `INFOPLIST_KEY_CFBundleDisplayName` を `音環島の調律` に変更した。
- 進行状況の保存キーやプロジェクト内部名は互換性維持のため変更していない。

確認:
- `swiftc -parse IntervalBattleMVP/GameModel.swift IntervalBattleMVP/ContentView.swift IntervalBattleMVP/IntervalBattleMVPApp.swift` 通過。
