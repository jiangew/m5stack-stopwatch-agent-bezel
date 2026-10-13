# Five workspaces and Home interaction history

The current seven-choice Home source replaces blinking with press/release skills and random selection. See [current Home behavior](HOME_HERO_INTERACTION.md); the blinking records below are historical acceptance only.

## DSH display label (2026-10-12)

The DeepSeek Harness page now displays `DSH` in active, idle, opening and error
states. It uses the existing SpaceMono46 font at its normal size within the same
center panel. The `deepseek` protocol mode, `com.deepseek.dsh` application bundle,
plugin bindings and navigation behavior are unchanged. Both README titles and
page labels, plus the public native-rendered preview, are synchronized.

Native UI, production draw/launch regressions and headless framebuffer previews
passed. Firmware built from source commit `ee80260` was flashed to the existing
USB-mic app0 partition after exact-device confirmation on 2026-10-12. Written
data and an independent device digest check passed; partition table, NVS and OTA
metadata remained byte-identical. Companion build15 and its LaunchAgent remained
unchanged; USB microphone enumeration and a fresh Companion HID connection were
observed after reboot. The user confirmed the `DSH` title and up/down/right
navigation normal. This acceptance covers the label update and those controls.
The `DeepSeek` title and scaling notes below describe earlier versions.

## Build9 installed acceptance and SUPER windowless follow-up

Build9 and matching USB-mic application firmware were installed with separate
explicit approvals. User confirmed triple blink, restored character haptics,
original CODEX UI and title/cycle. After reauthorizing Companion Accessibility
and restarting only Companion, DeepSeek three-direction navigation passed.
Codex/Hermes launch and SUPER cold launch/navigation were physically confirmed.

User then reported SUPER with process alive but all windows closed cannot reopen
from center. The accepted follow-up is Companion-only: check window presence
without reading contents, enter SUPER idle only on confirmed absence, and permit
center reopening then. An existing normal window keeps active-center no-op.
Permission failure/unknown is not treated as absence. Existing build9 firmware
already supports these states; no further firmware write is needed.

## Triple-blink and general center-launch implementation history

The user requested three more refinements after physical acceptance below:

- Home center now performs three silent blinks: 360ms per blink, 120ms fully open
  between blinks, 1320ms total. Repeated taps during any phase do not restart or
  queue animations; leaving Home/sleep/power still cancels.
- Subsequent user correction restores character-switch vibration: one existing
  swipe pulse (intensity168, 40ms) on up/down/right, including return to Bumblebee
  and offline selection. Wake-only gestures do not switch characters; held movement
  never repeats the pulse. Center triple blinking remains silent and non-haptic.
  Actual gesture/reaction extraction regressions pass for these distinctions.
- Title is exactly `DeepSeek`, using the same SpaceMono46 font asset as SUPER and
  HERMES. It scales down from 224px advance to fit the 178px panel; actual fixed-point
  text width is 176px. SUPER/HERMES retain their normal size.
- Stopped Codex, DeepSeek and SUPER targets can be selected without cold-launching.
  Center starts/retries; Hermes retains its existing explicit reopen flow. Waiting
  pages for DeepSeek/SUPER/HERMES show TAP TO OPEN / OPENING / TAP TO RETRY.
  User clarified that CODEX UI must remain unchanged: all Codex states use the
  original dashboard, with no four-triangle substitution or new visual prompts.
  Its center still launches/retries while pending and remains Send when active.
  Regression verifies actual drawScreen with real LGFX rasterization: 10 dashboard
  fixtures, pressed/unpressed, all four Codex states, both default/USB builds are
  pixel-identical to the original dashboard renderer. DashboardUi.h is unchanged.
  The correction passed 17 native C++ and 7 Ruby regressions.
  User accepted the smaller proportional DeepSeek title to preserve its layout;
  its lowercase letters and smaller size explain the visual difference despite
  using the identical font asset. Opening rejects repeat taps,
  while left can continue cycling. Active Codex center remains Send; other active
  centers remain no-op. Pending controls cannot emit native Codex actions.
- General launch wire event is `host.open_workspace` with empty params. All four
  known mode names accept strict leased idle/opening/error state. Old Hermes wire
  remains compatible. Firmware and Companion must be updated together; installed
  build8 does not implement the new general launch protocol.

Validation: 8 focused native C++ tests; actual main/BLE/touch extraction tests;
all-millisecond triple-blink tests and 26 timing boundaries for four native-rendered
characters; 102 production Swift test bodies with warnings-as-errors (not full
XCTest); Companion Release, USB-mic, default firmware and native preview builds
passed. USB-mic uses 99,988 bytes RAM / 1,742,703 bytes application flash. Existing
upstream M5GFX native compiler warning remains. No app/profile/plugin installation,
service restart or device flash was performed for this follow-up. The installed
0.1.1 Harness navigation plugin and recovered provider configuration were untouched.

## Previous navigation follow-up (physically accepted before the changes above)

The user accepted the ring-free / blink previews, then requested full Deepseek
controls with the same four-triangle geometry as SUPER. Current behavior:

- PREV / NEXT: previous/next existing thread in sidebar order across projects.
- VIEW: switch the main Chat / Trajectory view; CYCLE: advance to SUPER.
- Center and physical action buttons remain inactive. Home artwork/blink unchanged.
- Requires the separately approved optional `deepseek-plugin` and matching
  Companion. Fixed Ctrl+Option+Up/Down/Right commands are process-targeted only
  to the exact foreground DeepSeek Harness, not global keyboard events.
