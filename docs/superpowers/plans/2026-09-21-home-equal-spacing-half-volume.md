# Home equal spacing and half-volume follow-up

Approved scope: retain the enlarged portraits; align status, visible circle
and battery group horizontally, balance the two clear vertical gaps, remove
upward Talking motion and halve only the current central speech amplitude.

## Implementation and evidence

- Real renderer RED reproduced unequal Home gaps: 13px above, 31px below.
- The approved JPEGs have asymmetric black padding. Per-character visible rim
  anchors now position their circles around (233,232), between status ink
  ending at y=50 and battery starting at y=414. Bitmap centers are deliberately
  not used as a proxy for visible centering. Talking scales around this anchor
  without vertical translation.
- Added `robot_home_spacing_test.rb`, invoking the actual native renderer and
  checking RGB565 framebuffer pixels. Run with the native preview executable
  as its sole argument. All four settled and four Talking-peak scenes pass:
  horizontal center error <=1px, upper/lower gap difference <=1px, clear gap
  >=10px. Settled gaps: Bumblebee 22/22, Optimus 19/19, Megatron 22/21,
  Starscream 20/19. Tiny variation reflects the approved source rings, whose
  diameters are not identical; no resizing redesign was introduced.
- All 17 C++ tests, four existing production-code Ruby harnesses and four
  asset ring checks pass. Expanded C++ animation-frame tests still pass.
- Native preview and USB-mic builds pass. Native M5GFX retains the existing
  third-party VLA warning. Final previews were refreshed for all characters.
- All 77,433 central PCM samples were verified equal to previous samples
  multiplied by 0.5, within 1 integer quantization unit. Duration is unchanged;
  secondary clip is byte-identical. No speaker gain, chime, microphone, audio
  ownership, or USB descriptors changed. Private samples remain ignored.
- Half-volume WAV SHA-256:
  `40d5f40f394358f86e4e2fcff1faf50ed5c29ae01f32bcfc9a1a0bd5872c8e49`.
- Previous firmware and private header backed up before modification.
- Final USB-mic application: 1,706,960 bytes; SHA-256
  `eb6f3506e39f26ce2a0a7ad90cdfa7ce6adcf79665add0e4728c5bd43c422a0c`.
- Existing BLE working-tree changes remain untouched; no Companion,
  permissions or LaunchAgent changes. No merge or push.

## Installation boundary

Upload completed after fresh download-port enumeration and explicit user
confirmation. PlatformIO exited successfully; esptool verified all written
segments, including the 1,706,960-byte application, and issued a hardware reset.
No full-chip erase or pairing reset was performed.

## Physical acceptance

After being asked to restart the watch and check centered/equally spaced status,
portrait and battery, reduced central speech level, character selection and
four-workspace controls, the user reported: “ok，一切正常”. These requested
checks are accepted based on the user's physical observation, not inferred
from upload/build success. No additional microphone recording test was requested
or performed in this follow-up. No further device, Companion or configuration
changes were made; merge and push remain outside this follow-up.
