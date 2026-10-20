# Round notification badge — layout proposal

Status: approved by the user; implement and preview before flashing.

## Goal

Make the Home notification target easier to tap and give the count a circular
appearance, while keeping clear space between it and every character.

## Proposed geometry on the 466 px screen

- Move the center from `(420,233)` to `(402,233)`: 18 px toward the center.
- Use an 80 px diameter subtle low-brightness blue circle (`0x10C5`, RGB565), a subtle 1 px
  darker blue edge (`0x0863`), and orange-red count text (`0xFB27`). Use the
  dashboard's smooth circle rendering. The user requested a larger circle and
  brighter fill and text after reviewing the blue-gray version. Enlarge the
  centered numeric label from text size 3 to 4; keep two-digit counts legible.
- Use an invisible 96×96 px touch target centered on the circle. Its right edge
  becomes x=450 instead of the old x=447, making taps less dependent on the edge.
- When the badge is visible on Home, reserve character pixels to the left of
  x=352. The circle begins at x=362, leaving at least 10 px of visible space.
- Fit the existing character region x=64–403 into x=64–352 using one uniform
  layout scale `288/339` (about 85%) and a corresponding leftward center shift
  of about 25 px. Apply the same scale to the rendered position offsets. Keep
  the character's vertical center. Preserve the original clipped content bounds
  under this transform, rather than covering artwork with the badge.
- Apply this character layout only while Home has a notification badge. Keep
  gesture interpretation, character selection, animation timing, IMU detector,
  haptics, status text and battery positioning unchanged.

## Why a character layout adjustment is proposed

The current portrait canvas can draw as far right as x=403. The proposed circle
occupies x=362–442, so simply moving it inward cannot guarantee separation.
A local analysis sampled 68 native frames across all 17 roles and conservatively
expanded their occupied regions for the existing transition/IMU bounds. It found
no suitable inner-right position that preserved a 12 px visual gap without a
character layout adjustment. This is design evidence, not physical acceptance.

## Home-only entry and palette follow-up

Per the user's latest request, render the badge only inside the Transformers
Home branch. Agent desktops (including Codex, DeepSeek, SUPER and Hermes and
their idle/opening/error variants) show no badge and have no badge hit region.
Returning Home restores entry without dismissing notifications. A workspace
change during a badge press cancels opening but retains ownership until release.
Automatic notification presentation retains its existing policy.

Use a very low-brightness blue fill, only slightly distinct from Home's black
background, with orange-red digits. This interprets the user's color direction
according to the explicit low-contrast-with-black requirement. Preserve the
80 px circle, 96 px target and existing role clearance.

## Physical sizing feedback

The installed 52 px circle passed functional acceptance but the user found it
smaller than expected and still difficult to tap. Its recorded source/image
match the candidate, and the source draws directly into the full-size canvas;
these checks do not explain the reported difference in physical appearance.
The next sizing preview increases the disc to 80 px and the invisible target
to 96 px, while retaining the 402 px center and reserving a 10 px character gap.
This preview has not been flashed or accepted on hardware.

## Verification after approval

Verify that drawing and hit testing share geometry; counts contain only digits;
the enlarged target remains inside the round screen; and the reserved character
edge cannot reach the circle. Check existing notification input ownership and
Home gestures. Render wide and narrow characters plus animation/IMU extremes
using the actual native renderer. Review the resulting previews before a later,
separately confirmed app-only firmware update.
