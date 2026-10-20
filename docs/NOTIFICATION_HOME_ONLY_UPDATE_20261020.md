# Home-only notification badge update — 2026-10-20

## Installed image

- Source: `bb64fd2cbccbf2f56867047446c97de9e3f6c232`.
- Environment: isolated USB-mic `m5stack-stopwatch-home-imu`.
- Image size: 2,667,664 bytes.
- SHA-256: `a696c15a3513c9ceaed4d4f1fcf16bf11ac0908d1a6d72129e1cec88d1e2e1e5`.
- App0 at `0x10000` updated after interactive exact-port confirmation.
- Previous verified image: `8fc76bff8991a5423355e2bda06e85f01839ec59`.

This update includes the 80 px circle and 96 px touch target, a very low-brightness
blue background with orange-red digits, and Home-only badge rendering and manual
entry. Agent desktops have no badge entry; returning Home restores it. A desktop
change during a badge press cancels opening while retaining release ownership.
Existing notification content layout and controls remain unchanged.

## Verification

| Check | Result |
| --- | --- |
| Notification host regressions and native previews | Passed before update |
| Badge input routing | Passed every non-Home workspace mode, Home return and mid-press switch |
| Selected USB-mic + Home IMU build | Passed |
| Candidate image checksum / validation hash | Valid |
| Interactive Terminal updater | User reported UPDATE VERIFIED |
| Independent application readback | Rechecked byte-identical to candidate; SHA-256 matches |
| Protected first 64 KiB | Rechecked byte-identical before/after |
| Complete previous app0 backup | Rechecked 6,553,600 bytes, stored full hash and previous image prefix hash |
| Installed local receipt | Rechecked matching this candidate |
| Companion LaunchAgent | Running; this alone does not establish device reconnection |
| Normal startup, badge palette/size and navigation | Pending user acceptance after short reset |
| Notification paging/BACK, Home tilt and Agent keys | Pending post-update physical acceptance |
| Fresh USB audio / host BLE HID checks | No new enumeration or audio-quality claim |

The user ran the prepared updater in Terminal because the agent's execution
environment denied serial access. Private device identifiers, full backups and
installation receipts remain outside tracked files. Earlier candidates and
backups were retained. No Companion binary, pairing record or GATT schema was
changed in this update. The earlier 52 px image passed functional checks but
was rejected for badge size and tap comfort; it is retained as a recovery image.
