# Notification model/time row

User requested Codex and DSH notification context text before the time to show
the execution model version instead of the project basename. Keep layout, fonts,
controls, title and excerpt unchanged. Other sources retain project/time.

DSH uses committed native assistant message.source.model or the current observed
request/header config.model. Track exact live root Session and observed turn,
clear on new turn/root removal/terminal end; freeze pending request model across
renewal/resolution. No global configuration, transcript scan, generation or model
invocation. Missing native model must not be replaced with a guessed version.

Installed Codex Thread.model is explicitly current configured/latest persisted
model, not per-turn execution telemetry. Native completion callback and Turn do
not expose execution model. Latest user update: prefer the last assistant reply result, then exact session
configuration. DSH prefers native reply source.model, then an explicit standalone
model annotation. Codex callback has only reply text, so use explicit annotations
when unambiguous; otherwise Thread.model. Ignore code/quoted examples and casual
model mentions. Display only the version, with no 配置 prefix. Keep internal
modelConfigured provenance for compatibility. Missing stays 模型未提供; never use
a global default. DSH retains only bounded observed live-session configuration
for fallback across turns; the latest reply overrides later configuration.

Use the existing model field (bounded ASCII on wire, explicitly ellipsized if
long) and pixel-fit existing context row; preserve time. Project metadata remains semantically project metadata, never repurposed; omit
it from Codex/DSH rich wire to reserve model/context space. Full original native model stays
in the private event. Existing already-queued events are not backfilled. Preserve
all deciding/complete-scope behavior. Update native preview before any deployment;
no live install or flash in this source change.
