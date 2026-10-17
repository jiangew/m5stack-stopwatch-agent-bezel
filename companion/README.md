# macOS quota companion

The Swift companion reads the current Codex rate-limit window from a local
Codex App Server and writes a small quota snapshot to one explicitly bound
StopWatch over the project's private BLE service.

It uses the user's existing local Codex/ChatGPT sign-in context. It does not
scrape the UI, use a cloud relay, read credentials directly, require an OpenAI
API key, or put an account token on the watch.

## Build from source

Requirements:

- macOS 14 or newer;
- Swift 5.10 or newer (Xcode 15.3 Command Line Tools or newer);
- a locally available Codex executable or an explicit `--codex-path`.

```sh
swift build -c release
```

No prebuilt companion binary is distributed by this project.

### Versioned local app packaging

From a clean repository checkout, build the release executable from that checkout,
then run from the repository root:

```sh
bash scripts/package_companion.sh companion/.build/release/codex-watch-companion /private/tmp/CodexWatchCompanion-candidate.app
```

The output must not already exist. This packages version **0.1.4**, build **15**,
with `AgentBezelSourceCommit` and UTC `AgentBezelBuildTimestamp` in Info.plist,
then ad-hoc signs and verifies the candidate. It does not install or restart it.
The caller must supply the release executable built from the recorded checkout;
the packaging fixture test is not executable provenance validation.

Installation preserves the original app directory's creation time and updates
its modification time after signature verification. Finder shows the release
version and installation modification time; custom commit/build metadata is read
from Info.plist. Future newly packaged releases must increment the build number;
reinstalling the same artifact keeps it. Metadata changes require re-signing and
can require permission reauthorization even with an unchanged bundle identifier.

## Bind a StopWatch safely

First run demo discovery. It writes synthetic data only and prints the
CoreBluetooth UUID assigned by this Mac:

```sh
.build/release/codex-watch-companion --demo --verbose
```

Use the exact UUID printed on this Mac for every real write:

```sh
.build/release/codex-watch-companion \
  --device-id YOUR_COREBLUETOOTH_UUID --verbose
```

For continuous refreshes while the terminal remains open:

```sh
.build/release/codex-watch-companion \
  --device-id YOUR_COREBLUETOOTH_UUID --watch --interval 60
```

Keep this `--watch` process running whenever automatic startup is not installed;
otherwise the dashboard will correctly mark quota sync stale.

Pass `--codex-path /absolute/path/to/codex` when automatic executable discovery
does not select the intended local Codex installation.

## Robot Home and optional workspace controls

The Deepseek extension requires matching firmware with the fixed `deepseek`
mode and four-direction dedicated navigation. It adds **Deepseek** between Codex
and SUPER and activates only **DeepSeek Harness** (`com.deepseek.dsh`). It does not
open a browser or web URL. Up/down select existing threads in sidebar order,
including across project boundaries; right toggles chat/trajectory, including on
repeated right gestures. These actions require the separately installed DeepSeek
plugin registering `Control-Option-Up/Down/Right`; this host has no native bindings
for them. Missing plugin support has no fallback. Center remains a no-op while
Deepseek is active; on its waiting/error page it explicitly launches/reopens the app.

SUPER recognizes both `engineering.super.app` and legacy
`com.zarifpour.superconductor`, preferring a running current app.

The earlier version 0.1.4 navigation repair kept the Home firmware. Released
Deepseek/SUPER/Hermes up/down/right gestures may repeat after 350ms.
Left, native Codex events and central launch retain 800ms protection on both
sides of a transition. Stroke pacing remains 30ms; gestures are not queued.
On an explicit Hermes central launch, the Companion uses Accessibility only to
obtain that process's focused/main window handle, raise it and request window
focus. It never reads titles, contents or the view tree, enumerates windows,
clicks, or moves the cursor. A missing permission preserves app opening but not
navigation; failed focus confirmation retains OPENING until the existing timeout
or another valid activation callback. Physical no-click behavior is pending.

