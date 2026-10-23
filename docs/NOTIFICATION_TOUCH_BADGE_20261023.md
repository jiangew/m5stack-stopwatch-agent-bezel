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
| standard-application.bin | 2263968 | `666ba70594dedad781c3f2c15208691fa22e470ac353d3566cbae3f65f8673c8` |
| usb-mic-imu-application.bin | 3648000 | `3f1ddd0a3444c0bd2db894915b01c3b0012fb31a99e4d83d5bdf21d18edf6f95` |

Candidates are prepared only. No image was uploaded, Mac app replaced, branch
merged or remote pushed. Physical click sensitivity remains unverified until a
later separately confirmed app-only update and real-device acceptance.

The96px coral preview supersedes the104px cyan candidate, which was never flashed. Its renderer expectation failed against the previous radius, then passed with the new layout and font. The existing expanded BACK/OPEN hit regions remain unchanged.

Latest preview revision:90px amber/indigo badge, fixed center(388,232),36px Regular digits. The96px coral candidate was not flashed and is superseded. The112px square hit target is deliberately retained for easier taps, while the visible diameter shrinks. Notification UI regressions and all three builds passed;51 portrait-only native samples remain byte-identical.
