# Unified workspace and notification typography

Approved in the UI review on 2026-10-21, followed by authorization to build and flash.

- Keep the existing Codex dashboard and its six Agent controls unchanged.
- DSH, SUPER and HERMES adopt the Codex black background, Space Mono typography,
  central dial and four solid circular swipe indicators. Indicator radius is
  56 px; centers are (233,72), (398,237), (233,402), (68,237).
- The central dial is centered at (233,237), radius 104 px, with a thin status
  ring instead of a quota gauge. Keep the existing profile names and prompts.
- Keep all input routing, center hit regions, swipe thresholds, release gates,
  launch/foreground behavior, haptics, power behavior and palette cooldowns.
- Home and notification layout geometry remain unchanged. Notification digits,
  titles, body and hints use Space Mono VLW fonts rendered at native scale.
  Body remains centered and all 192 ASCII context bytes must remain visible.
- Notification display names are exactly Codex, DSH, Super and Hermes. Wire IDs
  remain codex/deepseek/super/hermes. Only known system-generated titles may be
  normalized; command/task content and approval scope must never be rewritten.
- Render a model row only when a real model identifier is present. No guessed
  model/version, global default substitution or fixture placeholder is added.
  Native model capture remains outside this UI update.
- Preserve USB input-only audio, BLE/HID and Home IMU. Keep prior accepted images
  and backups; application-only flashing requires an exact live port and backup.

Browser review artifacts are proposals. Release acceptance requires native
framebuffer inspection, builds, regression tests, independent flash readback,
protected-area verification and user acceptance on C152.
