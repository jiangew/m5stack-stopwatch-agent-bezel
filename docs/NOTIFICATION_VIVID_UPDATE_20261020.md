# Vivid notification badge update — 2026-10-20

The subsequent 80 px Home-only badge installation is recorded in
[the latest update record](NOTIFICATION_HOME_ONLY_UPDATE_20261020.md).

## Previously installed image

- Firmware source: `8fc76bff8991a5423355e2bda06e85f01839ec59`.
- Selected environment: isolated USB-mic `m5stack-stopwatch-home-imu`.
- Image size: 2,667,648 bytes.
- SHA-256: `361a187bff1d62fae0bc0f4bee09d57b29bbc3af651cd226472c839a1dadf485`.
- Updated app0 at `0x10000` only, after the user's interactive exact-port confirmation.
- Previous accepted image: `2af19c7e1ecd4741a93ae431a4d739956f1c2cf2`.

Home now has a 52 px vivid-blue circle, a quiet same-hue edge and a larger
bright-yellow numeric count. The touch target is 68 px; the circle retains
at least 10 px clearance from the transformed character region. The accepted
left-aligned notification body and compact footer remain unchanged.

## Verification

| Check | Result |
| --- | --- |
| Notification host regressions and native previews | Passed before update |
| Selected USB-mic + IMU build | Passed |
| Candidate image checksum / validation hash | Valid |
| Terminal update result | User reported UPDATE VERIFIED |
| Independent application readback | Rechecked byte-identical to candidate and matching SHA-256 |
| Protected first 64 KiB | Rechecked byte-identical before/after |
| Complete previous app0 backup | Rechecked 6,553,600 bytes and matching stored hash |
| Installed local receipt | Rechecked matching the candidate image |
| Companion LaunchAgent | Running |
| Normal startup | User confirmed short reset and normal Home/control operation |
| USB audio / fresh host BLE HID checks | No new host enumeration claim; functional Agent keys confirmed by user |
| Layout, taps, paging/BACK, Home tilt, Agent keys | User confirmed restart, appearance and controls work; badge is still too small and inconvenient to tap, so sizing acceptance failed |
| Audio capture quality | No new acceptance claim; previous execution environment denied microphone capture |

Private backup, device identity and installation receipts remain outside tracked
files. The previous update staging directory and verified backups were preserved.
The agent's serial access was denied by the execution environment, so the user
ran the prepared updater in Terminal. No Companion binary, pairing record or
GATT schema changed in this update. A running LaunchAgent does not by itself
establish device reconnection or successful input delivery.
