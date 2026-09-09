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

Agent status and all button actions deliberately stay on the native Codex Micro
HID channel.

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
```

These are the only mode/parameter shapes. SUPER/HERMES require exactly integer
`ttl_ms: 15000`; Codex permits only `mode`. Only Hermes accepts optional `state`,
strictly `idle`, `opening` or `error`; omission means the existing active page.
SUPER/Codex reject `state`. Missing or extra fields, wrong types,
negative, floating, overflowing or different TTL values yield
`-32602 Invalid params` without changing or renewing the lease.

The first valid directional request owns a shared lease for its HID connection.
That owner can renew or switch SUPER↔HERMES. Another connection cannot take over,
switch or refresh it. Any valid Codex request exits safely; owner disconnect
exits immediately; otherwise wrap-safe `millis()` expiry restores Codex after
15 seconds. Renewal does not dirty an unchanged mode. This method remains
`ControlOnly`, never sets host-RPC-observed and cannot synthesize `CODEX LIVE`.

Only real companion `--watch` mode observes exact foreground bundle IDs:
`com.zarifpour.superconductor` → SUPER, `com.nousresearch.hermes` → HERMES,
everything else → Codex. Explicit SUPER-left selection is the sole override:
Hermes idle is displayed without activating the Mac app. A center request shows
opening, with error after rejection/3 seconds; only actual Hermes foreground
enables active mode. External foreground events cancel the selection. Attach
and restart discard pending requests and use the real foreground.
Entry/attach synchronizes immediately; one 5-second timer renews the current
directional mode. Leaving sends Codex and stops renewals. Failed exit writes
retry only failed devices, at most twice at 5-second intervals; success, detach,
a new mode or stop cancels obsolete retries. Stop attempts Codex before listener
shutdown. Lifecycle generations reject delayed callbacks after stop/restart.
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

The HERMES `OPEN` label is not a new RPC. Radial input still carries the same
directions; only the Mac's exact-foreground application profile maps Hermes
right to a Control press/release (virtual key 59, Control flag on press and no
flags on release). CoreGraphics represents this modifier pair as `flagsChanged`
events, delivered only to the validated target PID. It does not send Return or
Command-T, read the picker, or carry a selected session identifier. Up/down keep
their existing Control-Shift-Tab / Control-Tab chords. See
[physical acceptance and protocol limits](superpowers/plans/2026-09-04-hermes-open-physical-acceptance.md).

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
