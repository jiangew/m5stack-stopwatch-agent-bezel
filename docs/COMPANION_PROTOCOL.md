# Mac companion to StopWatch protocol

This is a project-owned protocol. It is not part of Codex Micro.

## GATT

| Item | UUID |
| --- | --- |
| Service | `7f0d4e66-2ac2-4a71-bfbe-4ef61a0e5c01` |
| Quota write characteristic | `7f0d4e66-2ac2-4a71-bfbe-4ef61a0e5c02` |

The characteristic accepts Write and Write Without Response over an encrypted,
bonded BLE link. The first companion write therefore uses the same BLE bond as
HID. Payloads are UTF-8 JSON and must be no larger than 512 bytes.

## Snapshot schema

```json
{
  "remaining_percent": 26,
  "reset_in_seconds": 356400
}
```

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `remaining_percent` | number | yes | Clamped to 0 through 100 |
| `reset_in_seconds` | integer | yes | Relative countdown avoids a watch clock dependency |

## Companion behavior

1. Start or attach to a local Codex App Server using the user's existing local
   ChatGPT/Codex login context.
2. Call `account/rateLimits/read` at startup and after a rate-limit update.
3. Choose the primary Codex bucket explicitly; do not silently substitute a
   Spark or secondary bucket.
4. Convert the reset timestamp to `reset_in_seconds` at send time.
5. Require the Mac-specific CoreBluetooth UUID captured during the demo-only
   binding step, scan for that exact paired peripheral, discover this service,
   and write one complete JSON object. Never send real account quota to the
   first matching advertiser.
6. Refresh at most once per minute unless the App Server sends a change event.

Agent status and Codex controls stay on the existing HID channel. Dedicated
workspace directions use project-owned messages on that same transport, not quota
GATT and not native Codex radial messages.

## Foreground workspace mode over HID

The optional USB-microphone firmware accepts one project-owned control RPC over
vendor Report ID 6. It changes only a fixed rendered mode, not quota or content.

The macOS report passed to `IOHIDDeviceSetReport` is always 64 bytes:

| Offset | Value |
| --- | --- |
| 0 | Report ID `0x06` |
| 1 | RPC fragment marker `0x02` |
| 2 | UTF-8 payload length, 0 through 61 |
| 3 through 63 | Payload bytes followed by zero padding |

Requests are newline-terminated UTF-8 JSON, fragmented at byte boundaries into
at most 61 payload bytes per report. HOGP normally strips the report ID; firmware
accepts both the 63-byte body and full 64-byte form. A failed fragment stops that
request; the writer does not continue its remaining fragments.

```json
{"method":"host.workspace_mode","params":{"mode":"super","ttl_ms":15000},"id":1}
{"method":"host.workspace_mode","params":{"mode":"hermes","ttl_ms":15000},"id":2}
{"method":"host.workspace_mode","params":{"mode":"codex"},"id":3}
{"method":"host.workspace_mode","params":{"mode":"hermes","ttl_ms":15000,"state":"idle"},"id":4}
{"method":"host.workspace_mode","params":{"mode":"hermes","ttl_ms":15000,"state":"opening"},"id":5}
{"method":"host.workspace_mode","params":{"mode":"hermes","ttl_ms":15000,"state":"error"},"id":6}
{"method":"host.workspace_mode","params":{"mode":"home"},"id":7}
{"method":"host.workspace_mode","params":{"mode":"codex","ttl_ms":15000},"id":8}
```

These are the only mode/parameter shapes. SUPER/HERMES require exactly integer
`ttl_ms: 15000`; Codex accepts legacy `mode` alone or the leased form above.
Home permits only `mode`. Only Hermes accepts optional `state`,
strictly `idle`, `opening` or `error`; omission means the existing active page.
Home/SUPER/Codex reject `state`. Missing or extra fields, wrong types,
negative, floating, overflowing or different TTL values yield
`-32602 Invalid params` without changing or renewing the lease.

