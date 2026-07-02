# Dialog Color / Final Core Consistency / Tuning Recovery Fix

- StoryEventPagerView now derives panel color from speaker instead of per-page accent.
  - 父 and non-old-friend speakers: warm orange.
  - 父の旧友 / 旧友の声: violet.
- Final core pre-battle dialogue and phase intermissions were rewritten so the old friend no longer re-asks whether the player is a visible/special child after the prior center approach event.
- Correct answers no longer recover HP or MP.
- tune_hp / tune_mp / risk variants are made inert so residual equipped traits cannot restore HP/MP on correct answers.
- Reset now clears runtime battle state, equipped traits, story events, map focus, and battle accumulators more fully.
