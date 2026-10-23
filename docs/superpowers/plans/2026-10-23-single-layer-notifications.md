# Single-layer notification reading Implementation Plan

> **For agentic workers:** Use executing-plans in this existing isolated worktree. Execute inline with the user-approved preview as the checkpoint.

**Goal:** Collapse stock read-only notifications into one reading page and improve body typography.

**Architecture:** Branch only on Card.decide in the current Controller/renderer. Preserve native decision flow and all host/wire contracts. Share OPEN button geometry between controller and rendering.

**Tech Stack:** C++17, M5GFX, PlatformIO native framebuffer, existing ASan/UBSan host tests.

## Global Constraints

- All stock canDecide=false notices use Inbox/Toast as their only reading page.
- Body text stays centered; rich English22px, Chinese approximately22px, baseline28px.
- Native decision controls, complete scope, freshness and hold protection remain unchanged.
- No firmware flash or Mac runtime installation in this preview task.

### Task1: Controller and rendering

Files: include/TaskNotification.h, include/TaskNotificationUi.h,
simulator/task_notification_test.cpp, simulator/task_notification_ui_test.cpp.

- [x] Add a real Controller fixture with decide=false, openInbox/READ ACK, body tap; assert Inbox remains and no new action. Tap inside the future OPEN button; assert ActionKind::Open. ACK then swipe up/down from the button; assert Next/Previous rather than Open. Verify outside taps, Toast pinning and timeout.
- [x] Run scripts/test_task_notifications_firmware.sh and observe the new assertion fail on the current Detail transition.
- [x] Add shared button bounds and read-only branch in release(): classify gestures first; body tap pins Toast to Inbox; button tap issues Open; decide=true retains Detail.
- [x] Render read-only button and revised compact hints. Add size/lineStep arguments to richWrapped with existing defaults; body uses2.f/28px/five rows and CJK22/24 scale. Preserve title defaults and complete legacy scope.
- [x] Update UI regression assertions to preserve full scope and prove body/footer separation; run the firmware regression suite through success.

### Task2: Native preview and evidence

Files: native framebuffer output under ignored outputs; this plan/spec and deployment documentation.

- [x] Build native-preview with HOMEBREW_PREFIX=/opt/homebrew pio run -e native-preview.
- [x] Render the existing reply-first/fallback/DSH/waiting synthetic wire fixtures with the native executable; create before/after browser comparison.
- [x] Inspect actual images and verify footer/body geometry; fix collisions and rerun affected checks if found.
- [x] Record passed gates and show preview to user; retain installed-release acceptance separately from this unflashed candidate.

User accepted the native preview and requested update preparation. Standard and
selected USB-mic+Home-IMU firmware builds also passed. No flash has occurred.
