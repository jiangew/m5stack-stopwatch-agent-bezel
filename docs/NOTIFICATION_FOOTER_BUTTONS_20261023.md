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
independently reran the firmware regressions through success.

After explicit confirmation of the resolved device port, the selected USB-mic+IMU
image was written to app0 at0x10000 only. The full previous app0 and protected
64KiB backups were verified before writing. Independent application readback
matched the selected image byte for byte; the protected64KiB remained unchanged.
The updater finished with UPDATE VERIFIED.

After the user reported a short RESET, HID/RPC and IMU status checks passed.
The USB input microphone enumerated and a temporary48kHz mono16-bit capture
contained96256 frames (approximately2.005 seconds); the recording was deleted.
Two clearly synthetic A/B notices were sent for display and gesture acceptance.
The user initially reported that OPEN and BACK had no effect. After returning
Home and reopening a real Codex notice, the user repeated the OPEN/BACK/gesture
sequence and confirmed that all operations worked. Read-only tracing observed
READ, OPEN and CLOSE, and the host relay recorded exact-session-open-requested
without a relay error. This successful physical retest is recorded separately
from the synthetic A/B notices, which cannot validate task navigation.

No firmware or host code changed between the failed report and successful
retest. The earlier no-response condition was not reproduced and its root cause
remains undetermined; the retest does not establish that an intermittent bug was
fixed. Physical acceptance records include this limitation.

Previous single-layer source9fd2369 remains the rollback baseline. Its layout and
gestures were user accepted, and a real Codex OPEN succeeded with accurate upper
button taps; reliable bottom targeting motivated this revision. DSH remains app
activation only. No Mac replacement, main merge or remote push was performed.
