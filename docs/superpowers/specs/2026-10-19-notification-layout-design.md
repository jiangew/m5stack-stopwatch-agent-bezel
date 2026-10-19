# Notification layout adjustment

## Requested result

Place the notification badge on the right edge of the circular screen, balancing
the connection indicator at the top and battery indicator at the bottom. Move
the content of the inbox opened from that badge downward into the unused space.

## Recommended layout

- Keep the existing count badge appearance and dimensions. Move its center from
  `(325, 74)` to `(420, 233)`, the screen's 3 o'clock position. Move its touch
  target with it, leaving a small finger margin around the visible badge. A tap
  at the previous location must no longer open the inbox.
- Move the source/count heading, model, title, state and body together by 30 px
  in Inbox and Toast views. Their existing spacing and full text remain intact.
  On a 466 px screen, body text starts at y=195. The compact-footer refinement
  below extends its available area through y=315, above the outcome at y=350.
- Following the user's preview feedback, replace the large tap prompt and two
  direction hints with two small footer lines at y=382/398, size 1.25. Move the
  outcome caption to y=350, size 1.5. Give Inbox/Toast body text size 2, 32 columns
  and up to seven 20 px-spaced rows at y=195–315. The existing 192-byte limit
  stays intact; the gain is readable content space rather than a protocol change.
- Preserve gesture coordinates and BACK. Detail, confirmation and submitting
  layouts stay outside this adjustment.

The fixed footer is explanatory text, not a set of touch buttons. Its smaller
appearance does not change browsing, dismiss, detail or close behavior.

After the user's alignment choice, body lines share a fixed left edge: x=48 in
Inbox/Toast and x=72 in the narrower Detail/Confirm/Submitting body. Titles,
source, model, state and footer remain centered. Wrapping, complete body content,
font size and vertical spacing remain as specified above.

## Verification and delivery

Check a rendered normal notification and maximum-length body for clipping or
overlap. Check badge drawing and its actual controller hit target together, plus
the existing inbox/gesture and main-loop regressions. Produce native previews
for review before building a replacement USB microphone + IMU application image.
Any later device write requires fresh exact-port identification and explicit
flash confirmation. This layout review does not authorize a device write.
