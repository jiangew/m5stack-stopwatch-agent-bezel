# DSH notification content implementation plan

Execute the user-approved scope inline in the existing isolated worktree.

**Goal:** Complete DSH native content and read-only attention parity with Codex.
**Architecture:** Bounded opt-in native event collection; optional local reason;
shared Swift wire projection; layout3 read-only attention and semantic UI labels.
**Tech stack:** Node/Electron native packages, Python, Swift, C++/M5GFX/PlatformIO.

## Constraints

Follow the matching spec. No history scan, title/model invocation, native decision
extension, live-profile edits, runtime replacement or device flash during source
work. UTF-8 wire<=512 bytes; input/approval capabilities keep complete ASCII scope.
Preserve footer, controls, existing installed baseline and recovery artifacts.

## 1. DSH native content

- [ ] Red fixtures in notifications/tests/deepseek-content.test.mjs for title
  projection, header cwd, exact current-root reply, controls/Unicode/escaping,
  root/turn isolation, terminal reasons and immutable pending resolution.
- [ ] Implement notifications/adapters/deepseek/content.mjs and opt-in observer
  integration in index.mjs; retain legacy/native-owner path and relay bounds.
- [ ] Run Node observer/owner/lifecycle regressions; commit tested collector slice.

## 2. Shared read-only content contract

- [ ] Add failing Swift/C++/Python cases for strict optional terminal reason,
  layout3 read-only attention, semantic status and heartbeat/outcome-stable text.
- [ ] Extend event schema, immutable comparisons, bounded wire projection and
  firmware parser/UI. Preserve full deciding scope and action state machine.
- [ ] Run actual Swift-to-firmware wire, host bridge and firmware regressions.

## 3. Candidate validation and handoff

- [ ] Verify installed native0.2.1-rc.2 Session/title/header/message contracts
  with synthetic native events and inert generation; no live tasks/models.
- [ ] Build release Companion and native/default/selected USB-mic+IMU firmware;
  inspect completed/approval/input/resolved native DSH previews.
- [ ] Update docs, review immutable patch, package pinned candidates and present
  the existing-design preview. Record remaining profile reload/firmware/live
  acceptance gates. No merge/push unless requested.
