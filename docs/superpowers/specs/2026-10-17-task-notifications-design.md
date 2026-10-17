# Four-harness task notifications and approvals

Status: user approved the conversational design on 2026-10-17; implementation authorized. This file records the agreed scope. Hardware deployment and native harness support require separate evidence.

## Outcome and boundaries

Stopwatch receives completion, approval, input and failure notifications for Codex, DeepSeek Harness, super.engineering and Hermes through the Mac Companion. The watch can allow once or decline a concrete native request when its adapter supports exact request correlation and authoritative acknowledgement. Reading or dismissing a notification never approves or rejects it. Unsupported native decisions show OPEN ON MAC. No session-wide or permanent authorization. No simulated keystrokes to approve. A completed turn is not product acceptance; tools and child agents do not independently announce the parent task as complete.

## Ownership

Mac owns the persistent queue, deduplication, request identity, expiry, delivery receipts and harness routing. Firmware owns only a bounded current card, notification count, gesture UI, wake/feedback and opaque action identity. Existing vendor HID and quota GATT behavior remain separate from new project-owned notification GATT characteristics. Credentials, full prompts, captured audio, real task content and local device IDs never enter tracked files. Adapter inbox and decision files live in a private user directory, not the checkout; samples use synthetic values.

## UI

A new event wakes the screen and presents a five-second card; it does not interrupt an active gesture, microphone control or power confirmation. A persistent notification badge opens the inbox on all workspaces. Up/down browse; back returns to the previous workspace. Approval detail shows source, session alias, model, operation and scope. Only fully displayable decision context enables allow-once/decline. Choosing a decision opens a confirmation view; a fresh stationary 800ms hold submits. Wake touches and in-flight gestures are swallowed. New arrivals never replace an open detail or confirmation card. Submission shows PENDING until a native resolution, or UNKNOWN after receipt loss. At most three short haptic pulses distinguish done/needs-input/failure; initial candidate pulse intensity176 duration30ms, with gap120ms, subject to physical acceptance. Audio is optional and skipped during USB microphone streaming.

## Data and reliability

Notification identity contains source, opaque session, run and native request; revisions are monotonic. Duplicate events do not alert again. Local read state and native resolution are separate. Native approval requires a current lease, matching revision, pending state and decision capability. Decisions are idempotent per request revision. Retrying transport never blindly re-executes approval. Restarts restore queue but cannot replay old decisions. Reconnection synchronizes latest cards without replaying historical buzzes. Priority: approval/input, failure, done; stable FIFO within a class. Pending approval receives at most one optional reminder after120s; done never repeats. Acks for delivery, native decision and resolution remain distinct.

## Integration acceptance

Each installed harness must be inspected for lifecycle events, existing desktop session coverage, native pending request identity, decision API and authoritative resolution. Official docs establish possible integration surfaces, not installed runtime coverage. Codex app-server separately spawned for quota does not own desktop requests. DSH navigation plugin currently forbids content/network reads and remains unchanged; notification support is a separate server plugin. Hermes Gateway hooks are not assumed to run in Desktop. SUPER cannot be claimed supported without a stable verified interface. All four source types are supported by the common event contract; per-harness live capabilities are reported explicitly.

## Verification

Behavioral tests cover deduplication, stable ordering, multiple requests, stale revisions, native resolution on Mac, lease expiry, invalid payloads, missing capability, disconnection, ambiguous acknowledgement, restart and gesture isolation. Build Companion debug/release and default/native/USB-mic firmware as applicable; no flash until a frozen candidate and explicit exact-port confirmation. Preserve current known-good hardware and installed Companion until then.
