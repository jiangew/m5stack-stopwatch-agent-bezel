# Notification inset, reading size and consecutive browsing fix — 2026-10-20

Status: candidate verified in host/native builds; not flashed or physically accepted.
The currently installed and accepted baseline remains firmware source `bb64fd2`.

## Changes

- Shift the badge center from (402,233) to (378,233), 24 px left. Its 80 px disc
  now has 48 px clearance from the right screen edge instead of 24 px. Preserve
  the 96 px hit target, Home-only visibility, colors and accepted role layout.
- Increase browsing/read-only detail body size from 2 to 2.5 (read-only Detail
  previously used 1.5), title/source size to 2.5, model to 1.75 and state to 2.
  Keep body left-aligned. Eight 24-character rows at 24 px line spacing retain
  all 192 context bytes. Move compact footer hints below the body and remove
  the redundant footer outcome label; state remains above the body. Read-only
  Detail retains Open on Mac below the complete body. Decision/hold safeguards
  and full-scope rendering remain covered by existing regressions.
- Fix consecutive UP/DOWN browsing: an expected navigation acknowledgement
  with a new card previously set the input-blocking latch again, discarding the
  next physical swipe. Expected Next/Previous/Dismiss acknowledgements now clear
  that latch; unsolicited context changes still invalidate the gesture. The
  user identified the affected screen as the first page opened from Home.

## Evidence

- Added consecutive Next/Previous controller regression failed before the fix
  and passed afterward. Existing notification parsing, pinned context, leases,
  fresh hold, offline/input ownership and Home-only entry regressions pass.
- Coupled the real Swift Store/Broker, C++ Controller and BLE send guard: six
  consecutive mixed Next/Previous gestures select the expected notification
  without synthetic extra release events. Stale-confirmation Close regression
  also passes; no native decisions are published by browsing.
- Real PortraitCanvas regressions pass. Two native Home frames are byte-identical
  to the accepted baseline outside the old/new badge discs, confirming unchanged
  role placement, status and battery pixels.
- Sampled all 17 roles at idle, +8-degree tilt and 250 ms skill (51 native frames).
  No role pixels above RGB threshold 12 intersect the new circle. This sample
  does not replace physical acceptance or exhaust every animation/sensor pose.
- Native preview and selected isolated USB-mic + Home IMU firmware builds pass.
- Ordinary, two-digit and full-length reading previews are local ignored files
  under `artifacts/inset-notification-readability-20261020/`.

No companion app, pairing record, GATT schema or installed firmware changed.
Physical tap placement, reading comfort and repeated UP/DOWN still require a
later device update and acceptance.
