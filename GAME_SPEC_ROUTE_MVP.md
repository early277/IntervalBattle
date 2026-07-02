# GAME SPEC - Route MVP

## 構造

外周に12拠点を五度円順に配置する。

C -> G -> D -> A -> E -> B -> G♭ -> D♭ -> A♭ -> E♭ -> B♭ -> F

各拠点には以下を置く。

- 拠点: 特訓モード
- 洞窟: 攻略モード

## 特訓モード

父が仮想敵を映す。  
仮想敵は攻撃しない。  
HP/MPの危険なし。  
目的は鍵盤対応の記憶。

## 攻略モード

実体化した響きの獣と戦う。  
攻撃ゲージが満タンになると被弾。  
HPが0になると敗北。

## HP/MP

HPは数値とゲージ。  
敵の攻撃ダメージには幅がある。

MPは技で使用する。

## 技

- 減速: 攻撃ゲージを遅くする
- 二分聴: 正解を含む6候補を表示
- 四分聴: 正解を含む3候補を表示
- 直観: 正解だけを短時間表示

## 中心

6拠点攻略で通常の無音の核。  
12拠点攻略で真・無音の核。


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
