# Notification touch targets and Home badge

User approved implementation and native previews of these changes. This stage
does not authorize flashing a new candidate.

- Keep visible BACK/OPEN rectangles unchanged. Extend each hit region upward
  by another20px: top316 instead of336; preserve8px padding on other sides.
  The inter-button gap remains inert. Press locking,20px cancellation and52px
  swipe precedence are unchanged; the added region intentionally belongs to
  the buttons rather than body taps.
- Latest user choice: use one fixed circle position for every role, keep its
  anchor on the role's horizontal baseline, and reduce diameter slightly where
  necessary rather than move or shrink the role. Enlarge the installed80px badge
  to104px diameter: radius52, center(388,232), hit radius60. Preserve the role
  transform, asset, size, position, clip and animation. No role-specific or
  posture-following circle position is introduced. The initial112px candidate
  overlapped a Starscream tilt sample; it was superseded before preview delivery.
- Use the DSH upper directional control's initial cyan fill,55% dark outer rim
  of3px, contrast-selected dark text and Space Mono family. Keep46px digits
  legible for1..64 rather than reducing them to the small directional labels.
- Keep single-layer body layout, notification protocol, Mac services and
  collectors unchanged. Do not claim this layout change fixes the earlier
  intermittent unresponsive report, whose root cause remains undetermined.

Validate actual controller actions at the upper hit boundary, gap, hints,
press drift and swipe cancellation. Render Home with single/double digits,
wide roles and tilt, plus Chinese/English notification pages. Compare portrait
pixels against the current renderer and check circle clearances. Run focused
firmware host regressions and native/default/USB-mic+IMU builds. Physical input
sensitivity requires a later separately confirmed firmware update and retest.
