# Notification content V2 candidate — 2026-10-22

## Behavior

Codex is the first richer native content source. Explicit `--rich-content` on the
notify hook captures the exact native thread name, project basename and bounded
last-assistant reply. Explicit Companion `--notification-content-v2` projects
read-only done/failed cards into a <=512-byte UTF-8 frame. Both defaults are off.

A card identifies its selected position/count, a short project and local time,
a two-line Chinese-capable task name, truthful event status, and a centered
excerpt. Codex round completion says `TURN ENDED`; other done sources say
`COMPLETED`; failures say `FAILED`. Clipped content has an ellipsis and
`MORE ON MAC`. Native task text is not a proof of successful work. Missing task
names have a stable local serial; no preview/prompt or guessed model fills gaps.

Existing queue identities, original bounded local event body, OPEN routing,
read/dismiss/next/previous and complete-scope approval admission remain unchanged.
Footer columns x88/264, y378/395, 15px and BACK y430 remain unchanged. Legacy
browsing still displays all192 ASCII body bytes at23px line spacing. Rich body
uses pixel-measured UTF-8 wrapping; bundled M5GFX efontCN supports common Chinese,
with coverage limits for rare characters and emoji. Latin-only strings use the
existing Space Mono assets. Full reply scrolling is outside this candidate.

## Evidence and bounds

- Installed Codex CLI schema contains native `Thread.name` and `cwd`. One exact
  metadata-only local probe confirmed both fields and root lineage, with empty
  `turns`. Its actual values/IDs were not logged or tracked.
- The callback's last reply is capped at4096 UTF-8 bytes in the owner-only private
  bridge; wire title<=32 characters/96 UTF-8 bytes, detail<=128 UTF-8 bytes and
  project<=32 UTF-8 bytes. JSON fitting can reduce the excerpt further. It reserves
  maximum count/position/ack widths to keep the excerpt stable on acknowledgement.
- No transcript scan, inference request, translation, font download, native
  approval implementation, pairing change or global SDK/toolchain change.
- Old events do not acquire historical names or replies retroactively. Other
  harnesses retain their current content collectors and native capability limits.
- A full title and reply are private user content. Enable capture only through the
  explicit coordinated rollout. Real events and source IDs remain outside Git.

## Candidate validation

The following run locally against the candidate source, without hardware I/O:

- Python rich-content/adapter regressions:41 tests,2 optional native tests skipped.
- Standalone Swift broker/content/reconnect/transport regressions;14 ingress and
  Python→Swift private-file tests. Six actual Swift-produced rich wire fixtures
  parsed by the real firmware C++ parser under sanitizers.
- Firmware parser/controller/UI regressions with ASan/UBSan, root main-loop input
  ownership and legacy completion isolation. Actual drawScreen default/USB-mic
  regression covers unchanged Agent/Home displays and17 Home roles.
- Standard firmware, native framebuffer preview, selected USB-mic+IMU firmware,
  and release Companion builds. Companion packaging increments build15→16.
- Native preview fixtures include short/long Chinese titles, mixed text, Chinese
  project metadata, clipped English/Chinese excerpts, legacy and read-only detail.

SwiftPM needs a writable task-local Clang/module cache and `--disable-sandbox` in
this agent environment (nested sandbox-exec is denied). No global toolchain or
cache permissions were changed. The pre-existing M5GFX VLA extension warning is
separate from candidate source validation.

## Deployment gate

This is a source/build candidate. Live Companion replacement, hook editing,
firmware flashing and physical acceptance have **not** happened for V2.
Private candidate manifests pin source, artifact lengths and SHA-256 values.
Current working installed artifacts and recovery backups remain in place.

1. Review native framebuffer previews and the fixed patch.
2. Install the matching Companion candidate and preserve device binding, private
   runtime and all existing launch arguments; add only the explicit V2 opt-in.
   Changing the signed app can require rechecking Input Monitoring/Accessibility.
3. Preserve the hook's existing config/arguments; add only `--rich-content`.
   Existing open threads' hook reload behavior requires observed acceptance.
4. Identify the exact connected C152 `/dev/cu.*` immediately before flashing,
   obtain explicit port confirmation, back up the current application and first
   64KiB, write app0 only, then independently read back and verify protected bytes.
5. Physically accept real newly completed named Chinese Codex tasks, distinct
   position navigation, OPEN ON MAC, dismiss/BACK, Home/Agent controls, quota,
   Bluetooth reconnect, USB input-only audio and HID/RPC separately.

Before returning to an older firmware or Companion, disable both V2 opt-ins.
Keep the existing native notification ownership flag and relay settings. Old
queue decoders tolerate the optional local fields; firmware rollback still needs
the normal exact-port/app-only recovery checks. No physical success is claimed
from a synthetic render, test or build.
