# chordRootOffset compile fix

- `HarmonyExample` に明示的な initializer を追加。
- `chordRootOffset` を任意引数として扱えるようにし、通常コードは省略可能、オンコード・転回形だけ指定可能にした。
- `swiftc -parse` による構文確認済み。
