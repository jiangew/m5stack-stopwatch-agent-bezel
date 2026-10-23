# Notification touch and fixed badge — 2026-10-23

The user approved the target enlargement and preview, then explicitly chose a
single fixed circle position for all roles and a slightly smaller diameter.
The final badge is104px at(388,232), on the role layout's232px horizontal
baseline, with a120px square touch target. Role transforms/assets/clipping and
animation are unchanged. The initial112px and role-specific positioning proposal
was superseded; no such firmware was flashed.

The circle uses the same initial cyan fill,55% outer rim and contrast ink
functions as DSH's upper directional control; native46px Space Mono digits
remain readable. Shared palette functions preserve DSH rendering and support
standard firmware C++11. The Home-only visibility gate is unchanged.

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
role-to-circle clearance is2.23px; rightmost ring clearance is approximately26px.
These are sample measurements, not a guarantee for every continuous pose.
Single/double digits, wide tilted role, DSH reference, Chinese and English pages
were inspected in the native gallery; optional overlays show touch bounds only.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| standard-application.bin | 2263968 | `73f2cd8f061c7713ef22ee5f8e03d05265c0af715ba37b7831f036916b52871a` |
| usb-mic-imu-application.bin | 3595136 | `bb9a844892c939a0f129af495b8d0c71fa9c5915cad8c7f0cd6a2e24edb7fd3e` |

Candidates are prepared only. No image was uploaded, Mac app replaced, branch
merged or remote pushed. Physical click sensitivity remains unverified until a
later separately confirmed app-only update and real-device acceptance.
