# Robot home for C152 USB-mic

Status: Written design for review. Visual appearance and startup/disconnect
behavior were approved by the user; this document defines device integration.
Baseline: `f3be5a4`. Work serially on `codex/robot-home`.

## User experience

- Add a fourth, local robot home using the approved Q-style yellow/black helmet,
  blue eyes and silver mechanical mask. No logo, voice, chat, network fetch,
  microphone sampling or application-content access is added.
- Boot, Companion startup, device disconnect and reconnect select Home. Mac
  foreground changes do not leave Home. Home does not activate any Mac app.
- Left cycle is Home -> Codex -> SUPER -> HERMES -> Home. All Hermes states
  (idle, opening, error, active) cycle to Home. Cancel outstanding activation and
  owned navigation keys before leaving the current workspace.
- Home -> Codex activates the existing Codex/ChatGPT target. Failed activation
  leaves Home available for another manual swipe. Codex -> SUPER keeps its
  existing activation behavior. SUPER -> HERMES keeps the existing tap-to-open
  behavior; do not launch Hermes on selection or heartbeat.
- Once in a work page, actual Mac foreground changes retain existing follow
  behavior. Returning to Home pins the selection again. No private Space API.
- Without a usable Companion link, Home stays interactive locally; left briefly
  displays CONNECT MAC and remains Home instead of sending native Codex input.

## Rendering and local interaction

- A dedicated native renderer uses the 466x466 coordinate system. The approved
  browser mockup is visual reference, not an embedded web runtime. Translate its
  shapes into bounded vector primitives; no downloaded image or new dependency.
- Robot head occupies approximately x=88..378, y=108..319. Connection status is
  centered near y=64, mood near y=357, and battery icon plus measured percentage
  are centered as one unit near y=395. Use real battery/charging/link inputs,
  including unknown battery; do not display the mockup's fixed 82%.
- Idle has gentle vertical breathing and blinking. Short head tap gives a head
  tilt and smile eyes; up gives surprise; down gives sleepy eyes; right chooses
  a different expression from happy/surprised/sleepy. Reactions last 2400ms and
  replace the current reaction, never queue. No extra sounds or vibration.
- A head tap requires press/release inside the head bounds, less than 500ms,
  and movement never reaching the existing swipe threshold. Swipes and power
  holds cannot also produce taps. Reuse existing coordinate rotation handling.
- First touch on a sleeping screen only wakes it, consuming the whole gesture.
  Keep red-button behavior, central long-hold power overlay and travel shutdown.
  Agent/Send and left/right physical ChatGPT keys are silent in Home.
- Render at most 20fps while visible and animated, with no blocking delays or
  catch-up frames. Stop animation rendering while asleep, off-page or showing a
  power overlay. Animation never counts as user activity or wakes the device.
  Maintain Codex/SUPER/HERMES appearance and random triangle colors unchanged.

## Ownership, connection and protocol

- Add Home to the shared display-mode model, not to Mac app identities. Separate
  selected display from actual foreground so Home cannot be treated as Codex by
  a default branch. Routing rejects app navigation while Home is selected.
- Use the existing Report ID 6 framing. Extend workspace mode with the fixed
  `home` value and dedicated navigation with `workspace: home` for left only.
  Home tap/up/down/right never emit native or dedicated navigation events.
- Reuse the 800ms host action debounce and release gating for Home left. Local
  facial reactions replace one another immediately and do not consume app keys.
- Preserve the 5-second host heartbeat and 15-second lease duration. In the new
  USB-mic pairing, every work page, including Codex, is leased; an expired lease
  returns Home. Screen-control messages remain ControlOnly, never quota/live
  activity. All timers and host writes remain serialized on MainActor.
- The new Codex lease form adds `ttl_ms: 15000`; retain parsing of the legacy
  Codex form for old/default behavior. Only the new USB-mic integration enables
  Home boot/fallback. Default wireless behavior is unchanged.
- After local fallback to Home, reject stale work-mode renewals until Companion
  acknowledges Home. Use a fixed home-resynchronization action on the existing
  device-event channel; it changes selection only and cannot activate an app.
  Companion handles it even without Accessibility, cancels obsolete requests,
  releases owned keys and sends Home. Retry this control notification at most
  once per second while connected until acknowledged; never log payloads.
- On host HID attach/reset, synchronize Home before allowing any new work-page
  activation. Disconnect clears the corresponding device state; late callbacks
  cannot restore an old selection. Companion stop best-effort sends Home.
- Invalid messages do not change state or refresh a lease. No additional device
  identifiers, arbitrary text, project/session names or credentials are sent.
  New Companion and USB-mic firmware are a matched update; do not claim a mixed
  old/new installation supports Home.

## Verification and installation

- TDD coverage: strict mode/event parsing; ownership and millis wrap; Home
  fallback and stale-heartbeat rejection; reconnect acknowledgement; all four
  cycle transitions; failed activation; late Hermes callbacks; Home foreground
  pinning; no app events from facial interactions; permission degradation.
- Native renderer/gesture tests: all facial states, real/unknown/charging/low
  battery, circular bounds, text alignment, first-wake consumption, pointer
  cancellation, swipe vs tap vs power hold, reaction replacement, asleep frame
  suppression and no animation-induced wake or activity extension.
- Run the complete native suite and USB-mic build; regenerate native previews
  for user confirmation before installation. Run fixed-SDK Companion release,
  mode smoke and Swift harness tests. Report XCTest environment limits separately.
  Serial code review must check input cleanup, HID lifecycle and audio isolation.
- Preserve recoverable firmware and signed-app backups with hashes. Install one
  matched Companion update with current version/build/time metadata; preserve
  original app signing identifier, LaunchAgent, binding and log configuration.
  Do not restore the disabled Hermes auto-launch task or create another watch.
- Flash USB-mic only after re-enumerating the download device and receiving new
  explicit authorization for the exact port. Historical port consent is invalid.
- Physical acceptance: boot/offline Home, reconnect pinning, all reactions,
  four-page cycle, old navigation, no Codex background actions, sleep/power,
  heartbeat-loss fallback, restart, quota updates and temporary USB-mic recording
  with user-confirmed deletion. Logs/builds do not replace physical observations.
- Stop on critical regression and restore matched backups if required; a
  rollback flash also requires fresh device/port confirmation. No merge or push
  is included in this installation request.

## Self-review

The explicit Home selection overrides only foreground following while on Home.
All app identities, Hermes open semantics, targeted-key mappings and USB audio
boundaries remain intact. Home acknowledgement prevents stale heartbeat takeover
after local fallback. Installed-device results are still unverified; only the
browser appearance has user approval at this stage.
