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
