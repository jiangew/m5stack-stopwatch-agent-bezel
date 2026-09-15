# Navigation pacing and Hermes window activation repair

## Evidence

User observed quick consecutive swipes being missed. Decoder imposed 800ms
between every accepted action and dropped intervening presses, not queued them.
SUPER worked in the controlled one-second test. In Hermes, both watch gestures
and physical Control-Tab failed before clicking; clicking only the window title
bar restored physical keyboard behavior. This implicates window activation,
not solely process-targeted event submission. Exact macOS/app internal cause
remains unobserved.

## Candidate 0.1.4, build 5

- Reduce only dedicated SUPER/Hermes navigation cooldown to 350ms, retaining
  matching-release gating and the longer 800ms interval on either side of a
  cycle/launch/native action. Keep 30ms stroke pacing and no input queue.
- Central Hermes opening additionally requests window-level focus for its exact
  foreground identity. Only focused/main handles and focus state are accessed;
  no contents, titles, window list, clicks, global keys or app configuration.
- Failed focus does not declare navigation ready; existing timeout/manual retry
  applies. Home, external switching and late callbacks preserve cancellation.
- No firmware, protocol, LaunchAgent or SUPER activation changes.

## Validation

Both new regressions failed against the prior implementation. Current-source
Swift harness passes 82 test bodies with warnings as errors, not XCTest.
Physical repair is **unverified** until installed and tested without clicking.
Compare SUPER rapid browse and Hermes down/down/up/right, verify four-page cycle,
no duplicate actions, no stuck Control, no background Codex actions and quota.
Retain the installed signed Companion backup; no firmware rollback is needed
for this Companion-only candidate. No merge or push.
