# Robot Home four-character verification

Date: 2026-09-20

Branch: `codex/robot-voice-public`

Implementation baseline: `536499b`

## Implemented contract

- Home and every later Home visit start on Bumblebee.
- Up selects Optimus Prime, down selects Megatron and right selects Starscream.
- Repeating the direction for the selected target returns to Bumblebee.
- Character selection is local-only, silent and non-haptic; it emits no HID or
  workspace action.
- Center tap on every portrait keeps the existing task-speech ownership and
  talking animation. Left keeps the existing Home-to-Codex behavior and haptic.
- Four original 300x300 baseline JPEG portraits are embedded in flash. The
  runtime performs no filesystem or network asset lookup.
- Companion 0.1.4, Report ID 6, workspace leases, navigation mappings and the
  LaunchAgent are unchanged.

## Automated evidence

- 17 native C++ tests: passed with `-std=c++17 -Wall -Wextra -Werror`.
- Four production-source Ruby harnesses: passed.
- Deterministic art generation: a fresh `embed_robot_home_art.rb` output is
  byte-identical to `include/RobotHomeArtData.h`.
- M5GFX native preview build: passed. The compiler reports the existing
  third-party `LGFXBase.hpp` variable-length-array warning; project-owned code
  adds no warning.
- Native framebuffer previews were generated for all four settled portraits,
  the transition midpoint, Talking state and power overlay. Connection and
  battery chrome remain clear of the portrait.
- USB-mic PlatformIO build and upload: passed, 1,484,624-byte firmware,
  SHA-256 `4fe1031793eba42b96feec54895840fa8b6b92c676519e4e22730e1bf6313b5b`.
- Default wireless PlatformIO build: passed, 1,309,520-byte firmware, SHA-256
  `8bd342d3cf6f462660a9fbacd0d319c3cec6ddc9a12a2464bbd5b5f4f1cd13fe`.
- `git diff --check`: passed.

## Asset provenance and integrity

The portraits were generated specifically for this project from the
user-approved concept, then cropped and converted locally. They are not film
frames, official logos or downloaded runtime media.

| Portrait | Source JPEG SHA-256 |
| --- | --- |
| Bumblebee | `eefb63d0e80005042322d18ce3f364172b742090ea4766eae3a7eb15be274f5c` |
| Optimus Prime | `9089e86a358b5475f169fec8ed51d73f6b3ba05eefcb8394db9b312d3add7ad4` |
| Megatron | `3f87f0a450906c8d6a8f65a2db505636adedc66e4a224a064070e8275f52cd04` |
| Starscream | `b85e11fe26d1ee366186ffab25f5214fe8eb0ed08b17d0ab04a9c5a7c657e396` |

Private `RobotSpeechLocal.h` remains ignored and is not part of the public
change. The repository still builds without private speech samples.

## Physical acceptance

Firmware upload completed successfully on 2026-09-20; esptool verified every
written segment before resetting the C152. Character selection, repeated-direction
toggle, center speech on all portraits, sleep/power behavior, microphone
priority and the Codex/SUPER/HERMES regression remain **unverified on physical
hardware** until the user completes the checks below. The upload used the
freshly enumerated and explicitly confirmed download port; no historical port
authorization was reused.

## 2026-09-21 ring repair

- User confirmed interactions recovered after restarting macOS. Read-only
  checks found the BLE HID device, a single Companion and successful quota
  writes. This does not establish the cause of the earlier HID failure.
- User approved four reframed portrait previews. The original Megatron and
  Starscream source images already clipped the top rim; translating the
  whole bitmap could not restore missing pixels.
- Built-in image editing preserved the four character designs and repaired
  framing. Prompt constraints: complete centered 360-degree colored ring,
  approximately 5% black safety margin, unchanged face/armor/style, no text,
  logos or added ornaments. Approved outputs were converted to 300x300 JPEGs
  and embedded with the existing generator.
- Added `simulator/robot_home_art_test.swift`, decoding the actual JPEGs via
  ImageIO. Every 2-degree sector must contain a saturated rim in a centered
  annulus. RED: the original four assets failed; GREEN: all replacements pass.
  This is an image geometry regression check, not XCTest or proof of physical
  display appearance.
- All 17 C++ native tests and four Ruby-driven production-code tests passed.
  Header regeneration was byte-identical; `git diff --check` passed.
- Seven native framebuffer scenarios rendered successfully. Visual review
  confirmed intact rings and clear connection/battery chrome on all four
  settled portraits, plus Talking and power overlay. Native M5GFX build retains
  upstream VLA/empty-object warnings; no project-owned warning was observed.
- USB-mic build passed. Initial sandbox-only PlatformIO cache cleanup errors
  were resolved by rerunning with access to its existing cache; final run
  completed without those errors.
- New firmware: 1,721,536 bytes; SHA-256
  `637b6c856faf04676da3fbc19b2ed6d1b3de827e80194a5ed1b938b518cdb454`.
  Previous firmware and original portraits were backed up before replacement;
  previous firmware SHA-256
  `5f80a40bf83c634694230fb0418257feb7e6a19556ca13b188ba06b8b88475fc`.
- Existing BLE changes and private speech bytes were preserved unchanged in
  this visual-only pass. Companion, permissions and LaunchAgent were untouched.
- New image SHA-256 values (supersede the earlier source table):
  - Bumblebee: `e441e880d5846a74bf848e4e7d131a1fc961929b128d7abc6647f70560d28721`
  - Optimus: `da28f6e48968c5aac52f8c345057de4c0c1da52f83222700a1bee66136bbe718`
  - Megatron: `54f2a18742d986beb721b068ca9fb3fdb5a8ae20727ca8039b1844153606da92`
  - Starscream: `807889c9cf87615236d324947e60750b86e56db267a187bcb1fd29915b308da0`
- Upload completed after fresh download-port enumeration and explicit user
  confirmation. PlatformIO exited successfully; esptool verified written data,
  including the 1,721,536-byte application, and issued a hardware reset.
  Physical acceptance is recorded below. No full-chip erase,
  Companion replacement or new pairing reset was performed.

### Post-upload acceptance

- User reported all requested checks normal: four-character centering, complete
  Megatron/Starscream top rings, center speech, character selection and left
  workspace switching. These are user-observed results, not inferred from logs.
- Read-only checks confirmed BLE vendor HID enumeration, one Companion process,
  USB microphone enumeration with one input channel at 48 kHz, and a fresh
  successful quota write.
- USB enumeration is not an audio capture test. A new recording/playback test,
  long-duration stability and the full unrelated workspace regression suite
  were not separately performed for this visual-only update.
- No merge or push was performed during this repair.
