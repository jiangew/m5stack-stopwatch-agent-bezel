# Hermes window reopen verification

## Scope

Companion-only correction on `feature/hermes-tap-launch`. Hermes central tap
always requests `NSWorkspace.openApplication`, including for an already running
client, with activation enabled and new-instance creation disabled. Codex/SUPER
activation, navigation mappings, firmware, protocol and LaunchAgent configuration
are unchanged. No merge or push.

## Implementation evidence

- Added a regression test for running Hermes: one reopen request despite repeated
  taps, no activation-only call, and no operational screen until real foreground
  confirmation. The temporary harness failed at the expected assertion before
  the production change, then passed after it.
- All 61 Swift test bodies passed in the temporary harness, including timeout,
  retry, stale callbacks, external activation, routing and coordinator coverage.
  This is not a complete XCTest run.
- Release build with macOS 15.4 SDK and warnings-as-errors passed.
- Synthetic `--demo --json-only` smoke passed. Runtime mode gates are covered by
  the harness; no additional live watch was started for smoke testing.
- `swift test` with writable temporary module caches reached test compilation
  and failed with `no such module 'XCTest'` under the installed CLT.
- Diff review: only central Hermes opening opts into reopening; the same pending
  generation, deadline and foreground confirmation logic remains in use.

## Local probe and acceptance status

- Restarted the original Companion service after the user's Accessibility
  reauthorization, without changing its configuration.
- Invoked the corrected AppKit adapter in a bounded local probe: accepted=true,
  one matching Hermes process, and the existing process was reused. This proves
  request acceptance and instance reuse, **not visible window restoration**.
- Newly appended logs after restart showed no Accessibility denial or navigation
  send failure; HID attached and quota updates continued. Absence of errors alone
  does not prove navigation was exercised or permission is effective.
- User confirmation of visible window recovery and six navigation actions is
  pending. Cold-start regression and post-install physical acceptance remain
  unverified. The corrected Companion has not yet been installed.

## Remaining installation gate

If the system reopen probe does not restore the window, stop and diagnose without
window scraping, AppleScript, global key injection or Hermes configuration edits.
Otherwise back up the currently installed signed Companion, replace only its
executable, retain signing identity and restart the original service. Reauthorize
Input Monitoring/Accessibility only if needed, then verify background reopen,
cold start, instance reuse and Hermes/SUPER up/down/right with user observation
and fresh logs. Preserve the pre-install backup for a Companion-only rollback.
