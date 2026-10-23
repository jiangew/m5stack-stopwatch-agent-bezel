# Notification Touch and Badge Implementation Plan

> **For agentic workers:** Use executing-plans inline in the existing isolated feature worktree.

**Goal:** Enlarge approved touch targets and Home badge, then deliver native previews.

**Architecture:** Keep geometry in TaskNotification.h and reuse the DSH control
style in TaskNotificationUi.h. Rendering and controller consumers share the
badge constants; role drawing and host notification routing stay unchanged.

**Tech Stack:** C++17, M5GFX native renderer, PlatformIO, ASan/UBSan host tests.

## Global Constraints

- Button rectangles remain140×48px; only upper hit padding changes8→28px.
- Badge center388,232; visible radius52; hit radius60; Space Mono46px digits.
- No firmware flash, protocol/host change or role transform change in this task.

## Task 1: Target behavior and badge rendering

- [x] Extend real controller cases in simulator/task_notification_test.cpp:
  (148,316) closes; (318,316) opens; (318,315) and gap(233,316) do neither.
  Check upper-region press locking,20px movement cancellation and52px swipes.
- [x] Update simulator/task_notification_ui_test.cpp badge fixtures for the
  enlarged circle, native digits and DSH fill/ink. Run the focused host suite
  against old implementation and observe the missing upper hit/circle failures.
- [x] Update FooterButton::hit and badge constants in include/TaskNotification.h;
  update badge style in include/TaskNotificationUi.h using DSH style functions.
- [x] Run scripts/test_task_notifications_firmware.sh through success.

## Task 2: Native evidence and build

- [x] Build native-preview and default firmware with pio run; build the selected
  USB microphone+Home IMU environment in usb-mic without uploading.
- [x] Render badge counts1/64, wide roles and tilt, notification Chinese/English
  pages; compare portrait-only framebuffer pixels with the preceding native
  binary. Export PNGs and a gallery in the existing ignored output directory.
- [x] Inspect the native preview and circle clearances; open the gallery in the
  in-app browser, run git diff --check and record evidence without private data.
- [x] Commit scoped implementation and validation evidence; report preview
  ready and explicitly leave flashing/physical sensitivity validation pending.

Latest user correction applied: all roles use fixed center(388,232), diameter104px. The51-frame native comparison and fixed-position gallery supersede the initial112px proposal. Physical acceptance remains pending a later update.
