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
installed physical behavior is pending and must not be inferred from tests.

## Installation / acceptance

Pending. Back up and verify the current signed app before replacing Companion,
preserve configuration and outer creation time, then verify 0.1.2/build 3 metadata.
Only reauthorize if required. Keep diagnostic tools and existing backups.

Unverified for installed 0.1.2: SUPER all directions; Hermes repeated selection
and right-open; no background Codex actions; central launch; foreground/cycle,
disconnect/reconnect and service-stop cleanup; heartbeat, quota and USB microphone.