For the legacy/default lease, the first valid directional request owns a shared lease for its HID connection.
That owner can renew or switch SUPER↔HERMES. Another connection cannot take over,
switch or refresh it. Any valid Codex request exits safely; owner disconnect
exits immediately; otherwise wrap-safe `millis()` expiry restores Codex after
15 seconds. Renewal does not dirty an unchanged mode. This method remains
`ControlOnly`, never sets host-RPC-observed and cannot synthesize `CODEX LIVE`.

The matched Home USB-mic build instead boots and falls back to Home. All work
pages, including Codex, require a Home acknowledgment first and share the
15-second, wrap-safe lease. Only its owning connection can renew or switch it,
including an explicit Home command; another connection cannot steal ownership.
Expiry or owner disconnect clears readiness, and stale work renewals are ignored
until Home is acknowledged again. Even idle Home readiness expires without a
heartbeat. Renewal without a mode/readiness change does not mark state dirty.
While connected but not ready, firmware sends this fixed control action at most
once per second (it is not a user gesture and bypasses the 800ms gesture cooldown):

```json
{"method":"host.workspace_action","params":{"action":"show_home"}}
```

Companion cancels owned keys/pending activation, pins Home and replies with the
Home mode above, even when already on Home. The action accepts exactly `method`
and `params`, with `action` as its sole parameter; it never activates an app.
Home navigation uses `workspace: home`, `direction: left`, and press/release;
all other Home reactions stay on-device. No payload or device identity is logged.

Only real companion `--watch` mode observes exact foreground bundle IDs:
`com.zarifpour.superconductor` → SUPER, `com.nousresearch.hermes` → HERMES,
everything else → Codex while a work page is selected. Home is a pinned override
that ignores foreground changes until an explicit left swipe activates Codex.
Explicit SUPER-left selection is another override:
Hermes idle is displayed without activating the Mac app. A center request shows
opening, with error after rejection/3 seconds; only actual Hermes foreground
enables active mode. External foreground events cancel the selection. Attach
and restart discard pending requests and select Home in the matched build.
Entry/attach synchronizes immediately; one 5-second timer renews the current
mode, including Codex and Home in the matched build. Legacy mode without the
interaction controller stops renewals on Codex. Failed Codex writes additionally
retry only failed devices, at most twice at 5-second intervals; success, detach,
a new mode or stop cancels obsolete retries. Stop attempts Codex before listener
shutdown in legacy mode; the matched controller attempts Home instead.
Lifecycle generations reject delayed callbacks after stop/restart.
Failures log at most once per 60 seconds and do not stop HID input, quota or the
main RunLoop. All observer, timer and writer operations are MainActor-serialized.

Mode changes never wake a sleeping display. SUPER/HERMES isolate Agent, Send,
voice controls and ChatGPT physical buttons, retaining four swipes and existing
power/Travel Mode behavior. Disabled short taps do not wake; a swipe that wakes
the display is consumed without sending navigation.

Palette changes are firmware-local: an accepted awake four-direction swipe selects
four distinct colors from a fixed 12-color pool, with an 800ms visual cooldown.
Every direction differs from its preceding color. Rendering, foreground changes
and heartbeats do not randomize. No palette/color RPC or arbitrary text input is
introduced. Codex swipes may update the hidden palette without changing the
Codex dashboard; entering a directional screen reuses that palette.

The channel contains only a fixed mode/state enum, fixed TTL and a wrapping UInt32
request number. It never contains project/session/window/Space/workspace data,
credentials, prompts or user content. No report payloads or device identifiers
are logged.

## Device central action over HID

The device sends this fixed newline-terminated event through the existing
Report 6 fragment channel (not quota GATT or a keyboard Send event):

```json
{"method":"host.workspace_action","params":{"action":"open_hermes"}}
```

Only those two top-level keys and the single string action are accepted; extra
fields, unknown actions and wrong types are ignored. Center events share the
800ms direction cooldown and cannot bypass a held radial press. Central input
must begin/end inside the existing square, last under 500ms and never cross
the swipe threshold. The sleeping-screen wake gesture is consumed. Long holds
retain power behavior and cannot emit this event.

