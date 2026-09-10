# Workspace navigation isolation and Hermes diagnosis

Status: Design approved in conversation; written specification awaiting review.

## Verified context

The user verified Hermes background-window recovery and SUPER navigation after
targeted permission recovery. Hermes navigation still fails, including after
activation through Dock, while physical Control-Tab, Control-Shift-Tab and Control
release work. The user also observed Codex responding during Hermes gestures.

Current firmware sends `v.oai.rad` in every workspace; Companion consumes this
same native event. Thus Companion process-targeting cannot isolate the original
device event from Codex. Fixing this isolation defect does not by itself prove
that Hermes navigation will work.

## Firmware event separation

Codex retains its native direction reports. In the USB-mic build only, SUPER and
all Hermes screens instead emit the dedicated method `host.workspace_navigation`
through the existing Report ID 6 framing and transport. Never dual-send a press.

The fixed event shape is:

```json
{"method":"host.workspace_navigation","params":{"workspace":"hermes","direction":"up","phase":"press"}}
```

Allowed workspace values are `super` and `hermes`; direction values are `left`,
`up`, `down`, `right`; phase values are `press`, `release`. Exactly these fields
are accepted, with string types and no extra fields. No user-derived text, device
identifiers, project/session/window names or content is transmitted.

Latch workspace, direction and native/dedicated event family when accepting a
gesture. Release, mode-transition cancellation and power-off cleanup must use
that same origin, even if the displayed mode changes. Clear the active gesture
once, preventing a later touch-up from emitting a second release. An old Codex
gesture may need its native release during a transition; no new native press may
start in a dedicated workspace. Disconnection clears local gesture state.

Retain haptics, palette changes, wake-gesture consumption, center-tap recognition,
long-press power handling and all other input isolation. Default wireless
firmware behavior is unchanged.

## Companion decoding and routing

Preserve source workspace on dedicated events through the decoder and router.
Retain per-device decoding, Report ID checks, 64-byte compatibility, newline
framing and buffer bounds. Invalid events cannot invoke an action or rearm a
gesture. Match releases to their active origin before rearming; reset on device
removal. Native and dedicated directions and center actions share the existing
800ms cooldown and release gating semantics.

Dedicated up/down/right require all of: navigation enabled, selected workspace
matching the event, actual foreground matching that workspace, Accessibility
trusted, and the existing emitter's PID/bundle checks. Mismatch means no key
event. Dedicated left continues the existing cycle only for the matching selected
workspace, including Hermes waiting states. Late releases must still clear their
decoder gate after a legitimate mode transition.

Native up/down/right never map into SUPER/Hermes navigation. Native left retains
the existing Codex-side cycle entry. `host.workspace_action/open_hermes` and mode
leases remain unchanged. No global key injection, application configuration
changes or window-content inspection is introduced.

## Bounded Hermes diagnosis

Add a default-off diagnostic switch for the existing watch process only, with a
five-minute lifetime and at most 120 records per run. Record only fixed stage
and outcome values: accepted direction/source, navigation gate, foreground
profile match, Accessibility result, emitter identity checks and submission.
Do not log raw reports, payloads, PIDs, device identifiers, arbitrary bundle names
or application contents. Never start a second watch for diagnosis; preserve and
restore the original launch setup when enabling a bounded diagnostic run.

Use evidence to distinguish missing events, route rejection and process-directed
submission without visible response. Retain the existing Hermes mappings during
this diagnostic step. If submission occurs but Hermes still does not respond,
stop and report the boundary and physical-keyboard comparison; do not invent a
new mapping or claim this design has resolved that remaining cause.

## Tests and acceptance

- Native tests prove exactly one event family per press, correct release family
  across mode changes/power cleanup, waiting-page behavior and unchanged Codex
  and wireless behavior.
- Swift tests cover strict parsing, fragmentation, malformed events, matching
  releases, cooldown, stale workspace events, route isolation, permission denial,
  and diagnostic expiry/cap. Existing launch/timeout/heartbeat tests remain.
- Execute USB-mic build, native tests and fixed-SDK Companion build/harness.
  Attempt XCTest separately; report environment limitations without conflating
  harness success with XCTest.
- User must verify SUPER and Hermes each perform their three direction actions,
  Codex does not respond in the background, and original Codex controls work on
  return. Retest three-workspace cycling, center launch, reconnect, lease fallback,
  quota sync and USB microphone. Unobserved results remain unverified.

## Matched release and recovery

Incorporate the approved version-metadata design: next release `0.1.1`, build `2`,
source commit and build timestamp, plus installation modification time in Finder.
Write metadata before signing. Retain bundle identity; recheck permissions after
installation rather than assuming that the same identifier preserves trust.

Build both components before installation. Back up the currently installed
Companion and retain a verified firmware recovery artifact with its provenance.
Install the compatible Companion first; avoid workspace gestures during the mixed
version interval. Re-enumerate the download device and obtain explicit current
port authorization immediately before firmware upload. Do not alter LaunchAgent
configuration, merge or push. Roll back matched components after a critical
regression; firmware rollback also needs fresh port confirmation.
