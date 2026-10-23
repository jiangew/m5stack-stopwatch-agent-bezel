# Notification touch and fixed badge — 2026-10-23

The user approved the target enlargement and preview, then explicitly chose a
single fixed circle position for all roles and a slightly smaller diameter; the latest preview correction requests96px.
The final badge is96px at(388,232), on the role layout's232px horizontal
baseline, with a112px square touch target. Role transforms/assets/clipping and
animation are unchanged. The initial112px and role-specific positioning proposal
was superseded; no such firmware was flashed.

The circle uses very pale coral#FFE3D9 with a subtle88% rim and dark brown-red
#713B31 digits. Native36px Space Mono Regular digits replace46px digits; the font
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
role-to-circle clearance is6.23px; rightmost ring clearance is approximately30px.
These are sample measurements, not a guarantee for every continuous pose.
Single/double digits, wide tilted role, DSH reference, Chinese and English pages
were inspected in the native gallery; optional overlays show touch bounds only.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| standard-application.bin | 2263968 | `489937bdd90b0de080db33efbccf0e6d9c845893421582f5dcda864e1ab30664` |
| usb-mic-imu-application.bin | 3648000 | `df02331d5ef54f06f40a364cfdbac3873ccc563d4480f54f8f2782ddfc20ee84` |

Candidates are prepared only. No image was uploaded, Mac app replaced, branch
merged or remote pushed. Physical click sensitivity remains unverified until a
later separately confirmed app-only update and real-device acceptance.

The96px coral preview supersedes the104px cyan candidate, which was never flashed. Its renderer expectation failed against the previous radius, then passed with the new layout and font. The existing expanded BACK/OPEN hit regions remain unchanged.
