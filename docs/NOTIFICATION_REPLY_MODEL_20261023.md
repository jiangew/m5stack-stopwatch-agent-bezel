# Last-reply model priority — 2026-10-23

User update: extract model version from the last assistant result first, fall
back to that session's configuration, and display the version alone with no 配置
prefix. Reuse the same model/time row, title/body/footer and controls.

DSH prefers the last native assistant message.source.model. Without that, an
explicit model annotation in its visible reply can supply the identifier. A new
request header cannot override an already captured last-reply model; a newer
assistant reply replaces that previous reply (missing model then uses config).
Only current observed exact root Session/turn can contribute a reply. Preserve
bounded observed request/header configuration across turns while that same root
Session stays live; prune on root removal, cap at64 entries, never cross Session
replacement. Pending notifications retain their captured model through resolution.

Codex's installed native callback provides last-assistant-message as text, without
a separate execution-model field. Extract only explicit standalone 模型/模型版本/
Model/Model version annotations in that text, outside fenced/quoted/indented
examples. Multiple distinct identifiers are ambiguous and use configuration.
Casual mentions or model comparisons do not supply an execution model. Read the
original callback text before notification excerpt truncation; do not scan stored
conversation history, infer a version, invoke a model or use a global default.
Thread.model remains current/latest persisted session configuration, not execution
telemetry. Internal modelConfigured provenance remains compatible; UI ignores it.
Missing both sources still shows 模型未提供. Long versions preserve time and ellipsis.

Source regressions first reproduced priority/fallback and the old UI prefix.
Collector tests cover actual reply source, textual annotations, config fallback,
new/replaced turns, root replacement, bounded cache, pending immutability, code
examples, ordinary mentions and ambiguous annotations. Native Session/header/
assistant contract fixture and firmware UI/controller regressions remain separate
from live callback and physical acceptance. Companion source/executable is unchanged
from build18; only collectors and the firmware's presentation change.

No live app/profile/service/hook replacement or firmware write has occurred.
The coordinated release still includes compatible collectors/OPEN relay, build18
Companion and firmware; retain exact-port confirmation, app0/protected backups,
readback and independent physical C152 acceptance. Previous candidates and backups
remain untouched.

## Verified candidate

Implementation: `ded3a065a7a86d488812e3a3a0f232c7cd0b88a0`. Independent review found no actionable issue.
31 Node and45 Python/real-Swift-bridge tests pass; native DSH fixture and
firmware UI/controller regressions pass. Native/default/selected USB-mic+IMU
firmware builds pass. Repackaged Companion build18 code is byte-identical after
signature removal; its signed executable hash changes with the new provenance
Info.plist. All14 staged collector/relay file hashes match source.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| standard-application.bin | 2252320 | `b5b2e796f8a44d2c3026b47a03a4ee15764796ae2d50d142bdf258b141b6ab84` |
| usb-mic-imu-application.bin | 3583904 | `1da50ef0bfdce161d6de335a988a725e969ad52558910c6b61af6a27ea80f55d` |
| CodexWatchCompanion.app/Contents/MacOS/codex-watch-companion | 897840 | `4b9328df6ef0cf0cec84e8bb9f619d1494267c0eea9850cdc6d041497163cabc` |
