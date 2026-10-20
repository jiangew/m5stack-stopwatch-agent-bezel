# Notification UI firmware update — 2026-10-20

The later round, vivid badge update is recorded in
[the latest update record](NOTIFICATION_VIVID_UPDATE_20261020.md).

## Previously accepted candidate

- Firmware source: `2af19c7e1ecd4741a93ae431a4d739956f1c2cf2`.
- Selected environment: `m5stack-stopwatch-home-imu` in the isolated USB-mic project.
- Image size: 2,667,536 bytes.
- Image SHA-256: `49c536a44609a73b1b46b5c6d880e6be116574a37ecf2a1ab1cda7eef1a4e28f`.
- Only app0 at `0x10000` was updated after the user's exact-port confirmation.
  Previous full app0 and the protected first 64 KiB remain in private backups.

The badge is at the screen's right midpoint with a matching touch target.
Inbox/Toast content is 30 px lower; body text is larger, left-aligned and has
space for seven rows. Fixed gesture hints use two small footer lines. Titles
and status remain centered; BACK and gesture behavior retain their positions.
Other notification views also left-align body text within their existing width.

## Verification

| Check | Result |
| --- | --- |
| Host firmware regressions | Passed, including complete body rendering, alignment, badge target, main-loop input ownership and legacy isolation |
| Native framebuffer preview | Built and visually checked for ordinary and maximum-length body text |
| Default and selected USB+IMU firmware builds | Passed |
| Tool-side write verification | Passed |
| Independent application readback | Byte-identical to the candidate image; SHA-256 matched |
| Protected first 64 KiB | Byte-identical before and after update |
| Previous complete app0 backup | 6,553,600 bytes; stored hash independently checked |
| Normal startup / USB / HID | After one short physical reset, USB microphone enumerated, Companion was running and its HID-connected transition was observed |
| Physical layout and controls | User confirmed the right-side badge, left-aligned body, compact hints, paging/BACK, Home tilt and Agent buttons all normal |
| Short microphone capture | Invoking execution environment denied microphone access; no capture retained and no new audio-quality acceptance claim |

The user ran the prepared update script in Terminal because the agent's current
execution sandbox denied serial configuration. A duplicate identical address
line in the tool's chip-info output initially tripped the identity guard before
any write. The parser was corrected to require one unique identity, with checks
covering duplicate, changed, missing and ambiguous identities. Verified backups
were reused, and the subsequent application write/readback passed.

The notification GATT layout and Mac Companion binary were not changed by this
UI update. Live native delivery coverage remains documented separately in
[the installation acceptance record](TASK_NOTIFICATIONS_INSTALL_ACCEPTANCE.md).
