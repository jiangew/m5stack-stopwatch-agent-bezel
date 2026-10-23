# Notification footer buttons — 2026-10-23

Implementation:`87fe36a5de6288777e3e5e5ed43619dcf7376dbf`.
User approved two filled BACK/OPEN buttons and two rows of gesture hints, replacing
the single OPEN/bottom-wide BACK layout. See the approved footer design and plan.

Native22px labels,14px hints and shared render/hit geometry preserve centered
22px/28px body excerpts. MORE ON MAC and standalone bottom BACK are removed.
Overflow retains ellipsis; read-only legacy excerpts use the same bounded body.
Native decision-capable complete scope and hold flow remain unchanged. Buttons
have8px separated hit padding; targets lock on press,20px movement cancels taps,
existing52px swipes retain priority. Protocol, Companion and collectors are unchanged.

Controller regressions first failed against the prior footer action behavior;
renderer regression first failed on the old button count/layout. Full host
parser/controller/UI/main-loop/legacy checks passed (ASan/UBSan where applicable).
Native, standard and selected USB-mic+Home-IMU builds passed. Six synthetic native
framebuffer samples were inspected; header/footer RGB pixels agree between English
and Chinese fixtures. Browser gallery shows both language layouts without overlap.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| standard-application.bin | 2263968 | `2afa7eb1dfac3a54537aebab640b645f4992481852c985252c8df3367b7f13ae` |
| usb-mic-imu-application.bin | 3595136 | `27eb852571f8e7a601a8403829bd2a11853ce3cbb3d9111eac5854f72ce3a580` |

Independent focused review of038659f..87fe36a found no actionable issues and
independently reran the firmware regressions through success. Candidate prepared
only: exact-port confirmation, app-only flash/readback/protected comparison and
physical acceptance remain separate gates.
Installed single-layer source9fd2369 remains the rollback baseline. Its layout and
gestures were user accepted, and a real Codex OPEN succeeded with accurate upper
button taps; reliable bottom targeting motivated this revision. DSH remains app
activation only. No Mac replacement, main merge or remote push was performed.
