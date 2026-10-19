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
  On a 466 px screen, body lines move from y=165–240 to y=195–270, above the
  existing outcome label at y=290.
- Preserve the established lower controls and gesture coordinates, including
  BACK. Detail, confirmation and submitting layouts stay outside this adjustment.

An alternative is to redistribute the lower controls and body independently;
that introduces more interaction changes than the two requested placement fixes.

## Verification and delivery

Check a rendered normal notification and maximum-length body for clipping or
overlap. Check badge drawing and its actual controller hit target together, plus
the existing inbox/gesture and main-loop regressions. Produce native previews
for review before building a replacement USB microphone + IMU application image.
Any later device write requires fresh exact-port identification and explicit
flash confirmation. This layout review does not authorize a device write.
