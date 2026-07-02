# 響き一覧固定13列 コンパイル修正

## 修正内容

`ContentView.swift` の `listRow(for:itemAura:) -> some View` 内で、先頭に `let tonesByCircle = ...` を置いた後、`HStack` を暗黙返却していたため、Xcode の型推論で以下のエラーが発生していました。

- Function declares an opaque return type, but has no return statements in its body from which to infer an underlying type
- Result of call to 'onTapGesture(count:perform:)' is unused

Swift の `some View` を返す関数で、ローカル変数宣言を含む場合は、返す View に明示的な `return` が必要です。

## 対応

`listRow(for:itemAura:)` の `HStack` の前に `return` を追加しました。

```swift
return HStack(alignment: .center, spacing: 3) {
    ...
}
```

## 確認

- `swiftc -parse IntervalBattleMVP/*.swift` 通過
