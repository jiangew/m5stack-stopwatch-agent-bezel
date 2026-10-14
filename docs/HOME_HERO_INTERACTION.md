# Home character responses — 2026-10-14

This source candidate replaces tap energy effects with distinct character gestures
for **Bumblebee portrait, Bumblebee full body, Optimus Prime, Jazz, Hot Rod, Wheeljack, Hound, Ironhide and Ratchet**. It requires the
five-screen `m5stack-stopwatch-usb-mic` firmware; the default wireless image
remains the Codex dashboard. The existing Companion and protocol are unchanged.

## Behavior

| Gesture | Home result |
| --- | --- |
| Awake portrait press | Immediately compress the original portrait 3% |
| Release before 500ms, remaining inside the portrait area | Start one 600ms character response and request one short 25ms haptic |
| New press during a response | Interrupt and immediately begin the new press feedback |
| Move outside portrait area or at least 52px from start | Cancel the tap; a classified swipe may select a hero or cycle workspaces |
| Up / down / right | From the default portrait, uniformly choose one of eight full-body heroes; thereafter choose among the other seven full bodies, with one existing 40ms swipe haptic |
| Left | Existing workspace cycle; no new Mac action is attached to responses |
| First touch while asleep | Wake only; no response or hero change |
| Leave Home / sleep / power overlay | Cancel the reaction; existing long-hold power flow remains |

The portrait hit area is x=64..402, y=64..398. All portrait rendering stays
clipped inside that area; tap energy-effect overlays have been removed. Selection defaults to
Bumblebee when Home is re-entered. Directions no longer map to fixed heroes.
The portrait is excluded from the random pool. Choices may return to a
previously seen full-body hero after an intervening change; only immediate
repetition is forbidden. One held swipe never repeats selection.

| Hero | Response |
| --- | --- |
| Bumblebee portrait | Small nod and tilt using the unchanged portrait |
| Bumblebee full body | Wave between two accepted poses with a small bounce |
| Optimus Prime | Raise fist, nod, then return through the accepted poses |
| Jazz | Double thumbs-up with a slight shoulder tilt |
| Hot Rod | Open-palm greeting and lively forward lean |
| Wheeljack | Raise wrench beside shoulder |
| Hound | Fist over chest, returning to the original salute |
| Ironhide | Strong friendly fist raised at chest |
| Ratchet | Clear OK hand beside shoulder |

Responses are silent. State and battery retain their existing positions and
real data sources. Preview values are fixtures, not device telemetry. The user
accepted the Bumblebee full-body and Optimus browser pilots on 2026-10-14;
other motions use the same style and 600ms envelope. These use discrete edited
key poses plus native transforms, rather than skeletal interpolation.

## Rendering and failure behavior

- Nine idle 300×300 RGB565 sprites use 1,620,000 pixel bytes. Ten optional
  response sprites add 1,800,000 bytes, for 3,420,000 total cached pixel bytes,
  excluding the framebuffer, decoder scratch space and other runtime memory.
  Both banks prepare on entering Home; ordinary animation draws reuse pixels.
- Idle allocation failure frees its partial bank and attempts one reusable
  buffer. Hero changes may decode one idle image in this fallback. A failed
  decode is remembered; if no idle image can be drawn, a neutral face answers.
- Action allocation failure frees only the optional action bank, preserving
  idle images. A missing/bad pose draws that character's own idle image with
  the current motion. The optional bank never uses a single-buffer fallback,
  so changing key poses cannot cause JPEG decoding or allocation every frame.
  Cache failures stay remembered until explicit clearing. Leaving Home or
  sleeping frees both banks. Physical PSRAM headroom still needs validation.
- One `FrameClock` drives animation at a nominal 34ms cadence; input requests
  bypass the cadence. The final resting state is explicitly repainted. Idle
  Home redraws only for state changes.
- Scheduling records the animation state of the pixels rendered, so crossing
  an expiry during panel transfer cannot strand an effect. Cadence counts
  rendering time rather than adding a second delay after transfer.
- Portrait rasterization is clipped to its safe area, protecting status and
  battery from JPEG edge artifacts. Native previews use the same cache,
  transform and clip path as firmware.
- The release haptic begins after its first frame is drawn. Pulse widths are
  requested software durations; actual motor timing, frame rate and latency
  still require physical C152 measurements.

The original Bumblebee portrait source and accepted idle JPEG are preserved;
the idle JPEG SHA-256 is
`f1bb7e24fe30631b15e1999c35a0b8d4024d3fc52b222aa0ad6c5d6676a9d191`.
The eight full-body PNGs come from built-in imagegen output and are fitted to the
300px black-backed source tiles. The earlier Optimus portrait has been retired
from the active Home roster. Generation briefs and reproduction details are in
[artwork provenance](../assets/robot-home/GENERATION.md). This is unofficial
fan artwork, not licensed character art.

