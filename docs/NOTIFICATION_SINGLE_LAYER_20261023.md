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
readback and protected-area check. No flash or service replacement has occurred
for this candidate. Physical acceptance remains required after a later update.
