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