## Verification

The implementation includes:

- Selection tests for all three directions, all current heroes, every candidate,
  rejected entropy, non-repeat, no entropy for left/none and uptime wraparound.
- Press/release, interruption, expiry, bounds, movement, cancellation and wake
  tests using the real interaction state machine.
- Cache tests for full reuse, partial-allocation fallback, complete allocation
  failure, bad decode and recovery after overwriting the fallback buffer.
- Actual firmware-function tests for immediate press/release drawing, haptic
  ordering, wake/hold isolation, random swipes and existing Agent controls.
- Actual `drawScreen` tests for crossing reaction/transition expiry during a
  simulated panel transfer and Codex dashboard pixel equality.
- Decoded native sequence checks for all nine choices: immediate visible press
  and response, identical status/battery pixels and final idle-frame equality.
- Real JPEG/header-byte/determinism checks through Python and independent
  ImageIO decoding through Swift.
- Compression-tolerant artwork identity checks reject re-encoded duplicates
  of all nine images while accepting the distinct shipped figures.

Validation record for the earlier seven-choice source build: **5 Python artwork tests**,
**7 ImageIO decodes**, seven native spacing sequences, real gesture and production
draw regressions passed. Native preview, default firmware and five-screen USB-mic
firmware built successfully. Exact commands and outputs are recorded in the local
Task 2 validation report. One upstream M5GFX Clang VLA-extension
warning remains in native compilation; no new source compile errors occurred.

The previous nine-image energy-effect source build passed the same five Python artwork tests,
nine independent ImageIO decodes, selector/cache/frame/interaction/UI tests,
actual gesture/reaction/launch/draw regressions, and nine native spacing
sequences (270 retained frames). Native preview, default firmware, and selected
five-screen USB-mic firmware built. The two new README previews were exported
from the native framebuffer. The later physical deployment checks are recorded
below; host tests do not establish visual or gesture acceptance on C152.

The 2026-10-14 response candidate passed eleven focused C++ test executables,
seven Python artwork tests, nineteen independent ImageIO decodes, the actual
Home swipe/reaction/launch/draw regressions, and nine full native sequences
(486 frames). Status/battery pixels stayed unchanged in every frame and each
sequence returned to its original idle pixels. Native, default and selected
USB-mic builds succeeded. USB-mic static RAM was 106,764 bytes and program size
2,077,555 bytes; these build figures exclude dynamic sprite PSRAM. All nine
idle JPEG hashes and the four accepted pilot action JPEGs remain unchanged.
The response application was subsequently flashed as recorded below. Native response artwork is
shown in [the response preview](../artifacts/robot-home-responses.png); prompts
and action provenance are in [actions](../assets/robot-home/actions/README.md).

Run the core checks from the repository root:

```sh
clang++ -std=c++17 -Iinclude simulator/robot_home_character_test.cpp -o /private/tmp/home-character-test
/private/tmp/home-character-test
clang++ -std=c++17 -Iinclude simulator/robot_home_interaction_test.cpp -o /private/tmp/home-interaction-test
/private/tmp/home-interaction-test
clang++ -std=c++17 -Iinclude simulator/robot_home_frame_test.cpp -o /private/tmp/home-frame-test
/private/tmp/home-frame-test
clang++ -std=c++17 -Iinclude simulator/robot_home_cache_test.cpp -o /private/tmp/home-cache-test
/private/tmp/home-cache-test
clang++ -std=c++17 -Iinclude simulator/robot_home_motion_test.cpp -o /private/tmp/home-motion-test
/private/tmp/home-motion-test
python3 simulator/robot_home_art_test.py
python3 simulator/robot_home_action_art_test.py
swift -module-cache-path /private/tmp/home-swift-cache simulator/robot_home_art_test.swift
swift -module-cache-path /private/tmp/home-swift-cache simulator/robot_home_art_test.swift --actions
ruby simulator/robot_home_swipe_test.rb
ruby simulator/robot_speech_reaction_test.rb
ruby simulator/workspace_launch_main_test.rb
ruby simulator/codex_dashboard_draw_test.rb
pio run -e m5stack-stopwatch
# Archive the default binary before switching root PlatformIO environments.
HOMEBREW_PREFIX=/opt/homebrew pio run -e native-preview
ruby simulator/robot_home_spacing_test.rb .pio/build/native-preview/program
pio run -d usb-mic -e m5stack-stopwatch-usb-mic
```

Python artwork checks require Pillow and numpy. Existing dependency caches are
used; builds do not upload or change Companion installation. For a batch of
native animation frames, create an output directory then run
`.pio/build/native-preview/program --home-sequence OUTPUT_DIRECTORY`.

PlatformIO environment switching may clean another root environment's build
artifacts; complete default/archive first, then native rendering tests. The
isolated USB-mic project has its own build directory.

