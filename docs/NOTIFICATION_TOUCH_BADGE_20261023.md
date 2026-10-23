# Notification touch and fixed badge — 2026-10-23

The user approved the target enlargement and preview, then explicitly chose a
single fixed circle position for all roles and a slightly smaller diameter; the latest preview correction requests90px.
The final badge is90px at(388,232), on the role layout's232px horizontal
baseline, with a112px square touch target. Role transforms/assets/clipping and
animation are unchanged. The initial112px and role-specific positioning proposal
was superseded; no such firmware was flashed.

The circle uses bright amber#FFC857 with a subtle88% rim and deep indigo
#172554 digits. Native36px Space Mono Regular digits replace46px digits; the font
is generated from the existing regular TTF, without emboldening or bitmap
scaling. The existing14/15/22/24px font arrays are byte-for-byte unchanged.
Shared palette helpers remain compatible with standard firmware C++11.
The Home-only visibility gate is unchanged.

Visible BACK/OPEN rectangles remain140×48px. Top hit padding is28px instead of8px
(top316 instead of336); other padding is8px. Separate targets, inert gap/hints,
press locking,20px cancellation and52px swipe priority are retained. The added
upper area intentionally belongs to its button. Host/protocol/collectors are
unchanged. This does not establish a fix for the earlier intermittent response
report, whose root cause remains undetermined.

Controller and renderer regressions failed against the old upper target/badge,
then passed after implementation. Full notification parser/controller/UI/actual
main-loop/legacy checks passed with ASan/UBSan where applicable. Workspace
palette, Super/DSH/Hermes UI and Robot Home regressions also passed.
Native-preview, standard and selected USB-mic+Home-IMU builds passed.

Native preview sampled17 roles in idle, tilt and skill states (51 frames).
Portrait-only RGB bytes match the preceding renderer exactly. Using a48/255
salient-channel threshold to exclude JPEG background noise, minimum sampled
role-to-circle clearance is9.23px; rightmost ring clearance is approximately33px.
These are sample measurements, not a guarantee for every continuous pose.
Single/double digits, wide tilted role, DSH reference, Chinese and English pages
were inspected in the native gallery; optional overlays show touch bounds only.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| standard-application.bin | 2264000 | `87517bfed3e42bc6abff4c7d50e6a116928a81aa927ed319c805a9c189d48681` |
| usb-mic-imu-application.bin | 3648032 | `81ddd03d532971ebe54cb50c882a0be9ba3e591b242454f34deaf5cc5301d07c` |

After the user approved the final preview and confirmed the freshly resolved
device port, source26ba7b4 was written to app0@0x10000 only. Device identity,
actual app0 partition, full previous application backup and protected64KiB
backup were verified before writing. Independent application readback matched
the selected image byte for byte, and protected bytes remained unchanged;
the updater reported UPDATE VERIFIED. Mac app/services were not replaced;
no branch merge or remote push was performed. After the user reported RESET,
HID/RPC and IMU checks passed. The USB microphone enumerated and a temporary
48kHz mono16-bit capture contained96256 frames (about2.005 seconds); the recording
was deleted. Synthetic layout acceptance A/B notices were published. On2026-10-24
the user confirmed that badge appearance/clearance, header spacing, notification
gestures and Home/Agent controls were normal. On a real Codex notice, OPEN worked
at its center and slightly above, left the watch on the notification page and
opened the corresponding Mac task; BACK independently returned Home. This release
is physically accepted. That does not establish the cause or repair of the
earlier intermittent no-response condition.

The96px coral preview supersedes the104px cyan candidate, which was never flashed. Its renderer expectation failed against the previous radius, then passed with the new layout and font. The existing expanded BACK/OPEN hit regions remain unchanged.

Latest preview revision:90px amber/indigo badge, fixed center(388,232),36px Regular digits. The96px coral candidate was not flashed and is superseded. The112px square hit target is deliberately retained for easier taps, while the visible diameter shrinks. Notification UI regressions and all three builds passed;51 portrait-only native samples remain byte-identical.

Header spacing follow-up: the three read-only header groups now share the body's28px line step, centered at y64/92/120. Wrapped read-only titles also use28px. First/second rows move upward; rich title/status/body/footer anchors and native deciding controls retain their prior positions. The actual renderer regression failed on the old spacing, then passed. Notification host regressions and native/standard/USB-mic+IMU builds passed; Chinese short/long, English long and synthetic long-model/two-line-title previews were inspected without overlap. This final candidate was flashed and physically accepted as recorded above.
