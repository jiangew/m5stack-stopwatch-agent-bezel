# Paced navigation verification

## Scope

Companion-only 0.1.2/build 3 update. Firmware, wire protocol, shortcut mappings
and LaunchAgent configuration remain unchanged. No merge or push.

## User-observed diagnostic evidence

- SUPER full modifier sequence without spacing: no tab switch.
- Same sequence at 30 ms spacing: tab switch observed.
- Hermes spaced Control-Tab and release: next session opened.
- Hermes down/down/up while retaining Control: selection moved without opening;
  final release opened the selected session.
- Dedicated firmware isolation: user confirmed Codex no longer received
  background direction actions before this Companion pacing update.

These are diagnostic-tool observations, not installed 0.1.2 acceptance.

## Automated validation

- Regression test for right without owned Hermes selection failed against the
  prior emitter; router cleanup test failed before lifecycle integration.
- Version packaging test failed before metadata was updated to 0.1.2/build 3.
- 75 Swift harness test bodies passed, including pacing, no catch-up burst,
  retained selection, every partial cancellation, wrong process/permission,
  actual RunLoop responsiveness, SIGTERM on the test process, and late callbacks.
- Fixed MacOSX15.4 SDK release build passed with warnings-as-errors.
- Synthetic `--demo --json-only` smoke passed; packaging fixture tests passed.
- Full `swift test` was attempted and failed at test-module compilation:
  `no such module 'XCTest'`. Harness results are not described as XCTest passes.

## Serial review

Reviewed against the approved paced-navigation design and repository boundaries.
The emitter uses fixed sequences and no global posting or content reads. All
action strokes validate foreground, process identity/launch time and permission.
Cleanup only releases keys actually submitted to the original valid process.
MainActor timers do not block the main RunLoop; queued callbacks are invalidated.
SIGTERM/SIGINT handling exists only in real watch mode and attempts key release
before exit. Forced termination and revoked permissions remain delivery limits.

Review adjustments: preserve a single CoreGraphics event source, require explicit
cancel implementations, and distinguish permission loss from identity rejection.
No blocking standards or spec findings remain in the reviewed implementation;
physical behavior must be recorded separately and not inferred from tests.

## Installation / acceptance

Installed on 2026-09-12 from source `ecf1bbd`. The previous signed app was backed
up privately and verified. Candidate/installed executable equality, strict code
signature, version 0.1.2/build 3, preserved outer creation time and unchanged
original LaunchAgent configuration all passed. Modification time was updated.
The original service restarted as one instance and logged HID connection.
The initial startup reported an Input Monitoring warning and later an
Accessibility rejection. After the user re-added Companion Accessibility and the
original service was restarted, HID connected without a new Input Monitoring
warning. No permissions were reset and no firmware was flashed. Diagnostic
tools and all prior backups remain intact.

The user then confirmed both requested navigation groups worked normally:
SUPER up/down project selection and right tab switching; Hermes down/down/up
selection followed by right to open. These are user-observed physical passes.
The post-restart log slice contains no Accessibility warning, but contains no
NAV stage records either, so per-gesture submission traces are not claimed.

## Subsequent user-observed acceptance (2026-09-14)

- Left/cycle and Command-Tab away from Hermes selection and back: normal,
  with no stuck Control; no background Codex actions were observed.
- Travel shutdown and reconnect during selection: mode and navigation recovered
  without stuck keys or repeated actions.
- Service-exit/recovery cleanup: user confirmed normal after an explicit
  clarification of this test. The agent's attempted process inspection was
  blocked before any signal was sent; agent-observed termination/restart evidence
  is therefore not claimed.
- Hermes cold launch, background-window restoration, repeated central taps and
  subsequent navigation: user confirmed normal.
- USB microphone: user confirmed a normal short recording/playback and deletion
  of the temporary recording after the requested cleanup steps. No audio was
  read, transcribed, uploaded or retained in this record.

Initial final-check attempts were blocked by approval-service capacity before
execution. A subsequent read-only retry on 2026-09-14 succeeded:

- Original service running with exactly one Companion process; strict installed
  app signature verification passed and the original plist hash matched the
  installation baseline. No service or configuration was changed.
- One new quota-write success appeared during the observation window, with no
  new quota failure or workspace-output failure log entries.
- Since the preceding navigation acceptance log checkpoint, there were 76 quota
  failure/retry messages and two HID attach/detach pairs, but no workspace-mode
  output-failure messages. Later successful writes demonstrate recovery, not an
  error-free historical run. Disconnect tests may overlap this interval; no
  specific cause is inferred from these counters.
- Successful workspace heartbeats are intentionally silent. User-observed mode
  synchronization plus no logged workspace-output failures is the available
  evidence; individual heartbeat deliveries are not independently traced.

The service run count and process identity still matched the earlier snapshot.
Consequently the user-reported service-exit result above is not corroborated by
an agent-observed exit/restart. This remains a distinct evidence limitation.
