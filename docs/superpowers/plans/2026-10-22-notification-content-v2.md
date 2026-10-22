# Notification Content V2 Implementation Plan

> **For agentic workers:** Execute this authorized plan inline task by task.

**Goal:** Ship a tested Codex-first rich read-only notification candidate with
Chinese task names, position, project/time, truthful status and bounded excerpts.

**Architecture:** Add optional display metadata at local ingress and derive bounded
wire presentation in the Mac broker. Preserve legacy/approval paths. Extend only
notification firmware parsing and rendering; use existing M5GFX CJK assets.

**Tech Stack:** Python, Swift/Foundation, C++17, M5GFX, PlatformIO.

## Global Constraints

No inference request, transcript scan, fabricated model/title/result, new native
approval path, live runtime replacement, or unconfirmed device flashing. UTF-8
wire <=512 bytes. Preserve task identity, navigation, original complete approval
scope, current fonts for Latin text, footer and previous accepted artifacts.

## Task 1: Rich Codex callback and compatible local events

Files: notifications/adapters/codex_notify.py, runtime.py, scripts/stopwatch_notify.py,
notifications/tests/test_adapters.py, scripts/tests/test_stopwatch_notify.py.

- [x] Add failing fixtures for native Chinese name/project, actual last reply,
  root exclusion, missing metadata fallback, opt-out privacy, bounded UTF-8 and
  no captured input/preview. Keep old resolver and ingress fixtures compatible.
- [x] Add optional project/excerpted metadata, explicit --rich-content opt-in,
  exact metadata lineage wrapper and plain-text excerpt normalization.
- [x] Run Python ingress/adapter regressions and commit this independently tested slice.

## Task 2: Native model and bounded wire presentation

Files: TaskNotificationModel.swift, TaskNotificationBroker.swift,
TaskNotificationRuntime.swift, main.swift, standalone regression files.

- [x] Add failing Swift cases for optional-field queue compatibility, Chinese
  titles, stable untitled serial, all visible positions and <=512-byte fitting.
- [x] Add --notification-content-v2 (default off), opt-in broker projection and
  immutable metadata comparisons. Preserve the legacy complete deciding path.
- [x] Run host/coupled notification suites with Unicode and long-content fixtures.

## Task 3: UTF-8 firmware and native preview

Files: include/TaskNotification.h, include/TaskNotificationUi.h,
simulator/task_notification_test.cpp, task_notification_ui_test.cpp, preview_main.cpp.

- [x] Add failing tests for valid/invalid UTF-8, bounded title wrapping, indexed
  navigation, CJK font selection, semantic status and untouched legacy scope.
- [x] Render rich title/project/excerpt with native CJK fallback and measured
  wrapping; keep every legacy action/hit region and footer unchanged.
- [x] Build standard, native and USB-mic+IMU candidates; inspect short/long/mixed
  Chinese frames and verify circle/footer clearance. Run relevant regressions.

## Task 4: Reviewable candidate and deployment boundary

- [x] Update bilingual docs and native data/capability evidence, record build/hash
  and tests. Review the fixed patch before any merge or runtime replacement.
- [x] Present native previews and exact remaining deployment steps. Keep the
  installed working system untouched until installation/flash acceptance.


## Candidate handoff

Implementation pin: `7ec093f64390b147aa285c0be36bc2cae4b4d212` on
`feature/notification-content-v2`. Both P2 review findings were reproduced and
fixed; narrow re-review found no actionable regression. Final validation:42
Python tests (2 optional skips),15 coupled bridge tests, standalone Swift,
firmware sanitizer/main-loop regressions and actual drawScreen checks; release,
standard/native and selected USB-mic+IMU builds passed. Native preview opened.

Candidate installation, opt-in activation, exact connected-port flashing and
physical acceptance remain pending user review. Existing installed services,
hooks, queue and firmware remain untouched. No merge/push was requested here.


## Deployment follow-up —2026-10-22

- [x] User accepted native previews and explicitly confirmed the exact flash port.
- [x] Full app0/protected backup, app-only update, independent readback and
  protected-area equality passed for the pinned USB-mic+IMU candidate.
- [x] Installed build16, compatible OPEN relay and rich Codex hook; preserved
  outer callback and other collectors. Current permissions re-added and checked.
- [x] USB capture, HID/IMU, quota writes and physical synthetic Chinese UI/navigation
  acceptance passed; recorded private receipts and deleted temporary audio.
- [x] Installed exact-thread metadata-only lookup verified root/name/cwd availability.
- [x] Observed a natural current-thread Codex completion callback in the installed
  real broker, with native name/project/excerpt and resolved state; physical
  viewing of this particular real notice remains separate from ingestion.

See `docs/NOTIFICATION_CONTENT_V2_UPDATE_20261022.md`. No extra inference task,
merge or push was performed. Existing generic notices retain their old content.