- The installed Harness lacks native commands for these actions. The plugin
  operates a version-pinned, fail-closed DOM adapter with no text/draft/credential
  reads. It checks only structural IDs, focus, readiness and view metadata.
- A collapsed project or hidden-row expansion takes one gesture to prepare;
  the next gesture navigates after the render acknowledgment. No delayed clicks,
  automatic retries, wraparound or session creation. Missing Trajectory is a no-op.

Follow-up validation: 17 native C++ tests and actual gesture/reaction harnesses
passed; USB-mic and preparation builds passed (99,988 bytes RAM, 1,742,131 bytes
application flash); native preview passed with the existing upstream M5GFX VLA
warning. Companion Release warnings-as-errors build and offline HID self-test
passed after approved retries, plus 100 temporary Swift production test bodies.
The initial plugin passed 64 Node tests and deterministic build checking, but
those tests did NOT validate actual cross-platform command registration. Version
0.1.0 subsequently failed real Harness activation: registration checks every
platform and throws on any reserved default, even if this desktop's mapping is
allowed. Do not install or reenable 0.1.0. User recovered Harness and provider
configuration with Codex and disabled this bundle. Repair must preserve that
recovered configuration; passing fake DOM tests is not startup acceptance.

After separate approval, Companion build8 was installed and USB-mic application
flash completed with data-hash verification and full prior-flash backup. User
confirmed Home silent blink and Deepseek four-way page on C152; USB 48kHz mono
input-only enumeration and HID reconnection were observed.

Final user acceptance after 0.1.1 installation and full Harness restart: all three
commands visible; keyboard and C152 previous/next cross projects without creating
sessions, right switches Chat/Trajectory, and complete five-workspace cycle works.
Trajectory required the user to enable Settings → General → Show coding view.
C152 navigation required reauthorizing Companion Accessibility and restarting its
existing service. User also confirmed ring-free silent blink, inactive Deepseek
center, draft preservation, menu/settings/background isolation and wake-only first
swipe. Repaired provider configuration was preserved during installation.

Version 0.1.1 passed 96 tests including actual host ShortcutRegistry registration
for all platforms and regression rejection of 0.1.0 definitions. Fresh audio
capture and extended lease/reconnect soak were not repeated; quota networking
errors were observed, so quota sync is not claimed successful. Full XCTest remains
unavailable. See [plugin setup and limitations](../deepseek-plugin/README.md).

## Initial left-only scope (historical)

- Fixed left-swipe cycle: Home → Codex → Deepseek → SUPER → HERMES → Home.
- Deepseek activates only `com.deepseek.dsh`. Only CYCLE is displayed; center,
  up/down/right and physical action buttons do nothing. Power controls remain.
- The fixed `deepseek` mode uses the existing 15-second connection-owned lease
  and five-second Companion renewal. Its dedicated navigation only accepts left.
- Home center taps run a 360ms eye-closing/opening animation on the selected
  character. Repeated taps during a blink do not queue or restart it. Speech
  requests and talking animation are removed from Home, even with private audio.
- Up/down/right character selection, wake-only first touch, Home pinning and
  cancellation on mode/sleep/power transitions remain unchanged.
- All four decorative portrait rings are removed in derived image assets.
  Original JPEG artwork is preserved. Feathered outer-edge masking can also
  remove shoulder pixels touching the old ring; visual acceptance is required.

## Source validation

- Companion Release build with warnings-as-errors: passed.
- Temporary Swift production-source harness: 92 test bodies passed. This is not
  a complete XCTest run; `swift test` fails because this host lacks XCTest.
- HID RPC probe offline self-test: passed; no live HID write was performed.
- 17 native C++ test executables passed with warnings-as-errors; actual Home
  gesture and silent-reaction compiled harnesses passed.
- Python derived-art checks, Swift JPEG decode/rim checks and Ruby native
  framebuffer eye-only blink checks passed for all four characters. Actual
  gesture tests also confirm Deepseek up/down/right send no events or feedback.
- Native framebuffer renderer compilation passed. Previews still need human
  visual acceptance; image input was unavailable to the implementation agent.
- USB microphone recording-validator synthetic self-test: passed, not a device
  recording.
- Basic `m5stack-stopwatch` firmware compilation: passed.
- Selected USB-mic firmware and `prepare-bluedroid`: compiled successfully.
  USB-mic usage: 99,988 bytes RAM and 1,742,207 bytes application flash.
  The first invocation completed both builds but exited on a user-level
  PlatformIO configuration permission error; the approved exact-command retry
  completed with exit code 0. No dependencies were upgraded.
- New Deepseek tests cover strict mode parsing, Home resync, lease ownership,
  renewal/expiry/disconnect, left-only event serialization, input isolation,
  rendering labels, exact bundle matching, activation failures and full cycling.

## Deployment and acceptance

This source change has **not** been installed or flashed. It does not establish
physical C152, app activation, Bluetooth, microphone, quota or visual success.
Use the matching new Companion and explicitly selected USB-mic firmware; an old
Companion cannot provide the new five-workspace cycle. Preserve a matched backup
before installation. Follow AGENTS.md recovery and exact-port confirmation rules;
never flash an inferred port or replace an installed service without approval.

Physical acceptance should include a full left cycle, Deepseek cold/background
activation and failure/no-skip, absence of unwanted Deepseek/Codex actions,
all four Home blink/character combinations, no central-tap speech, sleep/wake,
power cancellation, reconnect/15-second fallback, and existing SUPER/Hermes,
USB microphone and quota behavior. Native framebuffer previews are design
outputs, not device photographs or proof of animation smoothness.

The pre-existing local BLE bond-revision change is preserved, not introduced by
this feature. Review that migration separately before deployment.
