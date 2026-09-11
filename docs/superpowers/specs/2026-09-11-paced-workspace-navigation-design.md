# Paced workspace navigation and Hermes selection ownership

Status: interaction approved in conversation; written implementation design awaiting review.

## Evidence and scope

The user observed that physical keyboard shortcuts work. Dedicated device events
now prevent Codex background actions. After Accessibility authorization, commands
reach the process-targeted emitter but some application actions still fail.

Temporary, separately authorized diagnostic applications established:

- SUPER full modifier sequences without delay did not switch tabs; the same
  sequence with 30 ms event spacing did switch tabs.
- Hermes Control-Tab with 30 ms spacing selected and opened the next session.
- Hermes down/down/up with Control retained moved selection only; final Control
  release opened the selected session. The user observed all stages.

These results validate the diagnostic sequences, not the eventual Companion
implementation. This change is Companion-only: no firmware, HID/RPC, shortcut
mapping, application configuration or LaunchAgent changes; no merge or push.

## Chosen approach

Use complete, process-targeted modifier sequences paced without blocking the
main RunLoop. Retain Control only for the Hermes selection interaction.

Alternatives: a blocking sleep reproduces the probe but stalls the watch loop;
releasing Control after every Hermes direction opens sessions prematurely.
Neither is selected. Global input and application-content inspection remain out
of scope.

## Sequence and ownership rules

- SUPER: Control down, Option down, direction down/up, Option up, Control up.
  Previous/next project and next tab keep the existing key codes and modifiers.
- Hermes first down: Control down, Tab down/up; retain Control.
- Hermes subsequent down: Tab down/up using the retained Control state.
- Hermes up: acquire Control if necessary, Shift down, Tab down/up, Shift up;
  retain Control. Shift is never retained between gestures.
- Hermes right: release an owned Control to open selection. Without an owned
  selection, right is a no-op; it does not press Control, Return or another key.
- Ownership is limited to the exact validated Hermes process identity. No
  project, session, window or user content is observed or retained.
- Ordinary strokes are separated by at least 30 ms using a monotonic scheduling
  gate on MainActor. Timer delays may lengthen the gap; never catch up in a burst.
- Only one sequence runs at a time. Busy input is ignored, not queued for replay.
  Existing per-device release gates and 800 ms debounce remain unchanged.

## Guards and cleanup

Revalidate foreground identity, PID, bundle ID and Accessibility before starting
an action and before each action stroke. Track only key-down events actually
submitted by this emitter. A failed event construction aborts the sequence.

Cancel pending strokes and release owned keys on left-cycle navigation, external
foreground change, device removal, service shutdown, and detected permission or
identity invalidation. Device removal may conservatively cancel the single
desktop interaction even when another device remains connected. Attaching a
device must not inherit an old selection.

Cleanup sends only key-up/modifier-release events to the original still-valid
process, even if it has moved to the background; it never sends a new action to
that background process or a release to an unrelated/replacement process. Invalid
or terminated identities are forgotten without posting. Cleanup is idempotent;
canceled timers and late callbacks cannot resume a sequence or recreate ownership.
Releasing Control during cleanup may close/commit the existing Hermes picker;
no unverified Escape-based cancellation is introduced.

Routine cleanup remains paced while the process is alive. Orderly process exit
uses best-effort release before dependencies disappear; forced termination or
revoked system permission cannot guarantee delivery and must not be described as
guaranteed cleanup. No global fallback or automatic permission reset is allowed.

## Implementation boundaries

Separate deterministic sequence/ownership logic from the CoreGraphics poster and
injectable main-RunLoop scheduler. The router requests cancellation before a
workspace cycle. Real watch startup owns foreground observation and ties HID
attach/removal and shutdown to cancellation. Demo, JSON-only and one-shot modes
must not create these services. Keep quota retries, heartbeat and USB audio intact.

Diagnostics distinguish accepting a sequence from completing its submissions;
neither means application receipt. Log fixed status categories only, never raw
events, content, device identifiers or application paths.

## Verification and installation

Use test-driven implementation with deterministic scheduler/poster fixtures:
exact sequences, >=30 ms spacing, busy rejection, repeated Hermes navigation,
right-without-selection, every partial-sequence cancellation point, foreground
and permission changes, PID identity changes, disconnect, repeated stop, and late
callbacks. Verify the RunLoop remains responsive while sequences are scheduled.

Run the full existing harness suite, fixed-SDK warnings-as-errors release build,
mode smoke checks, and attempt XCTest separately. Keep the current missing-XCTest
environment limitation distinct from harness results. Review lifecycle wiring.

Package a distinguishable Companion release (0.1.2, build 3) with current source
and build metadata. Back up the installed signed application, replace only the
Companion components, preserve original configuration and signing identifier,
and restart the original job. Reauthorize only if needed; do not reset TCC.

User-observed acceptance must separately cover SUPER all directions; Hermes
repeated up/down with picker retained and right to open; no Codex background
actions; central launch; cycle, detach/reconnect and shutdown cleanup; heartbeat
and quota continuity. Audio and other untested physical layers remain unverified.
Do not remove temporary diagnostic apps or permissions without user direction.
