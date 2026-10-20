# Round notification badge — layout proposal

Status: approved by the user; implement and preview before flashing.

## Goal

Make the Home notification target easier to tap and give the count a circular
appearance, while keeping clear space between it and every character.

## Proposed geometry on the 466 px screen

- Move the center from `(420,233)` to `(402,233)`: 18 px toward the center.
- Use a 52 px diameter vivid blue circle (`0x231D`, RGB565), a subtle 1 px
  darker blue edge (`0x1A15`), and bright yellow count text (`0xFFE0`). Use the
  dashboard's smooth circle rendering. The user requested a larger circle and
  brighter fill and text after reviewing the blue-gray version. Enlarge the
  centered numeric label from text size 2.5 to 3; keep two-digit counts legible.
- Use an invisible 68×68 px touch target centered on the circle. Its right edge
  becomes x=436 instead of the old x=447, making taps less dependent on the edge.
- When the badge is visible on Home, reserve character pixels to the left of
  x=366. The circle begins at x=376, leaving at least 10 px of visible space.
- Fit the existing character region x=64–403 into x=64–366 using one uniform
  layout scale `302/339` (about 89%) and a corresponding leftward center shift
  of about 18 px. Apply the same scale to the rendered position offsets. Keep
  the character's vertical center. Preserve the original clipped content bounds
  under this transform, rather than covering artwork with the badge.
- Apply this character layout only while Home has a notification badge. Keep
  gesture interpretation, character selection, animation timing, IMU detector,
  haptics, status text and battery positioning unchanged.

## Why a character layout adjustment is proposed

The current portrait canvas can draw as far right as x=403. The proposed circle
occupies x=376–428, so simply moving it inward cannot guarantee separation.
A local analysis sampled 68 native frames across all 17 roles and conservatively
expanded their occupied regions for the existing transition/IMU bounds. It found
no suitable inner-right position that preserved a 12 px visual gap without a
character layout adjustment. This is design evidence, not physical acceptance.

## Verification after approval

Verify that drawing and hit testing share geometry; counts contain only digits;
the enlarged target remains inside the round screen; and the reserved character
edge cannot reach the circle. Check existing notification input ownership and
Home gestures. Render wide and narrow characters plus animation/IMU extremes
using the actual native renderer. Review the resulting previews before a later,
separately confirmed app-only firmware update.
