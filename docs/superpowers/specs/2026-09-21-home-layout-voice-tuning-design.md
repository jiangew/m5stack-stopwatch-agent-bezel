# Home layout and mechanical voice tuning

Status: approved in conversation, including native preview and menacing v3 audition.

## Scope

- Home only: move connection label center from y=64 to y=44.
- Move the complete battery group down 25px, from y=395 to y=420.
- Enlarge the visible portrait rim from approximately 255px to 320px diameter.
  Keep horizontal center x=233; move the bitmap center to y=225.
  Set settled JPEG scale to 1.18, transition start to 1.04; retain Talking
  scale pulse. Limit upward motion to 3px (previously 4px) to preserve peak
  clearance beneath the status text, as verified across the full animation.
- Preserve the four approved artworks and intact circular borders. No cropping
  or stretching; the 466x466 display's circular edge must not clip the result.
- Central speech retains the fixed line: 愚蠢的人类，快给我下发任务吧！
  Use an original locally synthesized deep, raspy metallic antagonist-style
  effect with intelligibility prioritized. It is not a movie recording or a
  cloned performer's voice. Audition approval precedes embedding.
- All portraits use the same central speech; up/down/right remain silent
  character selectors. No changes to gestures, timing, BLE, protocol,
  Companion, permissions, LaunchAgent or USB audio descriptors.

## Preview and verification

Preview changes are made in a disposable renderer copy first. Show native
466x466 output and a local WAV audition. No production renderer or existing
private speech is replaced before approval.

After approval, use test-first renderer updates: label/battery positions,
portrait centering and all transition/Talking frames must avoid chrome and
screen boundaries. Run native tests, production audio-owner harnesses and
USB-mic build. Keep private audio ignored; back up matching current firmware.
Fresh download-port enumeration and exact-port confirmation remain mandatory.
Physical appearance and sound quality require user observation after upload.
