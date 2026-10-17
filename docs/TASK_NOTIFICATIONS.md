# Task notifications candidate — 2026-10-17

This is an opt-in source candidate for C152. The Mac owns the queue; the watch
shows opaque cards over a separate encrypted GATT service. Existing HID, quota,
workspace navigation and USB input-only audio retain their original paths.

Native cards currently use generic task labels and only verified available model
metadata; full task titles are not inferred from transcripts. Use exact OPEN
routing where supported to identify the native conversation.

The requested native allow/decline capability is **not yet delivered**. The broker
and watch implement a request-bound confirmation protocol, but all four supplied
native adapters set `canDecide:false`. A synthetic decision roundtrip does not
prove that a real harness accepted a watch response. Unsupported cards offer
OPEN ON MAC; reading, dismissing and opening never grant permission.

## What is implemented

- Persistent, bounded Mac inbox for Codex, DeepSeek Harness, SUPER and Hermes;
  independent sessions use exact source/session/run/request identity.
- Five-second announcements, priority/FIFO queue, browsing and one pending-action
  reminder. New arrivals cannot replace an open confirmation.
- Separate card/action GATT characteristics. Native scope, account credentials and
  session identifiers stay on the Mac; firmware receives opaque generation/id/revision.
- Read/dismiss/open plus generic allow-once/decline and finite choices. A fresh
  stationary 800ms hold is required for a supported, fully displayable request.
  Expired, disconnected or partially displayable scope cannot be approved.
- Action acknowledgement is separate from native result. Lost result becomes
  UNKNOWN; the durable dispatch is never automatically sent again.
- Native callback/plugin/collector entry points and explicit capability limits;
  see [adapter setup and evidence](../notifications/README.md).
- Explicit `--native-codex-notifications` completion ownership prevents the old
  HID completion banner/chime while the private channel is fresh. Status LEDs
  continue updating; the legacy path returns after 15 seconds without heartbeat.
  Enable only after installing the native Codex notification hook.

## Verification status

| Layer | Evidence | Limit |
| --- | --- | --- |
| Mac broker and private file bridge | Three standalone Swift suites (core, review regressions, production BLE transport against a test double); 8 Python tests, including real Python/Swift filesystem roundtrip | XCTest unavailable in the installed command-line SDK; standalone suites exercise production core sources |
| Native adapters | 23 Python and 7 Node tests; real Swift bridge tests | Source/schema + fixtures; hooks/plugins have not been installed in user profiles |
| Native SUPER envelope | Real ready and target_closed on an isolated synthetic terminal | No model completion or approval/input event observed live |
| Firmware parser/controller/UI | ASAN/UBSAN core and full-scope render tests, actual main-loop input/legacy-transition fixtures | Host execution cannot prove touch, encryption or haptics on C152 |
| Existing behavior | Actual main draw, haptic, workspace launch, IMU and swipe regressions | Physical regression acceptance pending |
| Compilation | Mac debug/release; default ESP32; native preview; existing USB+IMU source variant | Build success is not device acceptance |
| Release/install | Candidate packaging after source review | Installed application and known-good firmware are preserved |
| Native approvals | Generic synthetic identity/lease/confirmation/outcome tests only | Codex same-owner control; DSH audit-to-answerer binding; SUPER request/response API; Hermes native queue identity/control remain missing |
| Physical end-to-end | Not performed | No flash, pairing, encrypted GATT, watch action, duplicate-alert or haptic acceptance claim |

## Reproduce checks

Use the documented existing PlatformIO and Swift toolchains; these commands do
not install an app, edit a harness profile, call a model or flash hardware.

```sh
sh scripts/test_task_notifications.sh
sh notifications/test.sh
sh scripts/test_task_notifications_firmware.sh
ruby simulator/haptic_main_test.rb
ruby simulator/workspace_launch_main_test.rb
ruby simulator/robot_home_imu_main_test.rb
ruby simulator/robot_home_imu_swipe_test.rb
ruby simulator/codex_dashboard_draw_test.rb
```

Swift build commands need `CLANG_MODULE_CACHE_PATH` and
`SWIFTPM_MODULECACHE_OVERRIDE` set to `/private/tmp/stopwatch-swift-module-cache`;
run `swift build --package-path companion --disable-sandbox --cache-path
/private/tmp/stopwatch-swift-cache` and repeat with `-c release`.

Build firmware with `pio run -e m5stack-stopwatch`; build its actual framebuffer
renderer with `pio run -e native-preview`. The separately selected USB+IMU
candidate uses `pio run -d usb-mic -e m5stack-stopwatch-home-imu`. No upload target
is included. Local artifacts and private build provenance live in ignored output.

Native previews use `.pio/build/native-preview/program OUTPUT.ppm
notification-SCENARIO`, where SCENARIO is toast, detail, confirm, submitting,
offline, input or done. These are synthetic framebuffer captures, not photographs
or evidence of native harness approval.

## Remaining acceptance

1. Load each adapter into its existing native owner using the opt-in instructions;
   verify root/child separation, concurrent tasks and cancellation using synthetic
   tasks. Check existing-session coverage after reload. SUPER currently requires
   explicit root targets; global discovery is not implemented.
2. Observe exact-session OPEN where supported; application activation elsewhere
   must remain explicitly distinguished from exact navigation.
3. Establish same-owner native pending identity, full scope, cancellation and
   authoritative outcome before enabling any adapter's allow/decline capability.
4. Only after source/candidate review, identify the connected C152 and known
   factory recovery path. Resolve and report the exact `/dev/cu.*` port and obtain
   confirmation under AGENTS.md before flashing. Install/replace the running
   Companion separately from building its candidate.
5. Physically validate multiple simultaneous sources, reminder/browse ordering,
   wake-touch isolation, fresh confirmation, disconnect/reconnect, power holds,
   existing navigation/IMU/USB microphone, and duplicate Codex completion behavior.

The baseline checkout remains clean on main at `33bbbe98d719a19d5c909e3b1fc73319bc993795`. This feature is kept
on `feature/task-notifications`; no push, merge or deployment is implied.