The MainActor interaction controller accepts center actions only in Hermes
idle/error. Opening ignores duplicates, and active Hermes ignores center input.
One request has a 3-second foreground-confirmation deadline and never retries
automatically. Directions in idle/opening/error are suppressed; left exits to
Codex. Late launch callbacks are generation-checked; true foreground activation
still wins. The 5-second writer heartbeat never calls a launch API. A separate
Desktop KeepAlive LaunchAgent is an installation policy, not this protocol.

## Host-side direction mapping

In the matching USB-mic firmware and Companion 0.1.1, SUPER and all HERMES states
send only this dedicated event for each direction press/release:

```json
{"method":"host.workspace_navigation","params":{"workspace":"hermes","direction":"up","phase":"press"}}
{"method":"host.workspace_navigation","params":{"workspace":"hermes","direction":"up","phase":"release"}}
```

Exactly `method` and `params` are accepted. Params must contain exactly the three
string fields: workspace (`super`/`hermes`/`home`), direction (`left`/`up`/`down`/`right`),
phase (`press`/`release`). Unknown, missing, extra or wrong-type fields are ignored.
Home accepts only left. Home up/down/right and head taps do not emit these events.
Framing remains newline-delimited Report 6. Each press latches its source and
direction; a matching release rearms the per-device decoder, including after a
mode transition. A wrong-source/direction release cannot rearm it. Center actions
share the 800ms cooldown. Disconnect clears that device's latch.

Codex retains native `v.oai.rad` directions. Dedicated workspace presses never
also send native radial input; a prior Codex press still receives its native
release when switching modes. Native up/down/right are never forwarded to
SUPER/Hermes. Dedicated directions require matching selected and actual foreground
profiles and Accessibility; left cycles the matching selected workspace, including
waiting Hermes. This fixes a native-event leakage path, but must still be physically
verified to cause no background Codex action. Install and roll back matched pairs:
old firmware with new Companion cannot provide dedicated navigation.

Companion 0.1.2 retains Control across Hermes up/down selection and maps right
to release of that owned Control (virtual key 59, no flags on release). Without
owned selection, right is a no-op. Modifier transitions use `flagsChanged` events;
complete sequences are paced at least 30 ms apart on the main RunLoop. SUPER
releases all modifiers after each command. Each action validates foreground, PID,
bundle ID, launch time and Accessibility. Cleanup releases only owned keys to
the original still-valid process; normal SIGTERM/SIGINT attempts cleanup before
exit. Forced termination and revoked permission cannot guarantee delivery.
No firmware or wire-protocol changes are needed for this update. It does not send
Return or Command-T, read the picker, or carry a selected session identifier.
Up/down keep their existing Control-Shift-Tab / Control-Tab chords. See
[physical acceptance and protocol limits](superpowers/plans/2026-09-04-hermes-open-physical-acceptance.md).

### Bounded navigation diagnostics

Only real watch mode installs a `SIGUSR1` handler. After verifying that the running
process is this diagnostic-capable version, send that signal to its exact PID to
enable at most 120 fixed `NAV` records over 300 seconds. Repeated triggers do not
extend or replenish the budget. Never signal an older Companion (the signal may
terminate it), start a second watch, or change LaunchAgent arguments for tracing.
Records identify input origin/direction, rejection stage or submission outcome;
they contain no raw reports, arbitrary app names, PIDs, device identifiers or
user content. `sequence_accepted` records acceptance for scheduling and
`sequence_busy` records ignored overlapping input. `submitted` marks completion
of local API submissions, not Hermes receipt.
Hermes failure after submission requires separate investigation, not a mapping
change or global-key fallback.

## Optional maintenance request

Only the USB-microphone image accepts this write-with-response request:

```json
{"op":"enter_bootloader","version":1,"confirm":true}
```

The firmware accepts it only while USB power is present and only from the same
BLE peer that completed a valid Codex HID RPC in the current connection epoch.
It checks USB power again after a short delay before restarting into the
ESP32-S3 serial bootloader. The default wireless image ignores this operation.

An ATT acknowledgement proves delivery, not a restart. The companion reports
success only after the BLE link disconnects; the flashing workflow must still
discover and verify the newly enumerated `/dev/cu.*` port.

Do not send account identifiers, access tokens, prompts, task text, project or
session metadata, window/Space/workspace state, or other private content to the
watch.
