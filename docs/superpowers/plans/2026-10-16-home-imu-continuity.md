# Home IMU Continuity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement the task below, with TDD, task review and a final branch review. The user approved implementation and candidate builds on 2026-10-16; do not request another design or execution choice.

**Goal:** Reduce pickup-to-tilt lag and the delay before settled feedback, while preserving the physically accepted coordinate mapping and input protections.

**Architecture:** Use elapsed-time acceleration smoothing in the existing detector. Keep initial/recovery calibration separate from the shorter Held-to-Resting dwell. Reuse the Home frame clock's render-start timestamp for changed IMU frames instead of adding cadence after transfer completion.

**Tech Stack:** C++17, actual-main-function native adapter fixtures, Ruby, Swift IOHID self-test, PlatformIO/M5Unified/M5GFX.

## Global Constraints

- Continue clean feature branch `codex/home-imu-pilot` in the existing project checkout; no push/merge and no device flash.
- The user selected the optional USB-mic-derived Home IMU environment. Build default firmware and `usb-mic` environment `m5stack-stopwatch-home-imu`; do not install dependencies or alter Companion/pairing.
- Target M5Stack C152 only. Preserve first-pilot mapping: roll drives angle/x; pitch drives y. Preserve amplitude bounds, 60ms pickup, 120ms maximum gap, invalid-sample protection and 250ms physical-input quiet interval.
- Held-to-Resting continuous stillness becomes 600ms; initial/recovery calibration stays 1500ms. Any non-still sample restarts the stillness dwell.
- Smoothing uses time constant 60ms: `alpha = 1 - exp(-elapsedMs / 60.0f)`. Compute unsigned elapsed time before updating `last_`; initialization and reset seed filtered acceleration from the current valid sample. Preserve timestamp wraparound behavior.
- IMU redraw cadence measures 34ms from render start. A slow 65ms render must allow changed motion on the next loop; unchanged motion must not cause constant redraws. Touch, telemetry and final animation frames retain their existing priority.
- Do not loosen or redesign reset/recalibration rules without new evidence. Do not claim the existing 600.80-second zero-false-pickup trial validates changed firmware.
- Never commit credentials, device addresses, account identifiers, home-directory paths or audio. Keep candidate binaries, hashes and logs in ignored local artifacts; no new firmware is physically accepted before it runs on the device.

### Task 1: Implement and verify continuous motion timing

**Files:**
- Modify: `include/RobotHomeFrame.h`, `src/main.cpp`, `include/RobotHomeImu.h`.
- Test: `simulator/robot_home_frame_test.cpp`, `simulator/robot_home_imu_main_test.rb`, `simulator/robot_home_imu_test.cpp`.
- Create: `simulator/robot_home_imu_continuity_test.cpp`.
- Update: `docs/HOME_IMU_PILOT.md`, `README.md`, `README.zh-CN.md` and this plan's task checkboxes.

**Interfaces:**
- Existing `FrameClock::presented(startMs, animated)` owns the previous render-start time.
- Add `bool FrameClock::motionDue(std::uint32_t now, bool changed) const`; consumes changed pose, produces cadence eligibility without mutating the animation clock.
- Keep `Detector::update(const Sample&, uint32_t)` / Result / telemetry schema unchanged.

- [x] **Step 1: Reproduce extra frame waiting against actual main code.** Extend the adapter fixture to compile the actual `bool imuFrameDue=false; ...` selection block from `main.cpp`, and keep existing hardware stubs. Include the real `RobotHomeFrame.h`, enable the pilot macro and expose a fixture function with `robotNow`/`homeVisible`. With a frame started at130ms, completed at195ms and a changed pose at200ms, the actual selection must be true; it is false on the old code. Also cover an unchanged pose, a fast-render sample before34ms, at34ms and wraparound. Assert observable eligibility, not source text. Run the adapter test and save its expected assertion failure.

- [x] **Step 2: Implement start-based cadence.** Use the existing clock state:

```cpp
bool motionDue(std::uint32_t now, bool changed) const {
  return changed && (!valid_ || static_cast<std::uint32_t>(now-last_) >= 34);
}
// main.cpp IMU selection:
imuFrameDue=robotFrames.motionDue(robotNow,imuPoseChanged(robotImuPose,robotImuRenderedPose));
```

Run the actual adapter and frame clock tests. Keep `presented(homeFrameStartedMs, ...)` unchanged and preserve existing FrameClock::due semantics.

- [x] **Step 3: Reproduce sampling-dependent tilt lag.** Add a real-detector test with startup calibration, one pickup, then a10-degree roll step with gyro25dps. At sample intervals20/30/45/60/90ms, after180ms the returned angle must be between1.70 and2.00degrees (final unsaturated target is1.89degrees); reverse the roll and assert a clear negative response within180ms. Use literal physical fixtures, not the production filter formula as the test oracle. Show the test fails against the fixed20% filter before changing it. Cover stable pose and wraparound in the new temporal path.

- [x] **Step 4: Implement elapsed-time smoothing.** In the valid-sample path, after initial sample seeding and before updating `last_`, compute unsigned elapsed time and use:

```cpp
const float alpha=1.0f-std::exp(-static_cast<float>(static_cast<std::uint32_t>(now-last_))/60.0f);
fx_+=alpha*(s.ax-fx_);fy_+=alpha*(s.ay-fy_);fz_+=alpha*(s.az-fz_);
```

Run new continuity and existing detector tests with sanitizers. Preserve reset behavior and actual board mapping. Do not add gyro integration or another attitude subsystem.

