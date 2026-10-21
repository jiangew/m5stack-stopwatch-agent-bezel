# Unified workspace UI validation

## Scope

The approved 2026-10-21 design changes DSH/SUPER/HERMES rendering and
notification typography only. Codex rendering, input routing, palette selection,
haptics, Home geometry, native adapters and Companion are unchanged.

Notification source headings use Codex / DSH / Super / Hermes. Only known
Super-generated titles are normalized; raw card content is unchanged. Existing
18/46 px font assets are reused unchanged; additional 15/22/24 px assets are
reproducible from the bundled Space Mono TTF. All text renders at scale 1.
Missing model data remains hidden; native model capture is outside this release.

## Source and build checks

- Initial focused renderer tests rejected the old triangle/bitmap-font API.
- All 25 C++ host regression executables passed with ASan/UBSan.
- Notification firmware tests passed, including actual main-loop swipe ownership,
  consecutive browse gestures, Home-only badge entry and default/USB-mic paths.
- Host notification broker/transport suites and 14 CLI/coupled tests passed.
- Actual workspace launch, Home swipe/IMU, haptics and audio-owner Ruby tests passed.
- Actual drawScreen native tests passed for default + USB-mic, Codex state pixel
  equality, directional pages and 17 Home characters. Native Home spacing passed.
- Native frames inspected: all three directional pages, pending states, short and
  192-byte notification bodies, read-only detail, decision pages, badge 1/9/10/64.
  Representative visible pixels stay inside the physical round screen.
- Font regeneration matched the checked-in header byte for byte. Existing
  SpaceMonoVlw.h and DashboardUi.h have no changes. git diff --check passed.
- Standard firmware and native-preview builds passed.
- Selected USB-mic + Home IMU build passed: RAM 108228/327680 bytes,
  linked application 2677003/6553600 bytes, application image 2710080 bytes.
- Candidate application SHA256:
  ce634a0ffa8d7e4a9d594633a73f26259a87107841a1b5ec3276712d7a7a04c3.

## Device release gate

Application from source commit `3e9c8dc133b9df50a51deee7da01d2b162472f55`
was written after explicit confirmation of the exact live port. The existing
accepted C152 identity, 16MB capacity and actual partition table were checked.
Complete app0 (0x640000 bytes) and protected 64KiB backups matched the accepted
baseline and remain in private storage. Only app0@0x10000 was written.

- Esptool write hash passed.
- Independent 2710080-byte application readback matched the candidate byte for byte.
- Protected 64KiB matched its original backup byte for byte, preserving bootloader,
  partition table, NVS and OTA metadata.
- Updater completed with UPDATE VERIFIED; private installation receipts updated.
- Automatic hard reset left USB in its download personality. A single physical
  RESET was requested before runtime acceptance. Initial post-reset HID probes
  found no vendor HID device; runtime verification is still pending.

Physical acceptance remains pending: unified circles/fonts, notification
browsing/BACK, workspace taps and all four swipe actions, Home IMU, BLE/HID and
USB input-only audio. Native pixels and build results do not prove device feel,
latency, microphone quality or physical gesture acceptance.
