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
- USB-mic PlatformIO build: passed, 1,484,704-byte firmware, SHA-256
  `50b369e7b3bdfa9d2f2dd61861003e1304bd5d3abb067e890682f4d87c11c0cf`.
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

Not yet performed for this image. No C152 firmware was flashed during the
implementation and verification above. Character selection, repeated-direction
toggle, center speech on all portraits, sleep/power behavior, microphone
priority and the Codex/SUPER/HERMES regression remain **unverified on physical
hardware** until the user approves the previews and a freshly enumerated
download port.