Companion 0.1.3 (build 4) requires the matching Home USB-mic firmware. Startup,
attach, detach and stop select Home; Home ignores Mac foreground changes and
does not activate apps. With the Deepseek extension, left cycles
Home → Codex → Deepseek → SUPER → HERMES → Home.
Home head taps/up/down/right are firmware-local reactions. All work pages now
have a 15-second lease, renewed every 5 seconds, including Codex. On expiry or
disconnect firmware returns Home and rejects stale renewals until Home is
acknowledged. A fixed `show_home` event requests acknowledgment at most once per
second; it also cancels pending activation and owned modifiers without requiring
Accessibility. No project, session, window, credential or arbitrary display text
is read or transmitted. This update is not yet physically validated.

Installation and rollback must restore a matching app/firmware pair. Preserve
the existing signed app and firmware, original LaunchAgent and permissions;
never mix this Home Companion with older firmware as a supported setup. A
rollback firmware flash still requires a freshly identified and approved port.

Only a real `--watch` process enables foreground observation, radial HID input
and workspace HID output. One-shot, `--demo`, `--json-only` and bootloader
modes do not create these controllers.

| Foreground app | Left | Up | Down | Right |
| --- | --- | --- | --- | --- |
| Codex / ChatGPT (`com.openai.codex`) | Deepseek | Existing ChatGPT binding | Existing ChatGPT binding | Existing ChatGPT binding |
| Deepseek / DeepSeek Harness (`com.deepseek.dsh`) | SUPER | Previous existing thread | Next existing thread | Toggle chat/trajectory |
| SUPER (`engineering.super.app`, legacy `com.zarifpour.superconductor`) | HERMES | Previous Project | Next Project | Next Tab |
| HERMES (`com.nousresearch.hermes`) | Home | Previous / browse | Next / browse | Open selection |

Left always selects the next page in the fixed Home → Codex → Deepseek → SUPER
→ HERMES → Home cycle, even when the corresponding app is absent. It never
cold-launches an absent app. Missing Deepseek/SUPER processes show `TAP TO OPEN`;
Codex retains its original dashboard UI unchanged in every state. Only a central
tap opens the exact selected app, including an existing windowless process.
Build14 applies the same rule to Codex, Deepseek, SUPER and Hermes: a foreground
target is ready immediately, while a background or absent target waits for a
center tap. Every explicit center request opens/reopens the selected app with
`createsNewApplicationInstance = false`; activating a windowless process alone
cannot restore its closed window. Deepseek, SUPER and Hermes require a usable AX
application window; absent or unknown window state blocks navigation. A closed
last window returns to `TAP TO OPEN` on the next one-second check even if its
process remains foreground. Selection
stays on the watch when another Mac app gains focus. One bounded 1Hz observer
tracks the selected Agent, including quit/focus races; it never launches apps.
Hermes window focus is restored on entry, not repeatedly while navigating.
Existing build9 five-screen firmware is sufficient.

A request enters Opening (visually labeled `OPENING` except on unchanged Codex),
rejects duplicate taps and requires real foreground
identity confirmation (including the previously selected PID/launch date for an
already running app); launch submission success alone is not confirmation.
Rejection or a 3-second timeout shows `TAP TO RETRY`. A new open request is
central-tap only; there is no automatic relaunch. A fresh live check of the
selected foreground window can clear the error once ready, so a slow reopen
does not need a second center tap. Every waiting/opening/error page can still cycle left to the
next page or exit Home, cancelling the pending generation. Waiting selections
remain pinned despite unrelated or late Mac foreground notifications. Late
completion/timer callbacks cannot restore abandoned selection; reconnect and
restart pin Home. Up/down/right are ignored while waiting/opening/error. Once
active, existing Codex Send, Deepseek/SUPER navigation and Hermes session controls
are unchanged; generic center events do nothing on active pages.

The fixed central event is `host.open_workspace` with empty `params: {}`; legacy
`host.workspace_action` / `open_hermes` remains Hermes-only. Waiting Codex uses
`host.workspace_navigation` with `workspace: "codex"`, direction `left` and the
usual press/release phases; active Codex retains native radial reports. No new
center token is translated into Codex Send. All four waiting-state wire modes use
`state: "idle" | "opening" | "error"`, a 15-second lease and 5-second heartbeat. Home status means the screen-control link is ready,
not that Codex quota is live. Screen changes/animation never wake a sleeping
device; local animation is capped at 20 fps and reactions replace rather than queue.

