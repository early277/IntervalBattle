# IntervalRouteMVP

縦画面・1オクターブ鍵盤・地図・特訓/攻略・HP/MP・攻撃ゲージ・技を入れたMVPです。

## 主な仕様

- 縦画面固定
- 1オクターブ鍵盤
- 五度円配置の12拠点
- 中央に「無音の核」
- 各拠点に2モード
  - 特訓: 父が映す仮想敵。攻撃なし。
  - 攻略: 実体敵。攻撃ゲージあり。
- HPは数値 + ゲージ
- MPは数値 + ゲージ
- 技
  - 減速: 攻撃ゲージを遅くする
  - 二分聴: 候補を6個に絞る
  - 四分聴: 候補を3個に絞る
  - 直観: 正解鍵を一時表示
- 敵は常に1体ずつ出現
- 攻略クリアで五度円上の隣接拠点を解放
- 6拠点攻略で通常の無音の核を解放
- 12拠点攻略で真・無音の核を解放

## Xcodeで開く

`IntervalBattleMVP.xcodeproj`

## ルール

敵本体 = インターバル  
オーラ = ルート  
正解 = ルート + インターバル


## Update: multi-aura / save / skills / root-key highlight

- Progress is saved with UserDefaults.
- Cleared dungeons and unlocked areas persist after closing the app.
- Multi-aura dungeons were added:
  - 2-aura dungeons
  - 3-aura dungeons
  - 6-aura dungeons
- Normal final battle opens after clearing a 6-aura dungeon.
- Skills:
  - 減速: slows the attack gauge.
  - 二分聴: narrows candidates to 6 keys.
  - 三分聴: narrows candidates to 4 keys.
  - 四分聴: narrows candidates to 3 keys.
  - 回復: restores HP.
- The exact-answer skill was removed.
- The current root aura key is lightly colored gray on the keyboard.


## Update: 2-4-6-12 map / persistent hint / SFX

- Multi-aura dungeons are now placed inside the map.
- Progression is now 2-aura -> 4-aura -> 6-aura -> 12-aura final.
- Candidate narrowing skills persist across enemies while their timer is active.
- When a new enemy appears during the skill duration, candidates are recalculated to include the new correct answer.
- Heal MP cost increased to 28.
- Sound effects were added using iOS system sounds.


## Update: scrollable route map / single final core

- The map is now larger than the screen and scrollable in both directions.
- Route lines connect single-aura areas, 2-aura dungeons, 4-aura dungeons, 6-aura dungeons, and the final core.
- The final core is no longer split into normal/true nodes.
- The center battle is always a 12-aura battle.
- Each multi-aura dungeon has flavor text in its BattleConfig/story and context menu.
- Node sizes were increased to reduce label overlap.


## Update: pitched audio

- Fixed Swift compile error by replacing Set.contains closure usage with contains(where:).
- Enemy spawn now plays the current root aura pitch in a lower octave.
- Keyboard tap now plays a dyad:
  - lower note = current aura/root
  - upper note = tapped keyboard note
- This is intended to help the player hear the interval relationship, not only see it.


## Build fix

- Fixed malformed @Published property declarations in GameModel.swift.
- Kept pitched audio:
  - enemy spawn plays the root aura in a lower octave
  - keyboard tap plays lower root + upper tapped note


## Update: route unlock conditions / full combinations / timing / random keys

- Route unlock is now connection-based.
  - If a cleared node is connected to a map node, that connected node opens.
  - Unconnected map nodes do not open merely because the clear count increased.
- Each dungeon now uses all combinations:
  - allowed root auras × 11 interval enemies.
- Attack time:
  - 1 aura: 12 seconds
  - 2 auras: 6 seconds
  - 4 auras: 3 seconds
  - 6 auras: 2 seconds
  - 12 auras: 1 second
- Keyboard layout:
  - 1-aura and 2-aura battles keep the normal keyboard.
  - 4-aura, 6-aura and 12-aura battles use randomized pitch positions.


## Update: shifted keyboard start

- The previous fully randomized keyboard grid was removed.
- For 4-aura, 6-aura, and 12-aura battles, the keyboard now remains a real keyboard layout.
- Only the leftmost white key is randomized.
- Possible leftmost keys: C, D, E, F, G, A, B.
- 1-aura and 2-aura battles keep the normal C-start keyboard.


