# Home IMU Pilot Implementation Plan

> Execute inline with writing-plans, test-driven-development and verification-before-completion. The user selected implementation and physical trials on 2026-10-15; no further design selection is needed.

**Goal:** Add a reversible Home-only pickup, tilt and settled interaction pilot and prepare evidence for false activations, response latency and power comparisons.

**Architecture:** An allocation-free, host-testable detector consumes accelerometer (g), gyro (degrees/second) and monotonic timestamps. The optional USB-mic-derived pilot targets 50 Hz sampling, keeps touch/host controls independent, composes bounded portrait transforms and exposes read-only diagnostic snapshots through a dedicated control-only RPC. The existing production environments remain opt-out by build flag. Physical diagnostic polling currently observes about 32 Hz, so the target is not a measured rate.

**Tech Stack:** C++17 native assertions, M5Unified BMI270, M5GFX native preview, Arduino/PlatformIO, Swift IOHID probe.

## Global constraints

- Baseline: clean main 259f307; work on codex/home-imu-pilot, no push/merge.
- No changes to USB descriptors, account credentials, Companion installation or pairing.
- Only robot Home responds. Touch, overlays and haptic motion suppress/rebase detection; workspaces never emit IMU-derived host actions.
- Qualify motion for 60 ms; require 1500 ms continuous stillness; reject nonfinite/unphysical input and sample gaps above 120 ms. Initial/reentry calibration requires stillness.
- "Settled" means IMU stillness, not proven table contact. Slow constant-velocity translations can be unobservable.
- IMU wake applies to automatic Home desk sleep, not intentional red-button sleep, power confirmation or travel shutdown.
- Existing C152 current API returns unsupported zero. Report current as unavailable, never 0 mA measured. Voltage/percentage are only coarse battery proxies.
- Physical flash requires exact live target confirmation per AGENTS.md. Preserve app-only recovery and existing partition/NVS/OTA metadata.

## Task 1: Detector and meaningful native tests

Files: create include/RobotHomeImu.h and simulator/robot_home_imu_test.cpp.

- [x] Write tests with synthetic timestamped sensor traces: still/noise, short knocks, sustained motion, bounded tilt, settle dwell, gaps, bad samples, wraparound, reset and disabled policy.
- [x] Run the test with a minimal no-op detector; confirm a pickup assertion fails before implementing recognition.
- [x] Implement fixed-state filtering/hysteresis and event counters; rerun with sanitizers. Synthetic latency is algorithm-only, not physical acceptance.

Run: `clang++ -std=c++17 -Wall -Wextra -fsanitize=address,undefined -Iinclude simulator/robot_home_imu_test.cpp -o /private/tmp/home-imu-test && /private/tmp/home-imu-test`

## Task 2: Home composition and firmware integration

Files: include/RobotHomeCharacters.h, include/RobotHomeUi.h, src/main.cpp, usb-mic/platformio.ini, simulator/robot_home_ui_test.cpp, simulator/preview_main.cpp.

- [x] Add failing portrait-composition assertions before implementing tilt/rest transforms.
- [x] Add the separately selected `m5stack-stopwatch-home-imu` environment with `CODEX_STOPWATCH_HOME_IMU=1`.
- [x] Sample only Home; no per-sample allocations, haptics or logs. Throttle redraws and stop drawing unchanged static poses.
- [x] Add Home-only two-side-key hold toggle for same-image A/B tests, suppress touch/motor self-triggers and reset across workspace/power boundaries.
- [x] Render native pickup/left/right/rest examples using the production portrait cache; inspect resulting pixels.

## Task 3: Read-only diagnostics and host collection

Files: include/HostRpcRequest.h, include/CodexMicroBle.h, src/CodexMicroBle.cpp, scripts/hid_rpc_probe.swift, simulator/host_rpc_request_test.cpp.

- [x] First test classification of `device.imu` as control-only, ensuring diagnostics cannot renew the host/workspace lease.
- [x] Expose bounded latest raw sensors, counts, event/qualification timestamps, sample gaps, read timings and event-to-frame submission timings only for the pilot.
- [x] Add JSON output and repeated collection mode to the existing IOHID script. Preserve response ID matching and fragmentation checks; verify via its self-test.
- [x] Mark lack of battery current support explicitly; include voltage, VBUS and brightness for matching trial conditions.

## Task 4: Verification and physical evidence

Files: docs/HOME_IMU_PILOT.md, README.md, README.zh-CN.md.

- [x] Run changed native tests plus existing Home, input, power and RPC regressions.
- [x] Build default firmware, native preview and selected USB-mic pilot, using existing dependency caches.
- [x] Document 10-minute still/tap/desk-noise false-trigger trials, 30 pickup cycles and 30 tilt trials; report counts with denominators and misses separately. Proposed target: no static false pickup; pickup >=29/30; physical onset-to-visible P95 <=200 ms; tilt <=150 ms; rest 1.5–2 seconds. Targets are unvalidated until measured.
- [x] Document external current A/B measurement (same brightness, BLE, audio, charge state); use steady windows and report mean/peak/integrated energy. Without meter, perform repeatable long battery comparisons and retain uncertainty.
- [x] Before flash: resolve exact C152 port, preserve baseline binary/readback and protected metadata, request target-specific confirmation, app0 only. Independently verify application digest and protected metadata; restore runtime and separately verify USB input audio, BLE/HID diagnostics and manual motion feedback.
- [ ] Full physical host-control/power-button regression and physical onset-to-visible latency remain unmeasured; native adapter regressions do not substitute for those checks.
- [x] Record scope change: user chose to stop before the 30-cycle protocol after normal feedback; exact action denominator is unconfirmed. User has no power meter and explicitly deferred power measurement.
- [x] Publish a local result record separating synthetic tests, builds, native previews and physical measurements. Controlled desk-still window: 600.80 seconds, 600 snapshots, zero unintended pickups, zero new sensor-read errors. User-confirmed interaction feedback is qualitative; fixed-count hit rate, interference scenarios, physical onset latency and power remain unmeasured.