Prepare the applications and permissions:

1. Optionally place each app in its own normal macOS Space and use its Dock
   menu, **Options → Assign To → This Desktop**. The companion does not create,
   enumerate or control Spaces with private APIs.
2. Configure SUPER **Previous Project**, **Next Project**, **Next Tab** as
   `Control-Option-Up`, `Control-Option-Down`, `Control-Option-Right`.
3. Keep Hermes Desktop's default `Control-Shift-Tab` and `Control-Tab` browsing
   bindings. Right sends Control down with its modifier set, then Control up
   with empty flags to commit the highlighted central-picker session. It sends
   neither Return nor Command-T. First verify a physical Control tap/release
   commits the picker on your Hermes version (confirmed on 0.17.0).
4. Leave only ChatGPT **Analog stick left** unassigned; retain up/down/right.
5. Enable the installed `CodexWatchCompanion.app` under **System Settings →
   Privacy & Security → Input Monitoring** and **Accessibility**. Restart the
   existing LaunchAgent after permissions change; do not start a second watch
   process.

After replacing and re-signing a locally ad-hoc-signed Companion, macOS may
retain permissions for the old signature. If fresh logs reject input or
Accessibility, remove the old entry and re-add the installed app in the relevant
permission pane, then restart the original LaunchAgent. Do not reset all TCC
permissions, change the app identity or create another watch process. Require
both clean fresh logs and a successful physical gesture before calling it fixed.

Missing Input Monitoring warns once without stopping quota sync. Missing
Accessibility warns once and disables Deepseek/SUPER/HERMES navigation; left
activation, display synchronization, quota and USB microphone remain separate.
Hermes uses its native picker/Tab navigation, not sidebar project-tree order.
The companion does not inspect picker state or read session/project data. A
Control is retained across Hermes up/down gestures and released by right to open
the selection. Right without an owned selection is a no-op; no confirmation is retried.
Test right both with and without the picker after installation; native keyboard
confirmation alone does not prove process-targeted delivery or physical swipe.
Deepseek sends complete Control-Option arrow chords and releases every modifier
after each command. It never uses Hermes held-Control browsing, Return, Command-T,
a new-thread action or a message-send action. Native Codex up/down/right remain
Companion no-ops, regardless of foreground app.
Navigation uses complete fixed process-targeted CoreGraphics sequences, paced at
least 30 ms apart without blocking the main RunLoop. Each action revalidates
Accessibility, foreground identity, PID, bundle ID and application launch time. It never posts
these keys globally or retries navigation commands. Physical acceptance must
still confirm ChatGPT performs no background action in Deepseek/SUPER/HERMES.

Companion 0.1.2 uses the same dedicated-direction firmware as 0.1.1; this pacing
update does not require reflashing. Versions before the dedicated-direction
firmware still require a matched upgrade.
Deepseek/SUPER/HERMES send four directions through
`host.workspace_navigation` with fixed source, direction and press/release fields instead of native `v.oai.rad`, which remains Codex-only.
The source must match both selected workspace and actual foreground before keys
are sent. A gesture releases through its original event family across a mode
change. Do not use gestures during a mixed-version installation interval.
Keep Codex up/down/right bindings; removing them is not the isolation fix.

For a bounded navigation trace, first verify the exact running Companion is the
new diagnostic-capable build, then send `SIGUSR1` to that process only. It logs
at most 120 fixed `NAV` stage records for five minutes, once per process lifetime;
repeated signals cannot extend it. Never signal an old build or another process.
No LaunchAgent edits, second watch, key-event tap or content collection is needed.
`submitted` does not prove the target app responded; require physical observation.
`sequence_accepted` means scheduling was accepted; `sequence_busy` means the new
command was ignored, not queued. `submitted` marks a completed sequence of API
submissions, not application receipt.

