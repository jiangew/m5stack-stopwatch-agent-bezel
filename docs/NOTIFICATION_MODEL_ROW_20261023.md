# Codex / DSH model-time row candidate — 2026-10-23

Time's left-hand context now identifies the model, replacing the project label
for Codex and DSH rich notifications. The existing fonts, centered task/body,
status, n/N, compact footer and all gestures remain. Other sources keep project.
This is an uninstalled follow-up to the reviewed DSH content candidate.

## Model provenance

- DSH0.2.1-rc.2: exact live root Session and observed current turn; committed
  request/header config.model, then assistant message.source.model. The latter
  also covers tool-bearing steps without copying tool text. Missing/invalid
  identifiers stay missing. Clear model tracking on new turn/end/root removal;
  freeze each attention request's captured model through heartbeat and outcome.
- Codex: installed native ThreadReadResponse schema explicitly describes
  Thread.model as current configured/latest persisted model and **not per-turn
  execution telemetry**. The completed-turn callback/Turn has no execution-model
  field. The user selected exact thread-configuration fallback with `配置`
  displayed before it. A strict optional modelConfigured flag carries provenance;
  no global config lookup, history read, resume or inference request is added.
- Names are not invented. Missing data shows 模型未提供; earlier queue entries do
  not acquire historical models. Preview model IDs are synthetic examples.

Model stays a version string, separate from provenance. Native IDs<=128 printable
identifier bytes are admitted; long wire values<=32 ASCII bytes have explicit
ellipsis. Pixel fit preserves time. Codex/DSH wire omits unused project metadata,
while the private original retains its project. Qualification is immutable at
same revision, validated by Python/Swift/firmware, and never changes authority.

## Verification

The new collector tests first failed on missing native model; native rendering
first failed on the old project row. Production fixes now pass:

-29 Node observer/content/owner tests, including exact current model, pending
 freeze, no cross-turn fallback and unchanged default-off legacy behavior.
-44 Python adapter/content tests using the actual Swift bridge in the full runner;
 separate native0.2.1 real Session/header/assistant model contract passes with
 synthetic events, zero model invocations and no profile changes.
-Standalone Swift/broker/transport and15 ingress tests;8 actual Swift wire
 fixtures accepted by real firmware parser under sanitizers. Rich model values,
 explicit qualification, bounded JSON, long names and complete native scope pass.
-Firmware parser/controller/UI/main-loop tests cover source-specific context,
 missing model, qualified Codex text, pixel bounds/time retention and controls.
-Native framebuffer, standard firmware, selected USB-mic+IMU target
 m5stack-stopwatch-home-imu and release Companion builds pass. Companion0.1.4,
 build18. Native previews use real adapters/projection/parser/UI, with synthetic
 model IDs. Current preview shows Codex configured, DSH completed/waiting, missing.

## Deployment boundary

No running Companion, collector, Host profile, LaunchAgent or firmware has been
replaced. A new coordinated release must include Codex observer, DSH observer,
generic OPEN relay, Companion and firmware. Preserve nativeApprovalsfalse and
exact device binding. Keep explicit port confirmation, app0/protected backups,
readback and separate USB audio/HID/BLE/control/native callback acceptance.
Builds and synthetic fixtures establish no live DSH or physical C152 result.
