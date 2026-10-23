# Single-layer notification candidate — 2026-10-23

Implementation source:`9fd236998f454e259299b957cb1e9dc7126afa31`.
The user accepted the native single-layer preview and requested update preparation.
The installed reply-model release remains the separately accepted baseline.

Read-only notices stay in one reading page: body taps do not open another layer;
OPEN ON MAC has a separate visible button. Tapping a transient notice pins the
same view and its host selection. Browse/dismiss/Home exit and complete native
decision scope/hold protection remain intact. Rich English body uses native22px;
CJK24 glyphs are scaled22/24, with28px baseline spacing and five excerpt rows.
Titles, model/time, status and Home/Agent layout are unchanged. Legacy192-byte
ASCII scope remains complete above the footer.

Controller tests were observed failing for the old Detail transition and missing
Toast host pin before the corresponding changes. Renderer tests failed for the
missing first-page OPEN button before rendering changes. Final parser/controller/
UI/main-loop/legacy regressions passed under ASan/UBSan where applicable. Native
preview, standard firmware and selected USB-mic+Home-IMU builds passed.

Six synthetic native framebuffer samples were generated; the user accepted the
Chinese/English body size and footer layout. PNG export uses the original RGB
pixels directly after a separate image conversion/display anomaly; no firmware
rendering workaround was introduced. This is preview acceptance, not acceptance
of an updated physical device.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| standard-application.bin | 2252944 | `da0cbebda27d6fb3ae7e05b94a94c3fc0c8d00beb7a88401ce0b17f0933d2313` |
| usb-mic-imu-application.bin | 3584160 | `c747d75d3d326b508335c2a2ce6bb5a08cf35b8e0f563666270ae95f4a727c8f` |

Only firmware needs updating. Installed Companion/collectors remain compatible;
no App replacement or renewed macOS permission setup is required. Private update
scripts retain the exact-port confirmation, known C152 identity, complete app0 /
first64KiB backups, accepted-baseline comparison, app-only write, independent
readback and protected-area check. With exact-port user confirmation, the selected USB-mic+Home-IMU image was
written to app0 on the known C152. Full previous app0 and protected first64KiB
backups passed; the baseline matched the accepted reply-model image. Write hash,
independent application readback and protected-area comparison passed. No Mac
service or application replacement occurred. The user reported a light RESET;
normal USB microphone enumeration, HID device-status and IMU RPC passed. A short
input-only capture yielded96256 frames, mono48kHz16-bit PCM,2.005333333 seconds;
the WAV was deleted. This validates format/continuity rather than acoustic quality.
Two synthetic single-layer notices were sent through the installed bridge. The
user accepted body size/spacing, single-layer display, browsing/dismiss/Home exit,
Home tilt and Agent controls. The user initially reported no response from OPEN and then clarified the watch
returned Home. Read-only action observation captured CLOSE on a real Codex notice;
subsequent upper-button taps produced OPEN dispatches, and the user confirmed the
watch stayed on the page while Mac opened the correct task. This accepts the Codex
route, not reliable footer targeting. The user requested separate filled BACK/OPEN
buttons and two hint rows. DSH remains application activation only; exact-session
navigation is outside this update. Overall footer acceptance awaits the revision.
