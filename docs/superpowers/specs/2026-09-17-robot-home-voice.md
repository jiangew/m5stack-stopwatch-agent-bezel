# Robot Home local speech

> Public distribution amendment: publish code and documentation only. Audio is
> user-supplied through an ignored local header; missing audio means silent
> animation. Preserve the working private installation and its local branch.

## Approved interaction

The user approved two synthesized audition clips and one common talking animation.
Central short tap plays “愚蠢的人类，快给我下发任务吧！” (clear mechanical v5).
Up, down and right each play “哈哈哈，愚蠢的人类！” (fast laugh v2).
All four inputs use the same blue-eye and moving-faceplate animation, replacing
the previous happy/surprise/sleep/random reactions. Left retains workspace
navigation and its existing ready-link haptic; it does not speak.

## Boundaries

- USB-mic C152 firmware only; no Companion, protocol, permission, or service changes.
- Local prerecorded synthesis, no model, cloud request, microphone recording, or movie audio.
- Keep input-only UAC descriptors; never expose a USB speaker endpoint.
- Reuse the capture task's exclusive speaker ownership and microphone restoration.
- Active microphone streaming skips speech. Streaming requested during guard/playback
  preempts speech and restores capture; speech is never deferred until recording ends.
- Repeated gestures during an accepted utterance neither enqueue nor restart speech.
- Leaving Home, sleeping, or entering the power overlay cancels speech and animation.
- Sleeping-screen first touch only wakes. Long holds and swipes cannot also count as taps.
- No added haptics for local speech interactions. Existing workspaces remain unchanged.
- Actual speaker loudness, clarity, USB capture recovery, and UI synchronization
  require physical acceptance; builds and desktop auditions do not prove them.

## Audio assets and animation

Preserve the approved mono 24 kHz signed 16-bit PCM samples. Embed generated
read-only arrays only in the USB-mic variant, not heap copies or external downloads.
The combined PCM is approximately 263 KiB. Keep synthesized assets distinct from
microphone captures. Do not claim third-party voice likeness or film endorsement.
Use the same bounded faceplate motion and blue-eye pulse for both clips, with
duration from sample count. A skipped request still shows a short silent response.
Animation remains at most 20 fps and does not refresh inactivity or wake the display.

## Delivery

Implement and test in isolation. Preserve the known-good firmware backup.
Do not merge or push. Before any upload, enumerate the current download device,
report its exact port and obtain fresh user confirmation. Installed Companion
0.1.4, its signature and LaunchAgent remain untouched.