Left-cycle, foreground change and HID attach/removal cancel queued strokes and
release owned keys to the original still-valid process only. Such Control release
may commit an existing Hermes picker. Normal watch termination (SIGTERM/SIGINT)
attempts release before exiting; forced termination or revoked permission cannot
guarantee delivery. No global fallback or automatic permission reset is used.
See [protocol and diagnostic limits](../docs/COMPANION_PROTOCOL.md#bounded-navigation-diagnostics).

With matching USB-mic firmware, the selected Agent stays selected across Mac
foreground changes. Its idle/active state is synchronized immediately and by a
5-second heartbeat. Each work-page lease is
15 seconds and each newly attached device is synchronized immediately. A
failed Codex exit write is retried at most twice, 5 seconds apart, only for
failed devices. A new mode, detach or stop cancels obsolete retries. Failures
are logged at most once per 60 seconds, without payload or device identifiers.
Orderly shutdown attempts Home before stopping the listener. Owner disconnect
or lease expiry also restores Home; reconnect acknowledges Home before work-page renewal.

Both directional screens share four outward triangles, without an independent
center square border. The title, connection and battery stay in the center.
Each accepted local four-direction swipe chooses four distinct colors from a
12-color pool; every direction changes from its previous color. Text colors
stay fixed, redraws and heartbeats do not reshuffle colors, and the 800ms local
visual cooldown does not replace the host decoder's release gate/cooldown.

Hermes idle/error center taps require both endpoints inside the square, under
500ms and no threshold-crossing movement. A sleeping center tap wakes without
launching; the next tap can launch. Opening/active center taps are no-ops.
Center and directions share the host's 800ms cooldown. Long holds never also
submit a launch. Connection text remains device-link status, not client status.

Foreground changes while asleep do not wake the display. Disabled short taps,
Agent/Send and the left/right ChatGPT physical buttons do not wake or send HID
actions in Deepseek/SUPER/HERMES. Deepseek supports four directions (plus existing
power/Travel Mode); center does not emit an action. A swipe used to
wake the sleeping screen is consumed as a wake gesture, not sent to the app.
SUPER/HERMES retain four swipes. The red power button and existing long-hold
Travel Mode remain available. Held microphone/voice
controls are released on entry and stale Agent transitions are silently
baselined. Returning to Codex restores existing controls. The USB microphone
endpoint is unchanged.

The workspace channel sends only fixed `home`, `codex`, `deepseek`, `super` or
`hermes`, optional Hermes `idle`/`opening`/`error`, a fixed TTL and a local request number. Device
center input uses only `host.workspace_action` with `open_hermes`; the control
resynchronization action uses fixed `show_home` and does not represent a tap.
Dedicated direction input uses only fixed workspace/direction/phase enums. It does not inspect or
transmit projects, sessions, windows, Spaces, app preferences, credentials or
user content. Workspace control does not run CLI, shell, AppleScript, UI
scraping or private Space APIs; the existing Codex App Server quota subprocess
is unchanged.

For rollback, stop the original LaunchAgent, restore the backed-up signed
Companion app, verify its signature and restart that same agent, preserving its
configuration. Without renewals the Home firmware returns to Home within
15 seconds. Older companions do not understand the dedicated navigation event;
restore a matched Companion/firmware pair. Full rollback additionally restores the saved
USB-mic firmware, only after freshly enumerating the download port and obtaining
explicit confirmation for that exact port. Never reuse a historical port.
Space assignments and app shortcuts can be restored manually.

### Hermes Desktop launch policy

The screen heartbeat is not a Desktop watchdog: it only sends HID mode reports,
never application-launch requests. A separate user LaunchAgent named
`ai.hermes.desktop` may use `RunAtLoad` and `KeepAlive` to relaunch the client.
Inspect that exact job before changing anything. With explicit authorization,
back up its plist to a private directory, verify the copy hash, unload that job
and disable its label. Keep the original plist. Do not change the Companion
LaunchAgent, `ai.hermes.gateway` or `ai.hermes.dashboard`.

The approved local installation uses manual Desktop launch. Do not restore
auto-launch merely because firmware/Companion needs rollback. If explicitly
restoring the previous launch policy, verify the saved plist matches, enable
`gui/<uid>/ai.hermes.desktop`, then bootstrap the retained plist into that user
domain. This intentionally restores its former KeepAlive behavior. Never commit
private plist arguments, paths, identifiers or environment variables.

For physical acceptance: quit Desktop and check it stays closed; select Hermes
without changing Mac foreground; center cold-launch and background-activate;
test repeated tap, timeout/retry, left exit, external switching, sleep, reconnect,
existing navigation, USB input capture and quota. Build/harness success alone
does not establish physical acceptance.

Diagnostics (direct workspace probes briefly change the physical screen):

```sh
.build/release/codex-watch-companion --json-only
swift ../scripts/hid_rpc_probe.swift --self-test
swift ../scripts/hid_rpc_probe.swift --workspace-deepseek
swift ../scripts/hid_rpc_probe.swift --workspace-super
swift ../scripts/hid_rpc_probe.swift --workspace-hermes
swift ../scripts/hid_rpc_probe.swift --workspace-codex
```

The agreed physical acceptance checklist for source revision `5e9cc25` is
complete on the tested USB-mic C152 setup; see the
[layered acceptance record](../docs/superpowers/plans/2026-09-04-hermes-open-physical-acceptance.md).
It includes browse/open and no-background-action checks, sleep, lease fallback,
reconnect and local microphone recording/playback. New installations and app
updates still need their own acceptance. Build/harness results do not establish
hardware success, and the development host's missing XCTest remains an
environment limitation rather than a passing XCTest suite.

General center-launch follow-up: the updated production-source assertion harness
passed 102 test bodies with warnings-as-errors. It covers all four absent targets,
explicit launch/retry, complete cycle, cancellation while opening, unrelated/stale
foreground events, running PID/launch-date identity, Hermes window focus, strict
generic-center wire parsing and pending Codex dedicated-left isolation. Standard
`swift build -c release` passed after an approved exact-command retry. No installation,
service restart or physical acceptance was performed for this follow-up; installed
build8 and navigation plugin 0.1.1 were left unchanged.

Previous Deepseek directional source verification: a temporary assertion harness compiled
current production Swift sources with `-warnings-as-errors` and passed all 100
test bodies, including complete Deepseek chords, repeated right, every partial
cancel/stop, PID/launch identity, foreground/profile/permission rejection,
350ms/800ms release gating, fixed cycle, heartbeat and Home reconnect. It does not
run XCTest: this host's installed CLT lacks `XCTest` (established in the preceding
verification). The Release SwiftPM build with warnings-as-errors and the offline
HID probe `--self-test` both passed after approved exact-command retries; initial
attempts were blocked by nested sandbox/module-cache permissions. No app installation, real `--watch`,
live HID probe, physical gesture, or quota/audio acceptance was performed for
this directional extension. App-local sidebar/view semantics require the separate
plugin tests and later physical acceptance.

