# Notification inset, reading size and consecutive browsing fix — 2026-10-20

Status: flashed and independently verified; post-update physical acceptance pending.
The previous accepted baseline was firmware source `bb64fd2`.

## Installed firmware and flash verification

- Source: `5ce58d15c9ed8ccd6af175eedaff111421af1eaa`.
- Environment: isolated USB-mic `m5stack-stopwatch-home-imu`.
- Image size: 2,667,632 bytes.
- SHA-256: `13237e16c04178b2e8f5afdf9d9762d3cdbe03d4282de04fb1f42bddccc4f84c`.
- App0 at `0x10000` only, following interactive exact-port confirmation.
- User reported UPDATE VERIFIED from the prepared Terminal updater.
- Application readback independently rechecked byte-identical to the candidate.
- Protected first 64 KiB independently rechecked byte-identical before/after.
- Complete prior app0 backup rechecked at 6,553,600 bytes, with matching full
  stored hash and prior-image prefix hash. Installed local receipt matches.
- Physical appearance, reading comfort and consecutive browsing remain pending
  user confirmation after a short reset. No fresh USB-audio capture or host HID
  enumeration claim is made from a successful write alone.

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

No companion app, pairing record or GATT schema changed. The user ran the
updater in Terminal because this execution environment denied serial access.
Private device identifiers, backups and installation receipts remain outside
tracked files. Physical tap placement, reading comfort and repeated UP/DOWN
still require post-update acceptance.
