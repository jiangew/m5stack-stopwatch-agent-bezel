# Trim Home roster and streamline workspace cycling

User-approved scope: remove Jazz, Hotrod, Soundwave and Skywarp from Home;
remove the standalone Hermes desktop; improve left-swipe responsiveness.

## Design and boundaries

- Up chooses among BumblebeeFullbody, Optimus, Wheeljack, Hound, Ironhide,
  Ratchet. Down chooses among Megatron, Starscream, Shockwave, Thundercracker,
  Blitzwing, Astrotrain. Keep default Bumblebee and same-faction nonrepetition.
- Cycle Home → Codex → DSH → Super → Home. Keep Hermes notification collection
  and OPEN support. Preserve existing workspace protocol enum ordinals and
  compatibility parsers; only remove Hermes from the selectable page sequence.
- The HID decoder currently suppresses left swipes for 800ms. Verify with a
  deterministic released-gesture trace, then use a 200ms page-cycle cooldown.
  Keep matching-release gating, origin validation, launch protection and other
  navigation cooldowns. Do not replace host-authoritative screen selection with
  an optimistic local page change.
- Source changes and native simulation cannot establish physical latency.
  No installation, permission reset or firmware flashing in this implementation
  step. Prepare builds/previews; retain exact-port and app-only deployment gates.

- Follow-up physical observation narrowed the delay to the last Agent → Home
  transition. Both `drawScreen()` and loop cleanup discarded the idle bank.
  Keep 13 idle sprites warm across awake Agent pages, release only action
  sprites there, and retain full eviction for actual sleep. Existing automatic
  Home IMU wake retention is unchanged. The idle pixel bank is bounded at
  13 × 300 × 300 × 2 bytes (about 2.23 MiB PSRAM, excluding sprite overhead).
- A second improvement removes synchronous press/cancellation repaints before
  raw movement classification/transport. Dirty tap feedback still paints at the
  end of the same loop; only an online Home-left awaiting its host page skips
  the outgoing Home frame. Offline connection feedback must remain visible.

## Execution

- [x] Add failing roster membership/reachability, four-page cycle and fast
  released-left tests. Run each against the current implementation.
- [x] Reduce enum/art embedding/pose lists and selector pools; adjust affected
  native preview and regression fixtures. Keep surviving source pixels intact.
- [x] Remove Hermes from workspace cycling, preserving legacy wire decoding
  and notification paths. Ensure background Hermes cannot select a desktop.
- [x] Change page-cycle cooldown to 200ms; retain duplicate press, release,
  stale-origin, non-page debounce, center-launch and disconnect guards.
- [x] Run C++ selector/render/input regressions, Swift decoder/cycle/coordinator
  tests and notification regressions. Build native/default/selected USB-mic IMU
  firmware and Companion without installing them.
- [x] Produce a remaining-role native preview and record measured software
  results separately from pending physical acceptance.
