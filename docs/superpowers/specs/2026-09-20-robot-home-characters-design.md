# Robot Home cinematic character selector

Status: Approved by the user on 2026-09-20, including the cinematic visual
direction and its embedded-vector interpretation.
Baseline: `536499b`. Continue on `codex/robot-voice-public`.

## User experience

- Home still opens on Bumblebee. Its existing center-tap voice line and speech
  ownership rules remain unchanged.
- Up selects Optimus Prime, down selects Megatron, and right selects Starscream.
  Repeating the direction for the currently selected character returns to
  Bumblebee. A different direction switches directly to that character.
- Character selection is local to the watch. It sends no HID key or workspace
  action, does not activate a Mac app, and plays no speech sample.
- Left retains the existing Home -> Codex behavior and its approved single
  haptic pulse. Leaving Home resets the next Home visit to Bumblebee so the
  device always has a stable, recognizable landing state.
- Center tap on any selected portrait plays the same currently approved task
  voice line. It does not impersonate the selected character with new audio.

## Visual system

- Each character has an independent embedded-vector head renderer. Do not
  implement the characters as one shared face with palette swaps.
- Use the approved cinematic concept as a silhouette reference, then reduce it
  to bounded filled polygons, thick dark seams and a small number of flat
  highlight planes suitable for the 466x466 display.
- Bumblebee keeps rounded yellow/black automotive armor, two short antennae,
  large blue optics and a compact silver respirator.
- Optimus Prime uses a red/blue angular helmet, tall side antennae, narrow blue
  optics and a tall silver grille mouthplate.
- Megatron uses a broad, asymmetric gunmetal crown, scarred layered planes,
  deep-set red optics and a heavy jaw.
- Starscream uses a narrow silver face, swept-back jet-fin framing, red optics,
  pointed cheek plates and a sharp chin.
- Preserve the existing black background, real connection status and centered
  real battery indicator. Do not add logos, faction marks, film frames or
  downloaded runtime assets.

## Animation and input

- A character switch replaces the current reaction immediately; transitions
  never queue. Use a short armor reveal plus character-colored outline/eye
  pulse, then settle into the existing low-cost idle breathing/blink loop.
- Up/down/right remain silent and add no vibration. Left keeps its existing
  workspace-switch vibration. The first touch while asleep remains wake-only.
- Center speech uses one shared talking animation contract: portrait bob,
  optical pulse and a small mouth/faceplate movement where the renderer permits.
  The audio, timing and microphone-priority behavior are unchanged.
- Existing tap-versus-swipe and power-hold mutual exclusion remains intact.
  Character selection must not consume or synthesize Mac navigation input.
- Rendering stays non-blocking and capped by the existing 20fps frame gate.

## Architecture

- Add a `Character` enum (`Bumblebee`, `Optimus`, `Megatron`, `Starscream`) to
  the Robot Home domain state and keep the selection entirely in firmware RAM.
- Add a small selector state machine that maps directions to targets and toggles
  a repeated target back to Bumblebee. It owns transition start time but does
  not own audio, HID or workspace state.
- Split drawing into character-specific helpers sharing only display chrome,
  connection/battery rendering and animation timing. This keeps each silhouette
  independently testable and prevents future shape coupling.
- Keep `RobotSpeechData` and the ignored private `RobotSpeechLocal.h` boundary
  unchanged. No new distributable voice asset is introduced.
- Companion, Report ID 6 protocol, workspace lease, LaunchAgent and navigation
  mappings do not change.

## Verification

- Native tests cover the direction-to-character table, repeat-to-Bumblebee,
  direct cross-character selection, reset on Home exit and no emitted host action.
- Renderer tests exercise every character in idle, transition and talking states,
  all battery variants, charging, connection and power overlays; every primitive
  must remain inside the circular 466x466 canvas.
- Native previews show all four characters at real output size and demonstrate
  their transition midpoint. Visual acceptance is required before flashing.
- Run the full native suite and warning-free USB-mic build. Confirm the public
  asset-free build still works when local voice data is absent.
- Installation requires a fresh firmware backup, download-port re-enumeration
  and explicit confirmation of that exact port. Companion is not reinstalled.
- Physical acceptance covers four character selections, repeat toggles, center
  speech, Home -> Codex, sleep/power behavior, USB microphone priority and the
  unchanged Codex/SUPER/HERMES navigation. Only user-observed results are marked
  verified.

## Scope boundary

This change is firmware-only. It does not add film imagery, official trademarks,
new audio, network access, application control or user-content collection. The
public repository remains source-buildable without the private local voice file.