## Update: 8-white-key shifted keyboard / all battles

- Removed the START label on the leftmost key.
- Shifted keyboard now displays 8 white keys instead of 7.
  - Example: E start becomes E F G A B C D E.
  - This allows missing black keys such as E♭ to appear at the right edge.
- Random keyboard start is now applied to all battles, including 1-aura and 2-aura battles.
- The map background and route colors were adjusted slightly toward an RPG-map style.


## Update: 7-white-key shifted keyboard with side black keys

- White keys are back to 7 visible keys.
- Black keys are computed cyclically, so if a side black key is needed it appears at the right edge.
  - Example: E-start shows E F G A B C D plus E♭ at the right side.
- The keyboard start is randomized every time a new enemy appears, not only once at battle start.
- This applies to training, 1-aura, 2-aura, 4-aura, 6-aura, and 12-aura battles.


## Update: left/right side black keys and skill timers

- Shifted keyboard now shows side black keys on both sides when needed.
- Skill effects now show remaining time gauges.
- Slow and candidate-narrowing durations are about doubled.
- Candidate-narrowing skills remain active across enemies as before.
- Added 二択聴: narrows candidates to 2 keys.
- Heal MP cost changed to 24.
- In training mode, candidate-narrowing skills consume no MP because virtual enemies have very low resistance to skills.


## Update: skill naming/cost and map/key readability

- Skills changed:
  - 二分聴: 6 MP, 6 candidates.
  - 四分聴: 24 MP, 3 candidates.
  - 六分聴: 98 MP, 2 candidates.
  - 三分聴 removed.
- Candidate highlights were made more subdued.
- If a key is both the aura root and a candidate, the aura background is prioritized and candidate status appears as an outline.
- Map route lines were made thinner and lighter.
- Map canvas and node spacing were increased to reduce overlaps.
- Multi-aura nodes were widened and their backgrounds strengthened so route lines do not obscure names.


## Update: route visibility and text masks

- Route line visibility was restored closer to the previous stronger style.
- Added small dark masks behind map labels.
- Area names, status text, and core labels are now less affected by route lines passing underneath.
- Node backgrounds were made more opaque while keeping their color identity.


## Update: skill gauge label names

- Candidate-narrowing effect gauges now show skill names instead of candidate counts.
  - 6 candidates: 二分聴
  - 3 candidates: 四分聴
  - 2 candidates: 六分聴


## Update: HP-adaptive order, level-up, and final depth

- Every area still contains all required combinations: allowed root auras × 11 interval enemies.
- Enemy order is adaptive within the remaining undefeated combinations.
  - High HP: prioritizes combinations with longer recorded response time and more mistakes.
  - Low HP: prioritizes combinations with shorter recorded response time and fewer mistakes.
  - The final number of enemies and combinations does not change.
- Response time and misses are stored internally per root-aura × interval combination.
- First clear of a previously uncleared area increases player level by 1.
- Level slightly increases max HP and MP.
- Final core remains 132 combinations but is displayed as three depths: 44 + 44 + 44.


## Update: field map / battle background / UI polish
- Added low-resolution pixel-style field map background and battle background.
- Skill buttons now fit without horizontal scrolling.
- Added visible level-up notification on first clear.
- Keyboard hint highlight made more subtle.
- Removed aura-key highlight from the keyboard; aura guidance is now shown near the keyboard instead.


## Update: aura label position
- Moved the aura name display from near the keyboard to directly below the enemy.
- Simplified the aura label so the player's eye can stay on the enemy area.


## Update
- Added a new skill: 根音視 (highlights the root aura note on the keyboard for a limited time).
- Enlarged the aura name below the enemy and simplified it to text only.
- Single-aura dungeon battles now reuse the older cave-like stage background.
- Multi-aura dungeons continue to use stage-specific backgrounds.
- Improved the field map background with a more RPG-like terrain feel.


## Update: map route simplification / skill row / highlight