## Optional USB-mic bootloader request

The USB-mic firmware can be asked to restart into the ESP32-S3 serial
bootloader over the same encrypted private GATT characteristic:

```sh
.build/release/codex-watch-companion \
  --device-id YOUR_COREBLUETOOTH_UUID --enter-bootloader
```

This explicit maintenance mode cannot be combined with `--demo`, `--watch`, or
`--json-only`. The USB-mic firmware requires an encrypted, with-response write
from the same BLE peer that completed a valid Codex HID RPC in the current
connection epoch. Its main loop checks VBUS, waits 400 ms, checks VBUS again,
and only then restarts. The stable non-microphone firmware never acts on this
command.

An ATT acknowledgement proves only that the encrypted command reached the
device, so the companion exits successfully only after BLE disconnects. Before
uploading, resolve the newly enumerated `/dev/cu.*` bootloader port and verify
that it belongs to this StopWatch; never reuse or guess a stale port.

## Optional local background installation

For unattended CoreBluetooth access, Codex can wrap the locally built binary in
a small background `.app` using [`app/Info.plist`](app/Info.plist), ad-hoc sign
that local wrapper, and create a per-user LaunchAgent from
[`launchd/io.github.codex-micro-stopwatch.companion.plist.example`](launchd/io.github.codex-micro-stopwatch.companion.plist.example).

