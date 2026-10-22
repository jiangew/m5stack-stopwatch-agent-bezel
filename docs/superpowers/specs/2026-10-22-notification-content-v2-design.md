# Notification content V2

Approved: identify the real task, show a truthful outcome and a bounded excerpt;
Chinese task names are required, complete long replies stay in the native Mac app.
Codex is the first content adapter; other harnesses retain their current ingress.

- Keep existing workspace, Home, gestures, button regions, read-only OPEN routing,
  approval ownership and full-scope validation unchanged.
- Header shows canonical source and selected position/count. Context shows a short
  native project basename and event time. Task title uses at most two lines.
- Completion means TURN ENDED, not proven task success; failed/input/approval use
  truthful display statuses instead of exposing raw pending. Model stays absent
  when not supplied by the native event; never substitute defaults.
- Rich Codex capture is explicit opt-in. Exact metadata-only thread/read continues
  to verify root lineage; a native name is preferred. Missing names use a stable
  local task serial. Metadata preview and input messages are not title substitutes.
- Extract plain text from the callback's last reply with no translation/model call.
  Private ingress remains bounded; native app retains the full reply. Truncation
  is explicit. Do not log content, absolute workdirs or native routing IDs.
- Rich event fields are optional and existing queues remain readable. The new Mac
  wire builder is separately opt-in, retains v1 compatibility, and fits <=512 UTF-8
  bytes without cutting a codepoint. Approval capability cards keep the original
  complete ASCII-scope path and never use a shortened deciding scope.
- Firmware accepts bounded valid UTF-8 for read-only display. Existing M5GFX CJK
  fonts render Chinese at native size; Space Mono remains on Latin-only strings.
  Missing rare glyphs may fall back; do not replace system fonts or add downloads.
- Current footer is preserved: columns x88/264, 15px, y378/395; BACK y430. Rich
  excerpts must leave this area clear. Full-page/body scroll is outside this slice.
- Installed Companion, hooks and firmware are not replaced during implementation.
  Deployment needs reviewed candidate builds and coordinated opt-ins, followed by
  physical acceptance; no pairing or signing changes are implicit in a preview.
