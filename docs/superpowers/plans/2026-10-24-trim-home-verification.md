# Home roster and desktop-cycle candidate verification

Status: source/build candidate only; not installed or physically accepted.

## Behavior

- Retired from the live Home roster: Jazz, Hotrod, Soundwave, Skywarp.
  Six Autobots, six Decepticons and the default Bumblebee portrait remain.
  Historical source images remain available for provenance; live embedding is
  exactly 13 idle images and 14 response images.
- Desktop cycle: Home → Codex → DSH → Super → Home. Hermes notifications are also retired by the follow-up;
  legacy workspace protocol parsing remains for compatibility; a Hermes foreground app cannot
  replace the selected watch desktop. Companion candidate is 0.1.4 build19.
- The user's final reproduction was the last Agent → Home transition. Both
  the drawing tail and loop cleanup previously freed the entire idle bank.
  Awake page changes now release only action buffers, retaining the bounded
  2.23 MiB idle pixel bank. Actual sleep eviction and Home IMU-wake retention
  remain as before. Cold boot or a fully evicted sleep cache still needs decode.
- Press/movement classification no longer waits for redundant Home painting.
  A sent online Home-left skips outgoing Home frames while awaiting the host;
  an offline left keeps its connection feedback visible.
- Released page swipes use a 200ms cooldown; other cooldowns, matching-release
  gating, foreground ownership and explicit center-launch requirements remain.

## Evidence

- Roster membership/reachability test failed against the old roster, then
  passed with both six-role pools and no immediate same-role repetition.
- Actual gesture-function regression failed when an injected 65ms repaint ran
  before sending Home-left, then passed after moving painting off that path.
- Actual loop cache-policy regression failed when idles were freed; 20 awake
  Agent/Home returns now perform zero additional JPEG decodes and free actions.
- Independent review found the second eviction site in `drawScreen()`. A real
  M5GFX Sprite subclass counting JPEG decodes reproduced that failure, then
  passed across Codex/DSH/Super → Home after both eviction sites were fixed.
- Native UI, canvas, draw, gesture, launch, IMU continuity, haptic and
  notification firmware regressions passed. The twelve surviving idle native
  Home images match the accepted preview pixels exactly.
- Standalone Swift decoder/cycle/coordinator regression passed, including
  released 250ms mixed native/dedicated swipes, rejected-press rearming,
  non-page cooldown, no automatic launch, Hermes isolation and stale timers.
- Notification bridge: 15 tests; adapters: 45 Python and 32 Node tests passed.
  Native idle-art tests: 6 passed; action-art tests: 3 passed and 1 skipped
  because private raw image-generation originals are intentionally untracked.
- Native preview, standard firmware, selected USB-mic/Home-IMU firmware and
  release Companion builds passed. Independent focused review approved the
  corrected cache policy and navigation changes.
- Full SwiftPM XCTest was unavailable because this Mac has Command Line Tools
  without XCTest. This is not counted as a passing test suite. Standalone
  regression compiles the same production components without XCTest.

## Pending device acceptance

Install the paired firmware and Companion candidates using the normal exact
port, app-only backup/readback/protected-area gates. Confirm the four-page
cycle, all remaining roles, Home-return speed, notification OPEN/BACK,
Home tilt, Agent controls, USB microphone and reconnect behavior on C152.
No measured physical latency improvement is claimed by these host regressions.

## Follow-up: retire Hermes notifications

Supported notification sources are now Codex, DSH and Super. The Hermes collector
plugin and OPEN routes are removed. New Hermes events are rejected by Python,
Companion and firmware. Durable queue loading validates legacy Hermes records
only for migration, removes them before presentation, preserves other sources
and nextID, and saves the filtered queue. Old Hermes route records are skipped
on read and safely retired under the exclusive inventory lock before publication
or native owner acquisition, including a full inventory of 256 old routes.
These changes are still candidate-only and are not installed.

Follow-up verification: 44 Python adapter tests and 32 Node tests passed;
standalone Swift migration keeps Codex/DSH/Super IDs and nextID unchanged while
rejecting new Hermes ingress. Notification firmware regressions, native preview,
standard and selected USB-mic/IMU firmware builds, and release Companion build
passed. Focused review approved the full-inventory migration correction.
The pinned external DSH native contract was not run (no DSH_NATIVE_MODULES supplied).