- [x] **Step 5: Reproduce late settled feedback.** In the continuity test, establish Held, change to still and then record the first qualifying still sample. At580ms since that sample no settled event is allowed; at600ms one settled event and the resting pose must appear. Repeat stillness without duplicate events, then immediately perform another pickup/tilt/settle. Add an interruption at400ms and verify it restarts the600ms dwell. Assert startup is still Calibrating before1500ms. Run this test against1500ms Held dwell and save the expected failure.

- [x] **Step 6: Separate calibration and settled dwell.** Keep a1500ms calibration duration and set Held dwell600ms. Choose the duration from the current phase in the stillness block. Update the old test's waiting assumptions to the approved600ms contract, without removing isolated-knock, noise, interruption, invalid/gap and wraparound coverage. Run all changed tests, plus existing Home UI/interaction/motion/frame and input regressions appropriate to these paths.

- [x] **Step 7: Build and record candidate status.** Build default firmware and selected pilot with existing caches, sequentially to avoid shared build locks. Run `ruby simulator/robot_home_imu_main_test.rb`, the detector/continuity/frame tests, and the Swift probe self-test. Build native preview if supported by the existing environment. The local completion chime remains skipped while the host streams microphone audio. Do not flash or reset the device.

```sh
pio run -e m5stack-stopwatch
pio run -d usb-mic -e m5stack-stopwatch-home-imu
HOMEBREW_PREFIX=/opt/homebrew pio run -e native-preview
ruby simulator/robot_home_imu_main_test.rb
```

- [x] **Step 8: Document, commit and self-review.** Distinguish the physically deployed first pilot (fe28100 /5bdd3ed9026a) from the new unflashed candidate. Mark old1.5s results and old zero-static-false-pickup result as first-pilot evidence. Explain the new600ms Held dwell, retained1500ms calibration, elapsed-time filter, render-start cadence, possible increased redraw power and pending physical retest. Keep frozen first-pilot artifacts intact. Stage exact changed paths; commit code/tests and final documentation. Record test commands, expected red failures, green outputs and build results in the task report. Return status, commit IDs, brief test/build summary and concerns only.


### Final review fix wave: automatic pickup wake continuity

Final whole-branch review found one P2 integration issue inherited from the first pilot: Pickup called `noteActivity()` and synchronously presented its pose, then unconditionally marked the same frame dirty again. This could create two65ms renders plus the8ms loop delay before sampling and trigger the unchanged120ms gap protection. The65ms duration comes from prior first-pilot frame measurements; this is deterministic modeled integration evidence, not candidate physical validation or an explanation of earlier ambiguous recalibration logs.

- [x] Add the failing regression before production edits. Extract actual `noteActivity()`, `wakeDeskSleep()`, Home presentation bookkeeping, IMU adapter and main frame selection; stub only hardware/raster boundaries. Expected RED: automatic pickup wake presents two frames where one is required.
- [x] Move event dirty marking before synchronous wake. Ordinary awake pickup still leaves its frame pending; a synchronous wake draw can consume it. Preserve input/state/final-animation priorities, all detector timing, calibration/filter/mapping and the120ms reset contract.
- [x] Verify one65ms wake frame, no unnecessary outer frame, retained Held at the next73ms sample after the8ms delay, and continued positive tilt. Re-run actual adapter and affected Home/input/draw/reaction regressions; frame/detector/continuity suites pass with ASan/UBSan.
- [x] Commit code/tests first as `43d8e91`; build default and selected Home IMU environments sequentially from that clean committed source using cached dependencies. Do not rebuild unchanged native preview.
- [x] Preserve pre-fix candidate binaries and manifest exactly. Freeze uniquely named post-wake-fix images and a separate manifest with complete SHA256/size/source commit, `deployed:false` and supersedes links in ignored local artifacts. Record red/green/build/self-review evidence in the local final-fix report.
- [x] The implementation/fix wave itself retained the first pilot with no flash/reset, host/Companion change, dependency install, push or merge. Subsequent device actions required separate exact-target authorization.

### Subsequent user-authorized deployment and physical follow-up

- [x] User reconnected C152 and entered ROM download mode. Resolve the actual single ESP32-S3 ROM port; independently verify accepted first-pilot application, expected16MB flash/8MB PSRAM and current protected metadata/partition/activeapp0. Preserve first-pilot rollback image.
- [x] After user explicitly confirmed source43d8e91/image6cc50998db76 for the exact resolved device, write app0／0x10000 only. Write verification, independent application digest and byte-identical first64KB checks passed; standard watchdog reset restored runtime. USB input enumeration, IMU/BLE HID diagnostics and3.008s temporary audio check passed; recording deleted.
- [x] User completed a few sequences and confirmed pickup-to-tilt feels more responsive with noticeably less lag. A separate1Hz motion window was stopped after a129ms maximum gap to reduce observation overhead; end snapshot counters were5 pickups/3 settles/errors0. Actual cycle denominator is unmarked; no hit/miss rate or physical onset latency claim.
- [x] New-version10-minute user-confirmed desk-still trial completed with only start/end status reads:601.22s host/601.232s device time, zero unintended pickups, zero new settled events and zero new read errors. Endpoint availability/active/Resting remained valid; lifetime gap maximum129ms did not increase. Keep first-pilot evidence separate.
- [ ] Fixed-count hit rate, interference, physical onset latency and independent physical auto-sleep-wake timing remain unmeasured. Power remains deferred by explicit user choice. These limits do not turn qualitative user feedback into quantified latency acceptance.
