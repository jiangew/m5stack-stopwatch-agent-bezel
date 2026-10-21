# Unified Workspace UI Implementation Plan

> **For agentic workers:** Execute this authorized plan inline, task by task.

**Goal:** Implement the approved workspace and notification typography on C152.

**Architecture:** Change rendering and font resources only. Reuse existing
controller state and the established application-only updater.

**Tech Stack:** C++17, M5GFX VLW, Space Mono, PlatformIO, Python/Pillow.

## Global Constraints

Keep Codex rendering, input regions, touch/gesture routing, haptics and native
adapter behavior unchanged. Notification names: Codex, DSH, Super, Hermes.
Retain 192 context bytes, centered text, existing badge geometry and no invented
model metadata. Preserve prior firmware and protected flash regions.

## Task 1: Shared circular workspace rendering

Files: `include/SuperWorkspaceUi.h`, `simulator/super_workspace_ui_test.cpp`.

- [x] Extend real-renderer recording tests to require four circular directional
  indicators, existing labels, pending-state prompts, no quota fields, measured
  title/battery alignment and no overlap with the center dial.
- [x] Run the focused C++ test before implementation and observe the expected
  triangle-versus-circle failure.
- [x] Replace triangle drawing with circles, native chevrons and a static thin
  status ring; retain current state inputs and palette behavior.
- [x] Run focused renderer and existing workspace input/launch tests.

## Task 2: Native-size notification fonts and display names

Files: `scripts/generate_notification_fonts.py`, `include/NotificationFonts.h`,
`include/TaskNotificationUi.h`, `simulator/task_notification_ui_test.cpp`.

- [x] Extend rendering tests to record loaded font data and require scale 1,
  canonical source names, absent empty model text, complete 192-byte context,
  unchanged badge geometry, and no offline approval controls.
- [x] Run the focused test and observe the expected legacy-font failure.
- [x] Generate only additional 15/22/24 px fonts; reuse the existing 18/46 px
  assets unchanged. Map notification roles to native sizes, and normalize only
  known system-generated titles. Do not modify raw notification payloads.
- [x] Run the existing notification firmware and coupled host regression suites.

## Task 3: Native validation and application-only release

- [x] Build default firmware, native-preview and selected USB-mic + Home IMU.
- [x] Inspect native workspace, pending, badge 1/9/10/64 and short/long notification
  frames. Verify real glyph ink and footer clearance, including read-only detail.
- [x] Run all C++ host regressions and relevant Ruby main-loop/render tests.
- [x] Commit only reviewed source, fonts, tests and design/release documentation.
- [x] Prepare a new immutable private candidate and updater. Resolve the actual
  connected C152 port; back up app0/protected regions and confirm exact target.
- [x] Flash app0 only, independently compare readback and protected regions,
  restart, and request physical UI/audio/HID/Home acceptance.

Device write/readback/protected-region checks passed. The user confirmed
physical RESET, appearance and interactions normal. HID/IMU RPC and a short USB
audio capture passed; see the validation record.
