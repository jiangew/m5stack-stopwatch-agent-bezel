# Task notifications integration — 2026-10-20

This release integrates the four-source notification feature and the final
user-accepted C152 layout. Native confirmation stays on the Mac.

## Included changes

- Opt-in Codex notify, DeepSeek Harness observer, super.engineering lifecycle
  collector and Hermes plugin adapters, with distinct source/session identities.
- Private Companion queue, bounded persistence, reconnect handling and a
  dedicated notification GATT channel, isolated from quota and vendor HID.
- A Home-only 80 px circular badge moved inward, with blue fill, orange-red
  count and a larger touch target. Agent desktops do not show or intercept it.
- Larger notification text, compact gesture hints and centered body text.
  Consecutive UP/DOWN navigation, LEFT/RIGHT and BACK retain input ownership
  across acknowledgements, disconnects and modal exits.
- A default-target build fix: Home badge hit testing is compiled only for the
  USB-mic workspace variant, matching its renderer and state fields. The
  non-USB dashboard cannot intercept an invisible Home badge. Both variants
  exercise the actual notification main-loop gate in regression tests.

## Validation for integration

- 25 C++ host test executables passed with address/undefined-behavior sanitizers.
- All 12 Ruby regression scripts passed, including actual main-loop input,
  rendering, Home spacing, haptics, IMU, audio ownership and workspace launch.
- Companion standalone notification broker/store/reconnect/transport checks
  and 14 Python bridge tests passed.
- Adapter tests passed: 36 Python tests and 19 JavaScript tests.
- Default C152, native-preview and selected USB-mic + Home IMU builds passed.
- Companion release build, four Swift diagnostic type checks, HID/RPC self-test
  and USB microphone validator self-test passed.
- Full `swift test` could not run because this host toolchain lacks `XCTest`.
  The real-source standalone suites and release build above passed; this is
  not a claim that the XCTest suite passed.
- Historical pinned DSH native approval acceptance was not rerun: it requires
  an explicitly supplied verified external module fixture. The optional patch
  and owner remain source-only and disabled in the installed setup.

## Physical acceptance and boundaries

The [installation acceptance](TASK_NOTIFICATIONS_INSTALL_ACCEPTANCE.md) records
four source-labelled transport cards, reconnect/restart trials and the limits
of live native event coverage. It does not establish four real native model
completions or current compatibility with every newer harness release.

The [centered-body acceptance](NOTIFICATION_CENTERED_BODY_UPDATE_20261020.md)
records the final installed image, readback verification, protected-area
preservation and the user's confirmation that text and controls work normally.
The integration-only compile guard does not change the selected USB-mic path.
No additional flash, Companion replacement or audio capture was performed
during Git integration. Firmware backups and local installation evidence stay
private and outside tracked release files.

Installed native adapters advertise `canDecide:false`. Read, dismiss and
OPEN ON MAC do not approve, decline or answer native requests. See the
[adapter guide](../notifications/README.md) for per-source setup and limits.
