# Local notification installation acceptance — 2026-10-19

Scope: install the four notification sources on one C152 and keep native
confirmation on the Mac. Watch allow/decline is not enabled.

## Installed artifacts

- Source checkout: `feature/task-notifications`, installation revision `af0b707`.
- Companion: the reviewed, source-built notification candidate; the previous
  application and configuration are retained in private local backups.
- Selected image: USB microphone + Home IMU, 2,667,408 bytes,
  SHA-256 `7254cc929da96ada0820cd111709b1a80ad84e317e3b5413926160d8cbce2463`.
- Only app0 was written after explicit device/port confirmation. The flash tool
  verified the written data. The protected first 64 KiB were read before and
  after and compared byte for byte unchanged. The previous full app0 is backed up.
- Bluetooth identifiers, port details, installation paths, profile backups and
  native task identities remain in private installation records.

## Observed acceptance

| Layer | Observed result | Boundary |
| --- | --- | --- |
| Four source labels | User saw TEST CODEX, TEST DEEPSEEK, TEST SUPER and TEST HERMES on C152 | Transport tests, not four real native completions |
| OS permissions | Current application reports Accessibility authorized; HID connected after pairing recovery | Application signature unchanged during recovery |
| Notification recovery | User saw TEST REPAIR and confirmed paging | Required refreshing this C152's Mac pairing record |
| Device restart | User saw TEST RESTART; paging and BACK passed | One physical restart trial |
| Existing interaction | User confirmed Home touch/tilt and Agent page buttons normal | Qualitative local regression acceptance |
| HID/RPC | Physical device-status RPC returned `result=ok` after restart | Does not establish every native app action |
| USB microphone | CoreAudio enumerated the input-only 48 kHz microphone | No new capture/audio-quality claim |
| Mac Companion restart | User saw TEST MAC RESTART; paging and BACK passed; fresh logs recorded zero notification reconnect rejections and HID/RPC returned `result=ok` | One trial of the original OFFLINE trigger |

## Recovery evidence

After the first Companion restart, discovery found the notification service with
zero characteristics. An all-service probe found both notification characteristics
under the old quota service instead. Disabling quota queries did not resolve the
failure, and a physical reset alone did not refresh the directory.

After the user forgot only this C152 on the Mac, discovery returned the correct
separation: one quota characteristic and two notification characteristics, with
notification subscription succeeding. The UI initially showed a connection
problem; the private GATT channel recovered before HID enumeration did. After a
physical restart following that pairing refresh, HID/RPC and the user's existing
controls passed. No firmware, source code, permission grants or other Bluetooth
pairings were changed during this recovery.

This identifies a stale service-directory problem on this installation; it does
not establish an automatic cache-migration fix for future firmware upgrades.
Do not routinely remove working pairings or reset system permissions.

## Native adapter coverage

| Source | Installed state and live evidence | Still unverified |
| --- | --- | --- |
| Codex | Completion notify fanout installed, preserving the previous notify command | Actual completion callback from this Desktop; approval/input are unsupported |
| DeepSeek Harness | Installed desktop observer loaded; two non-test completion records reached the broker | Other event types, exact-session OPEN and concurrent/cancellation cases |
| SUPER | Three collectors running; native ready frames accepted for 12 existing targets | Real completion/input events; newly created chats require subscription refresh |
| Hermes | Plugin/config installed; registration of four native hooks checked in isolation | Runtime activation on a new native session and actual native delivery |

All installed adapters keep `canDecide:false`. No model tasks or approval grants
were created for acceptance. No claim is made about universal existing-session
coverage, duplicate native completion suppression, physical reminder timing,
measured latency or haptic intensity.

The original packaging manifest records source-only gates at packaging time. It
is retained unchanged; this record adds later installation evidence. This local
acceptance does not imply a merge, push or public release.