## Deployment and remaining physical acceptance

On 2026-10-14, after explicit current-target confirmation and a new complete
16MB backup, the nine-role 600ms response USB-mic application from `4b1b6e9`
was written only to app0 at `0x10000`. The partition table matched, OTA selected
app0, and the previous application matched the earlier confirmed deployment.
The application is 2,110,000 bytes, SHA-256
`12fb681b47bf5dd748f37ab043bc71b809e63d34ca82365a9e5c9d925acaa531`.
The tool wrote it in 22.1 seconds and verified its hash; independent ROM
verification matched the digest. A readback of the protected first 64KB was
byte-identical to the fresh backup, preserving bootloader, partition table,
NVS/pairing configuration and OTA metadata.

After watchdog reset, USB/IOKit and CoreAudio exposed `Codex StopWatch Mic`
with one 48kHz input and no output. BLE HID transport and a fresh Companion
HID connection were observed; read-only `device.status` RPC received its
matching successful response. A 3.008-second capture contained 144,384 frames
of 48kHz mono16 PCM, with zero discontinuities, long zero runs, repeated adjacent
blocks or clipped samples. Temporary audio and staging files were deleted.
No Companion restart/deployment, push or merge occurred. These establish the
write, protected metadata, reboot, connections and short capture. On 2026-10-14,
the user subsequently confirmed the deployed Home interactions normal, completing
qualitative Home interaction acceptance. Actual PSRAM headroom, motor timing,
frame rate, measured touch latency and audio continuity during sustained animation
remain unmeasured; this confirmation is not a new acceptance run of every Agent control.

On 2026-10-14, the nine-image/eight-body USB-mic application built from
`2705564` was written to app0 at `0x10000` after fresh download-mode target
confirmation, a complete 16MB private backup, matching partition tables and
verification that OTA selects app0. The firmware SHA-256 is
`976db32b5bc9087d72dd4c355833963f2f5f69491a6cde3cad574be29399ee59`.
The write verified its hash and a separate ROM verification matched the digest.
A readback confirmed the protected first 64KB remained byte-identical to the
fresh backup, including bootloader, partition table, NVS and OTA metadata.

After watchdog reset, USB and CoreAudio enumerated `Codex StopWatch Mic` as one
48kHz input without a USB output. A fresh Companion HID connection was observed;
the HID transport was Bluetooth Low Energy and a read-only `device.status` RPC
received a matching successful response. A 3.008-second capture contained
144,384 frames of 48kHz mono16 PCM, with zero discontinuities, long zero runs,
repeated adjacent blocks or clipped samples. Temporary audio was deleted.
No Companion restart/deployment, push or merge occurred. These checks establish
the write, reboot, connections and short audio capture. The user later accepted
the deployed random swipe experience. Every Agent control, measured latency
and long-duration audio reliability remain
separate hardware checks.

On 2026-10-13, the user confirmed download mode and explicitly approved the
identified upload port. The earlier four-hero five-screen application built from `3a0e2cf` was
written to app0 at `0x10000` after a complete 16MB private backup and confirmation
that the device/candidate partition tables match and OTA selects app0.

The write tool verified its data hash, then an independent ROM verification
matched the firmware digest. A separate readback confirmed the first 64KB,
including bootloader, partition table, NVS and OTA metadata, remained byte-identical
to the pre-update backup. No Companion deployment, restart, push or merge was
performed. The device restarted with the tool's watchdog reset; USB and CoreAudio
again enumerated `Codex StopWatch Mic` as one 48kHz USB input, and a new Companion
HID-connected log was observed. A compiled version of the existing capture helper
then recorded 3.008 seconds of 48kHz, mono, 16-bit PCM (144,384 frames). Validation
found no discontinuities, long zero runs, repeated adjacent blocks or clipping.
The temporary recording was deleted. Connection and this short capture do not
establish every control/RPC action or long-duration audio reliability.

Before any future upload or rollback, follow the
[official M5Stack factory-recovery procedure](https://docs.m5stack.com/en/guide/stopwatch/restore_factory),
resolve and report the current exact download-mode port and obtain upload approval.
Private backups, firmware and detailed device logs stay local.

The user later confirmed the earlier interaction felt normal in use; that was
subjective acceptance, not a measured response-latency result. The nine-image, eight-body energy-effect firmware has been written and verified,
and its random swipe interaction was accepted by the user on 2026-10-14. The
new 600ms character-response application has now been flashed and verified, and
the user confirmed its Home interactions normal on 2026-10-14. This is qualitative
acceptance, not a per-character timing or long-duration soak measurement. For a
quantified latency check, measure at least 30 responses per hero, with a target P95 of 80ms or
less from recognized touch to first feedback; also check touch-to-visible latency
using high-frame-rate video. The target has **not** been measured or established
on this hardware.