This is a local installation step, not a distributed package. The generated app
belongs under `companion/.local/` or another local application directory. The
generated LaunchAgent belongs under the user's `~/Library/LaunchAgents/`.

Before loading the LaunchAgent, replace every placeholder with an absolute local
value:

- `__EXECUTABLE_PATH__`: executable inside the locally built app wrapper;
- `__CODEX_PATH__`: intended local Codex executable;
- `__DEVICE_UUID__`: UUID printed by demo discovery on this Mac;
- `__LOG_DIRECTORY__`: a private local log directory.

Codex should lint the generated plist, verify the ad-hoc-signed app with
`codesign --verify --deep --strict`, load it only after user approval, and use
`launchctl print gui/$UID/io.github.codex-micro-stopwatch.companion` plus one
real quota/reset update as the health check. To uninstall, boot out that exact
per-user LaunchAgent before removing only the generated local app, plist, and
logs; never delete or edit the tracked templates.

Do not edit the tracked example in place. Never commit the generated plist,
app, UUID, usernames, home paths, or logs. The root README contains the
recommended prompt for asking Codex to perform and verify this installation.

The first Bluetooth access may trigger a macOS permission prompt. Discovery
filters on the private quota service UUID rather than the advertised
`Codex Micro` name. Real writes additionally require the exact bound
CoreBluetooth UUID, so another same-name peripheral is ignored.

## Data boundary

The companion sends the percentage and reset fields documented in
[`docs/COMPANION_PROTOCOL.md`](../docs/COMPANION_PROTOCOL.md) over the private
quota GATT service. In a real `--watch` run it additionally sends only the fixed
`home`/`codex`/`deepseek`/`super`/`hermes` display mode RPC over Report ID 6.
Agent status, button events, and voice actions otherwise stay on the Codex Micro HID channel. The companion
recognizes only fixed radial/dedicated/control events described above and emits
only fixed Deepseek/SUPER/Hermes process-targeted key sequences. Deepseek's
plugin performs sidebar thread selection and chat/trajectory toggling inside the
app; no application content crosses the Companion/HID boundary. It does not capture keyboard text. It does not read or transmit project names, session titles,
windows, Spaces, workspace state, credentials, prompts, conversation content,
or audio. Audio is outside this companion's scope.

### Build13 control availability

See [diagnosis and acceptance](../docs/CONTROL_AVAILABILITY.zh-CN.md). macOS must
grant both Input Monitoring and Accessibility to the current installed Companion.
An enabled row can refer to an older ad-hoc signed binary. If permission checks
still reject after toggling, remove the stale row, add the installed app again,
and restart the Companion. Do not reset unrelated applications' permissions.
Startup logs report the actual process Accessibility result. HID connection alone
and local watch haptics do not prove navigation delivery.

## Optional task notification adapters

The [private notification bridge](TASK_NOTIFICATIONS.md) is opt-in via `--notifications-dir` and remains independent of quota/HID/navigation. [Source-native adapters](../notifications/README.md) provide Codex completion callbacks, separate DSH Host audit/projection observers, a strict SUPER native lifecycle collector and Hermes agent hooks. They keep generic display text and opaque native identities in a private Mac directory; they do not copy prompts, commands or transcripts into tracked files or BLE identity fields.

Every current native adapter disables native decisions. The OPEN consumer routes only identity-bound open requests and reports an exact-session request or an explicit application-activation fallback; neither clears nor approves a native request. No hooks, external profiles, apps or providers are changed automatically. Source/fixture tests, SUPER no-model envelope observation, live native installation and C152 physical delivery are distinct validation layers. See the adapter guide before enabling an integration.

After opting into native Codex notify, add `--native-codex-notifications` together with `--watch --notifications-dir ...` to suppress duplicate legacy Codex completion alerts while the dedicated channel is fresh. This defaults off, preserves status LEDs, and restores legacy alerts after 15 seconds of stale/disconnected delivery. Physical duplicate-alert acceptance remains outstanding.