- Vector route lines are no longer drawn because the field-map background itself shows the routes.
- Map label dark mask boxes were removed; labels now use only a subtle shadow.
- Skill buttons are back to a single row.
- Keyboard highlights were made slightly stronger.
- 6-aura areas were renamed/reframed as 六重険路: steep routes toward the 12-aura final core.


## Update: text clipping fix

- Training battles no longer show the long top story text.
- Training explanation is shown before starting the training.
- Battle flavor text uses a smaller caption and up to three lines.
- Long final/multi-stage flavor text was shortened to avoid clipping.


## Update: gauges, map memory, resonance/taitoku

- Skill effect gauges are displayed above the skill buttons with a stable height.
- Returning to the field map now scrolls back near the previously selected node.
- Locked map nodes can be tapped to show reward information, but cannot be challenged yet.
- Clear result now displays immersive resonance wording instead of S/A/B rank:
  - 体得: average response <= 0.50 sec
  - 澄響: average response <= 0.75 sec
  - 残響濃し: average response <= 1.00 sec
  - 残響あり: average response <= 1.50 sec


## Update: taitoku threshold / gems / aura label / map focus

- 体得基準を平均応答1.00秒以内に変更。
- 敵下のオーラ音名をさらに大きくし、該当オーラ色の半透明背景を追加。
- マップ復帰位置をUserDefaultsに保存し、選択地点を中央固定ではなく左上寄りに戻すよう調整。
- 20個の宝玉・技案を `GEM_SKILL_DESIGN.md` として追加。
- 未開放ダンジョンの報酬表示を、汎用名から各宝玉名へ変更。


## Update: gem upgrade system

- Added 20 gem skill definitions.
- First clear of a multi-aura dungeon obtains its gem.
- Re-clearing an already cleared multi-aura dungeon strengthens that gem up to Lv5.
- Existing battle skills now scale with related gem levels where already implemented.
- Clear resonance display avoids S/A/B rank wording.


## Update: speed-based gem strengthening and skill colors

- Re-clearing an already cleared dungeon now strengthens the gem more when average response time is shorter:
  - <= 1.00 sec: +3 levels
  - <= 1.25 sec: +2 levels
  - otherwise: +1 level
- Gem skills now include color definitions.
- Current skill buttons are color-tinted for easier selection.


## Update: gem level time thresholds

Gem strengthening now uses target level thresholds:
- First clear: Lv1
- Average <= 4.00 sec: Lv2
- Average <= 2.00 sec: Lv3
- Average <= 1.00 sec: Lv4
- After Lv4, another <= 1.00 sec clear reaches Lv5


## Build fix

- Removed a stray leftover `else if average <= 1.25` block in `GameModel.swift`.
- This fixes the parser error that caused many follow-on `Cannot find ... in scope` errors.


## Update: skill unlock flow and preserved map scroll

- Initial visible battle skill is only 減速.
- Other battle skills appear only after obtaining the matching gem.
- Empty skill slots are shown to keep the skill area stable.
- The field map now preserves the actual scroll offset while moving into and out of battles, instead of jumping back to the top-left.


## Update: weapon customization and reset confirmation

- Added a 武器カスタム screen from the map header.
- Equipped skill gems determine which battle skills appear.
- The initial equipped skill is only 減速.
- Matching gems unlock skills; up to 6 can be equipped.
- Reset progress now shows a confirmation dialog before clearing data.


## Update: initial twelfth listen

- Added 十二分聴 as an initial skill alongside 減速.
- 十二分聴 costs MP 255.
- In training, MP is not consumed, so it is mainly intended for practice confirmation.
- It narrows candidates down to 1 note.
- It is treated as a father-given initial gem/skill and cannot be removed from the weapon.


## Update: removable initial skills

- Initial skills 減速 and 十二分聴 are now removable from the weapon customization screen.
- They remain always unlocked, so they can be re-equipped later.
- Reset returns the weapon to the initial state with both equipped.


## Update: gem labels, Sanbun listen, resonance gauge

- Renamed the father-given gem to 古律の宝玉.
- Built-in gems now show 授与済 instead of 未入手.
- Added 三分聴, obtained from 二重洞 F/C, narrowing candidates to 4.
- Weapon customization cards now show where each gem is obtained.
- Removed gem-obtain wording from locked map node descriptions.
- Added a resonance gauge under MP showing average tuning time and gem level thresholds.


