# DSH notification content parity candidate — 2026-10-23

This is a source/build candidate. No running profile, application, LaunchAgent,
collector or device has been replaced. The physically accepted Codex V2 baseline
remains installed; its observed real Codex callback delivery remains valid.

## Behavior and boundaries

DSH's explicitly enabled `richContent:true` observer uses native title projection,
header cwd basename and a bounded visible assistant reply from an observed exact
live root/current turn. The completed native round becomes resolved `TURN ENDED`;
errors, interruption, blocking and token limits retain distinct native meanings.
Missing titles use the existing stable unnamed serial; missing final reply points
to Mac. No history scan, model/title generation, tool-output copying or invented
model version. All captured task content stays in the private runtime/watch.

Read-only approval/input now share the existing rich title/project/time/position
layout, fonts, centered excerpt and compact footer. Pending labels are
`WAITING ON MAC` and `WAITING FOR INPUT`. Native outcomes alone yield
`ALLOWED`/`DECLINED`/`ANSWERED`/`CANCELLED`; clearing alone yields `CLEARED`.
Task metadata stays fixed for one request/revision across rename, renewal and
resolution. Scope ownership remains disabled; `nativeApprovals:true` and rich
capture are mutually exclusive. All capable requests retain complete ASCII scope.

Local body<=4096 UTF-8 bytes and task name<=512; encoded event/route<=8192,
including Foundation slash escaping. Project is a basename only. Wire<=512,
title<=32 characters/96 UTF-8 bytes, body<=128, project<=32. Further JSON fitting
reserves action ACK/count/position/TTL and future native outcome widths. Original
local events remain unchanged by wire fitting. Latin Space Mono/CJK efontCN
coverage and all existing gestures/footer coordinates remain unchanged.

## Validation

- Node observer/content/approval-owner/lifecycle:27 tests pass; default legacy
  behavior, root/turn isolation, Unicode/escaping, continued input, authoritative
  outcomes, frozen metadata and early incompatible-config rejection included.
- Python adapter/content suite:43 tests pass, including strict optional native
  terminal reason; the full runner supplies its actual Swift bridge.
- Standalone Swift broker/content/transport/reconnect and15 real ingress tests
  pass. Seven actual Swift wire fixtures parse with the firmware parser under
  ASan/UBSan, including read-only attention and outcome-stable excerpt fitting.
- Firmware parser/controller/UI/main-loop/legacy tests pass. Native drawScreen
  regressions pass for default/USB-mic and17 Home roles; no control mapping change.
- Installed DSH0.2.1-rc.2 ASAR packages exercised with real Cordis4.0.5,
  SessionStore and title projection definition, synthetic committed native
  assistant/turn/audit events. Models invoked:0; profile changes:0. Four native
  events also pass the real Python relay and production Swift rich projection;
  the resulting JSON renders through the real firmware parser/UI.
- Standard, native framebuffer, selected USB-mic+IMU and release Companion builds
  pass. Companion packaging is0.1.4/build17. Native previews cover completed,
  waiting approval, waiting input (projection fixture), and native declined.

Run `sh notifications/test.sh`, `sh scripts/test_task_notifications.sh`,
`sh scripts/test_task_notifications_firmware.sh` and
`ruby simulator/codex_dashboard_draw_test.rb`. The separate native contract runner
is `scripts/test_deepseek_content_native.cjs`: execute with the installed Desktop
Electron in Node mode, `--expose-internals`, and an explicit ASAR node_modules
path. It checks native versions and emits actual module hashes. Its optional
second argument writes synthetic events only. It does not weaken or replace the
older separately pinned0.2.0 native-approval extension tests.

## Review correction

The fixed-range review found a same-revision compatibility defect: withdrawing
native decision capability could change complete ASCII scope into a rich
excerpt, causing firmware context rejection. A failing production broker test
reproduced it. A persisted per-revision complete-scope marker now keeps layout
and full scope through release, submission, native outcome and restart. A rich
read-only revision cannot gain capability without a new revision. Regression
covers withdrawal, restart, resolution, rejected same-revision promotion and
accepted higher-revision transition.

## Reviewed artifact pins

Implementation source: `052677538e50b3713ddbe36edc3eecd9bdafd850`. Narrow re-review found
no remaining actionable issues. Candidates are signed/hashed local artifacts;
this record does not establish installation. USB-mic uses the explicit
`m5stack-stopwatch-home-imu` environment, not the USB project's default target.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| standard-application.bin | 2252000 | `e662f367a8db7e54049b616c3bdf5b6e8112d14d54f1344b98340f24e392eeee` |
| usb-mic-imu-application.bin | 3583744 | `28f61a0c6bd6043f153b76815984eeef3cf52be8c84d49929e0505504291d41b` |
| companion-executable | 897696 | `bb1931c36e2731b8509562b9878c485fd177e6ef74ceba72dc5580c65e48ce28` |

## Deployment and rollback gate

1. Review the four native previews and immutable patch; pin source and artifacts.
2. Preserve current application, DSH profile patch, runtime, exact device binding,
   collector configs and generic relay arguments before coordinated replacement.
3. Update compatible generic OPEN relay alongside the DSH package. Enable only
   its root Host node's richContent; keep nativeApprovalsfalse, navigation and
   unrelated providers/config untouched. Fully reload the intended Desktop Host;
   do not run a second Host or alter the unrelated global CLI.
4. Install matching Companion and firmware together (layout3 is incompatible with
   older firmware). Keep the selected USB input-only mic+IMU target, exact-port
   confirmation, current app0/protected backup, app-only write and readback gates.
5. Verify fresh named DSH completion plus actual Mac approval/input/outcome,
   OPEN activation limits, all notification/Home/Agent gestures, BLE reconnect,
   quota, HID and USB input audio on physical C152 separately.

No live DSH callback, Mac native outcome delivery or physical acceptance is
claimed from these fixtures. Disable DSH richContent and restore the saved DSH
node/relay/Companion when rolling back; old attention layout needs the prior
matching firmware. Preserve original private queue and the accepted V2 artifacts.
