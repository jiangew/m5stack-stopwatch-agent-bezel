# Notification footer buttons Implementation Plan

> **For agentic workers:** Use executing-plans inline in the existing isolated feature worktree.

**Goal:** Implement the approved two-button footer and prevent OPEN/BACK mistargeting.

**Architecture:** Shared button geometry in TaskNotification.h drives controller hit targets and TaskNotificationUi.h. Preserve wire and host protocols. Generate native14px hints from the existing licensed Space Mono asset.

**Tech Stack:** C++17, M5GFX, generated VLW fonts, existing host/native/PlatformIO toolchains.

## Global Constraints

- BACK/OPEN140×48px at(78,344)/(248,344);8px hit padding, separate targets.
- Single-layer body centered22px/28px; bounded excerpts with ellipsis, no MORE ON MAC.
- Native decision scope/hold controls remain unchanged; no Mac replacement.
- Explicit exact-port app-only gate and independent physical acceptance.

### Task1: Controller and renderer

- [x] Replace obsolete footer regressions with real center/edge/gap/hint/press-lock/drift/swipe cases. Verify failure on old full-width BACK.
- [x] Capture read-only button target at press, cancel after20px motion, process swipes before button clicks, remove bottom-wide BACK for read-only pages.
- [x] Add native14px generated font; render filled BACK/OPEN, two hint rows, no standalone BACK or MORE. Bound read-only body above controls with ellipsis.
- [x] Verify renderer failure before implementation; run complete firmware regressions through success and inspect native pixels.

### Task2: Candidate and installation

- [x] Build native/default/selected USB-mic+Home-IMU; render six existing synthetic wire fixtures. Candidate pins follow the implementation commit.
- [ ] Report preview; detect the current download port, verify known C152 identity and backup app0/protected64KiB against installed9fd2369 image.
- [ ] Obtain exact-port confirmation, write only app0, independently read back and compare protected bytes.
- [ ] After RESET, verify USB enumeration/short capture/HID/IMU, then request user center/edge BACK/OPEN, gestures and Home/Agent acceptance. Record observed boundaries.