## Update: potential gems, debug clear, outer gems

- Clear overlay now shows average tuning seconds only, not gem/potential targets.
- Resonance gauge is moved under the HP/MP top area with fixed height.
- Long-press the battle top status area to reveal debug clear buttons.
- Weapon customization now shows cost, function, potential-stage effects, and source location.
- Added gems for all 12 single-aura outer dungeons.
- User-facing wording prefers 潜在 over 宝玉Lv.


## Update: compact customization, traits, and stealth skill

- Weapon customization is split into 技 and 特性.
- Skill cards are compact, with one-line summaries.
- Tapping a card opens a detail panel with quantitative potential effects.
- Skills and traits each have up to 6 equipped slots.
- Added 気配断ち: pauses the enemy beat for a few seconds, but the player cannot attack during it.


## Update: revised skill/trait table

- Reflected the user-revised skill and trait table.
- Initial active skills are now 十二分聴 and 根音視.
- 緩拍 is now obtained from D近郊.
- Added HP small/medium/large recovery skills.
- Updated 二分聴 / 三分聴 / 四分聴 / 六分聴 acquisition points and costs.
- 気配断ち now hides the enemy and cancels when the player presses a key.
- Added multiple passive traits: auto HP/MP recovery, tuning recovery, max HP/MP, risk traits, and beat-slow traits.


## Build fix and trait replacement

- Restored missing GameModel methods used by ContentView:
  - skillColor(_:)
  - activateEquippedSkill(_:)
- Rewrote some Button and ForEach code to avoid SwiftUI generic inference errors.
- Replaced the HP10% beat-slow trait with 延響律, which extends skill effect duration:
  - 潜在1:+2秒
  - 潜在2:+4秒
  - 潜在3:+8秒
  - 潜在4:+16秒
  - 潜在5:+32秒


## 追加修正
- ContentView.swift の `game.gemRewardText(for: dungeon)` 呼び出しに対応する `GameModel.gemRewardText(for:)` を追加
- 単独オーラ戦の背景をオーラごとの専用背景へ切り替え
  - C/G/D/A/E/B/G♭/D♭/A♭/E♭/B♭/F それぞれ専用
- 二重・四重・六重・最終戦は既存の個別背景を継続使用


## 今回の追加
- フィールドマップを同心円ごとの RPG 風レイヤー構成へ変更
  - 外周拠点帯
  - 二重洞帯
  - 四重洞帯
  - 六重険路
  - 無音の核
- 背景側に街・洞窟・遺跡・険路・核の意匠を描き込み、ノード位置と地形の対応を強化
- 単独オーラ 12 地点それぞれに固有の地名とフレーバーテキストを追加
- 単独戦・中層戦・最終戦の戦闘説明文を背景イメージに合わせて再調整


## Story update: fighting motive
- Added a prologue screen between title and map.
- The map is now framed as 音環島, an island whose center governs the concept of sound.
- The twelve outer bases maintain the island's tuning order.
- C is now Cの灯火港, the harbor town where the father trains the protagonist.
- The father initially uses 十二分聴 to guide the protagonist, then is sealed by his old friend.
- The old friend becomes/serves the 無調律の力 because of resentment toward people who can play freely and accurately.
- The protagonist's motive is to cross the island, reach 無音の核, stop the disappearance of music, and prove that anyone can reach free musical expression.


## Build fix

- Fixed ambiguous `cos` / `sin` calls in the RPG-style map background.
- Added an unlabeled initializer to `MapZoneText`, fixing `Missing argument label 'text:' in call`.


## Update: rewards and final-depth story

- Reverted the field map background toward the previous clearer version.
- Enlarged enemy display size.
- First-time gem acquisition now uses clear average time to set the initial potential.
- First-time gem acquisition now displays only the obtained gem and potential, without 共鳴 wording.
- Weapon customization header now changes by tab: skill slots on 技, trait slots and totals on 特性.
- Multi-aura and final nodes now open an explanation panel before battle.
- Area/detail panels now show reward and potential thresholds.
- Final core has three depth phases with story intermissions and a final scene where the former friend smiles and throws himself into the silent abyss.


