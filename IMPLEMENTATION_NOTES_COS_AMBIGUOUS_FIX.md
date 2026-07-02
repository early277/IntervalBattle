# cos/sin ambiguous build fix

## 変更内容

`ContentView.swift` の `RecordRadarChart.point(...)` 内で、`cos(angle)` / `sin(angle)` が `CoreGraphics` と `DarwinFoundation` の両方に解決されて Xcode ビルドエラーになる問題を修正。

```swift
CGFloat(Darwin.cos(angle))
CGFloat(Darwin.sin(angle))
```

として明示的に `Darwin` 側を指定した。

## 確認

`swiftc -parse IntervalBattleMVP/GameModel.swift IntervalBattleMVP/ContentView.swift IntervalBattleMVP/IntervalBattleMVPApp.swift` 通過。
