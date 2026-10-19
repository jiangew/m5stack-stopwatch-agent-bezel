# Notification Layout Implementation Plan

> **For agentic workers:** Execute inline in the existing isolated feature worktree.

**Goal:** Put the count badge at 3 o'clock and lower Inbox/Toast content by 30 px.

**Architecture:** Share badge geometry between controller hit testing and drawing.
Apply a content offset only to Inbox and Toast; preserve other views and controls.

**Tech Stack:** C++ headers, existing host regression runner, native framebuffer preview.

## Global Constraints

- Badge center `(420, 233)`; existing 46×44 appearance.
- Inbox/Toast upper content offset `+30` px; BACK and lower controls unchanged.
- No Mac application/profile changes, firmware build or device write in this preview task.

## Task 1: Adjust and preview the layout

Files: `include/TaskNotification.h`, `include/TaskNotificationUi.h`,
`simulator/task_notification_ui_test.cpp`, `simulator/task_notification_main_test.rb`,
`simulator/preview_main.cpp`.

- [x] Extend the existing UI check to capture drawn text/rectangles. Verify the
  badge lies on the right horizontal centerline and its controller target covers
  it; the old badge point must not open the inbox. Render a maximum-length body
  in Inbox and Toast and ensure the title is lower and body clears y=290.
- [x] Run `sh scripts/test_task_notifications_firmware.sh`; observe the new
  positioning check fail on the old implementation.
- [x] Define shared badge bounds `(397,211,46,44)` and a 4 px hit margin in
  `TaskNotification.h`; use them for rendering and hit testing. In `render`, use
  `offset = (view==Inbox || view==Toast) ? 30 : 0` for heading/model/title/state/body.
  Update main-loop badge fixtures to the new center.
- [x] Add preview scenarios for the badge on Home, Inbox and full-length Inbox.
  Run the host checks again, then `pio run -e native-preview`.
- [x] Render the scenarios to ignored local artifacts, convert framebuffer PPM
  files to PNG with `sips`, inspect them and deliver clickable inline previews.
- [x] Run `git diff --check`, commit the scoped source/tests and mark steps complete.

## Follow-up: Compact fixed hints after preview feedback

- [x] Extend the existing render check to require complete, larger body text and
  two small hints below the content. Observe failure before changing the renderer.
- [x] Keep Inbox/Toast upper offset at +30 px. Render body at size 2, 32 columns,
  max seven rows. Put the smaller outcome at y=350 and fixed hints at y=382/398.
  Preserve BACK and all controller hit regions/gesture behavior.
- [x] Run the firmware host regressions and native-preview build. Regenerate and
  inspect normal/max-length Inbox PNGs, then commit the scoped change.
