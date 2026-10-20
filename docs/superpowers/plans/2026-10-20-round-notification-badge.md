# Round notification badge implementation

Approved scope: implement and preview; no device update in this step.

- [x] Add regressions for numeric circle, padded hit target and character clearance.
- [x] Update shared badge geometry and drawing; pass Home badge visibility to the portrait canvas.
- [x] Transform portrait placement, size and clip together; preserve normal Home and clip restoration.
- [x] Run notification and affected Home regressions, then build native-preview.
- [x] Render actual wide/narrow roles, action/tilt extremes and two-digit count; review previews.

Files: TaskNotification{,Ui}.h, RobotHome{Ui,Characters,PortraitCanvas}.h,
main.cpp, preview_main.cpp and their existing host tests.

## Validation

Notification firmware host suite passed (including numeric counts 1/9/10/64,
target boundaries and input ownership). Home UI and real PortraitCanvas tests
passed under AddressSanitizer/UndefinedBehaviorSanitizer. Existing Home swipe,
IMU main-loop/swipe and haptic main-loop regressions passed. Native-preview
built successfully; the existing upstream M5GFX VLA warning remains.

Native previews are local ignored artifacts in
`artifacts/round-notification-badge-20261020/`:

- `notification-badge`: wide Bumblebee portrait, count 3.
- `notification-badge-optimus`: full-body Optimus, count 3.
- `notification-badge-starscream-64`: Starscream, count 64.
- `notification-badge-megatron-tilt`: Megatron at +8 degrees, x+10/y-8.
- `notification-badge-bumblebeefullbody-skill-64`: Bumblebee action at 250ms, count 64.

All five native RGB frames have black pixels across x=366..375, y=201..265,
between the transformed portrait clip and the badge. The real canvas regression
also checks offset scaling, clip intersection/restoration, and return to the
original layout without a badge. Status/battery positions remain covered by
Home UI regressions.

Reproduce a preview using `.pio/build/native-preview/program OUTPUT.ppm SCENARIO 250`
after building `pio run -e native-preview` with the existing local dependencies.
No firmware image was built or written for this preview. Physical tap comfort
and the updated layout still require a later device update and user acceptance.

## Filled-disc style follow-up

The user requested a visible background and quieter border, referencing the
Codex dashboard circles. Reused dashboard track blue-gray (`0x2187`) for the
fill and pressed-panel shade (`0x1946`) for a one-pixel darker edge, with ice
count text and the same smooth-circle primitive as dashboard keys.
Geometry, touch bounds, character placement and notification content stay as
previously verified. Updated the existing circle test for smooth rendering and
the one-pixel edge; notification host regressions and native-preview build pass.

New local previews: `artifacts/filled-notification-badge-20261020/` for
`notification-badge` and `notification-badge-starscream-64`. Actual RGB pixels
confirm the solid background is distinct from black and its subtle edge, with
the existing ten-pixel character clearance. Native previews reviewed; no flash.

## Larger vivid badge follow-up

The user requested a larger circle and bright accent colors for both fill and
number. Increased diameter from 44 to 52 px and label size from 2.5 to 3. The
fill is vivid blue (`0x231D`) with a quiet dark-blue edge (`0x1A15`), and the
count is saturated yellow (`0xFFE0`). Shifted the center right by 4 px to
(402,233), preserving the existing x=376 left edge and 10 px character gap.
The touch target grows from 64 to 68 px, still inside the round screen.

Updated existing geometry/input fixtures; notification firmware host regressions
and native-preview build passed. Native one/two-digit previews in
`artifacts/vivid-notification-badge-20261020/` confirm visible yellow count pixels
and a black gap between character and circle. No device update performed.

## Physical sizing correction preview

The user confirmed normal operation after resetting the installed 52 px image,
but rejected its tap comfort and perceived size. Receipt/image identity and
direct full-size sprite rendering were inspected; no physical size discrepancy
has been reproduced, so no unsupported root cause is asserted.

Increase disc diameter to 80 px and target to 96 px, retain center (402,233),
blue fill and yellow count, and increase label size to 4. Fit the character's
original x=64..403 region into x=64..352 using 288/339 uniform scale. Its right
edge remains 10 px clear of the circle's x=362 left edge. Existing hit-boundary,
round-screen bounds and canvas transform tests were updated.

Notification host regressions and native-preview build passed. Native wide,
two-digit full-body and tilted character previews in
`artifacts/large-notification-badge-20261020/` pass the actual pixel gap check.
This is a source/preview correction; no new firmware was built or flashed.

## Home-only badge and quiet palette

User requested a background only slightly distinct from black, orange-red
numbers, and an icon shown only on Transformers Home. Updated fill/edge/text to
RGB565 0x10C5/0x0863/0xFB27. Moved badge rendering from the shared desktop footer
to the Home renderer branch. Restricted manual badge press entry to Home and
cancelled a pending open if the workspace changes before release.

Added an existing main-loop fixture scenario that first failed against the old
implementation, then passed across every non-Home workspace mode, a mid-press
workspace switch, and entry after returning Home. Existing notification host
regressions and native-preview build pass. Palette previews are local artifacts
in `artifacts/home-only-notification-badge-20261020/`. No flash performed;
physical palette and navigation acceptance remain pending. The selected isolated
USB-mic + Home IMU firmware build also passed after this routing change.

## Update closed after physical acceptance

Firmware source `bb64fd2` was flashed to app0, with independent application
readback, protected-area equality and complete prior app0 backup verified.
On 2026-10-20 the user confirmed normal restart, appropriate badge size/tap
comfort, Home-only visibility with restoration on return, notification paging
and BACK, Home tilt and Agent keys. Notification UI acceptance is complete.
See `docs/NOTIFICATION_HOME_ONLY_UPDATE_20261020.md` for the release evidence
and the separate USB-audio verification boundary.

## Further inset, reading typography and consecutive browsing

- [x] Reproduce the lost swipe after an acknowledged navigation in a controller test.
- [x] Fix the expected-ACK input latch while preserving unsolicited-context guards.
- [x] Move badge and hit target left 24 px without changing the role transform.
- [x] Enlarge reading text and retain the full 192-byte context without footer overlap.
- [x] Pass firmware host regressions, actual broker/controller/send-guard coupling,
  real canvas regression, native preview and selected USB-mic + Home IMU build.
- [x] Check 51 native role frames for overlap and two baseline pixel comparisons.
- [x] Device flash from `5ce58d1`, following exact-port safeguards, independently verified
  application readback, protected-area equality and complete prior app0 backup.
- [x] Physical repeated browsing: user confirmed TEST SWIPE A → B → A.
- [ ] Inset and reading comfort not separately reconfirmed in the browsing diagnostic.

Candidate evidence: `docs/NOTIFICATION_READABILITY_FIX_20261020.md`.

## Restore centered body text

- [x] Switch body wrapping back to its existing centered drawing path.
- [x] Update existing alignment assertions for browsing, Toast and Detail,
  preserving full 192-byte context and the existing scope checks.
- [x] Native-preview build and existing UI regression passed; short and maximum-length
  centered previews checked in `artifacts/centered-notification-body-20261020/`.
  No firmware build or device flash in this step.

- [x] Built and flashed centered-body source `ae5a8a5` with exact-port confirmation;
  application readback, protected area and full prior app0 backup verified.
- [ ] Physical centered-body layout and control acceptance after short reset.

Installation evidence: `docs/NOTIFICATION_CENTERED_BODY_UPDATE_20261020.md`.