## Update: full-screen area details

- Area clicks now transition to a full-screen detail view rather than showing an inline map panel.
- Multi-aura and final-core areas now use the same full-screen pre-battle detail flow.
- Battle flavor text is no longer shown during combat; it is shown on the pre-battle detail screen.
- Aura badge text under enemies is reduced to about 70% size.
- Reward text now includes the gem effect.
- Removed the unnecessary “初回でも平均に応じて…” wording.
- Fixed the final-core ending text persisting after clearing other areas.


## Production phase start

- Fixed `clearedFinalCore` private access from `ContentView.swift`.
- Added `GameModel.isFinalCoreClearedForView` as a read-only view-facing property.
- Added `PRODUCTION_IMPLEMENTATION_PLAN.md`.


## Update: locked rewards and final intermissions

- Cleans old equipped skill/trait settings via a data-version migration.
- Locked areas now open the full-screen detail view and show reward/effect information.
- Final core no longer tells the player there are three phases beforehand.
- Final core now pauses after each internal phase and shows dialogue before resuming.
- Final intermission dialogue no longer remains after clearing unrelated areas.


## Bug fix: trait reset and defeat overlay

- Fixed trait helper functions returning level-1 values even when a trait is not equipped.
- Reset now removes saved equipped trait/skill/gem/combo-performance keys before writing the clean default state.
- Clear-only results, gem rewards, level-up text, and final-core scenes are shown only on victory.
- Defeat now clears reward/final-scene/intermission text immediately.


## Compiler-safe rebuild v2

- Rebuilt from the last stable `trait_reset_lossfix` line instead of the dialogue branch.
- Moved all long map-detail text generation out of `MapView.body` and into `GameModel`.
- Replaced inline `MapInfo(...)` construction in `ForEach` closures with simple calls:
  - `game.auraMapInfo(aura)`
  - `game.dungeonMapInfo(dungeon)`
  - `game.finalCoreMapInfo()`
- Added area dialogue, multi-area solo rationale, and final-core pre-battle dialogue.
- Added upper-to-lower connected route unlocking.
- Moved 気配断ち to F近郊 and HP小回復 to G近郊.
- Changed user-facing wording to 宝玉レベル.
- Hides unowned items in weapon customization and fixes the equip button readability.


## Build fix: string literals

- Fixed broken newline string literals in `GameModel.rewardThresholdText` and `levelDetailLines`.
- The generated Swift source now uses escaped `\n` inside string literals instead of accidental physical line breaks.


## Update: HP/MP, reward display, and multi-area individuality

- Battle start now fills HP/MP to the current max including equipped traits.
- Max HP/MP no longer increases just because the player enters deeper areas.
- Pre-battle reward text is now shown in a larger dedicated reward detail box near the battle button.
- Reward details are grouped in the same style as the weapon customization detail panel.
- Multi-aura areas now have more individual names, lore, and dialogue.
- Four-aura areas are no longer all treated as tower-like areas.


## Update: world setting and father advice

- Applied the far-future / ancient-civilization setting.
- The island is framed as 音環島 / 屋久の環, with an ancient sound-core at the center.
- Replaced 能力者 wording with 真律者.
- Rewrote father dialogue to be warmer and less commanding.
- Removed the visible outer-area training button.
- Added father advice during outer-area battles, e.g. direction from the current root by semitones.
- Fixed broken multiline string literals in dialogue and reward-detail text.


## Update: father advice wording

- Removed the real-world technical word `半音` from user-facing father advice.
- Advice now uses keyboard/in-world wording such as `右へ○つ先の鍵` / `左へ○つ先の鍵`.


## Build fix

- Fixed `Extra argument 'rewardDetail' in call` by adding `rewardDetail` to `MapInfo`.
- Kept reward details displayed in the pre-battle detail screen.
- Rechecked newline string literals in reward detail text.


## Build fix: MapInfo.rewardDetail

- Fixed `Extra argument 'rewardDetail' in call`.
- Patched MapInfo definition to include `rewardDetail: String = ""`.
- Checked both ContentView.swift and GameModel.swift because the MapInfo struct location differed between branches.
