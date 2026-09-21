# Robot Home speech

## Public source versus private audio

The public repository includes playback code and animation, **not voice samples**.
Without a local audio header, Home inputs show silent talking animation and do
not switch the codec to speaker mode. Completion chimes are unaffected.

To supply audio you are authorized to use, prepare two mono 24 kHz signed PCM16
WAV files (0.1–5 seconds each), then run:

```sh
ruby scripts/embed_robot_speech.rb TASK.wav LAUGH.wav include/RobotSpeechLocal.h
pio run -d usb-mic
```

`RobotSpeechLocal.h` is ignored by Git and loaded by `RobotSpeechData.h` only
when present. Never force-add it without checking redistribution rights.
Native audio-owner tests use zero-filled synthetic buffers, not private speech.
The public commit is based on the prior public main and does not include the
private audio commits in its ancestry. Existing installed firmware is unchanged.

Code-only publication verification: 16 native C++ tests and four compiled
production-function harnesses passed. USB-mic and preparation builds passed
without compiler warnings; the asset-free USB image uses 1370363 flash bytes.
Missing audio returns `Unavailable` before reserving the audio owner. The existing
installed Companion is unchanged; no re-signing or permissions reset is needed.

## Historical local audition provenance

The two user-selected clips were synthesized locally using macOS Tingting and
processed with FFmpeg. They are not microphone captures, movie excerpts, a
performer's cloned voice, or an official character voice. No TTS model is
downloaded or installed. No speech content is sent to the Companion.

| Input | Fixed line | PCM frames at 24 kHz | Audition SHA-256 |
| --- | --- | --- | --- |
| Central short tap | 愚蠢的人类，快给我下发任务吧！ | 84372 | `3f0ca8b10323509195920b0af583380e9c480cd0d91ce3cee2d90c1b440865bc` |
| Up/down/right | 哈哈哈，愚蠢的人类！ | 50200 | `81e0ed4e90f55213a19be1e5a2adebc1dc9dd87a0b0d91002214e9e39d3b0c0d` |

`scripts/embed_robot_speech.rb` validates mono 24 kHz PCM16 WAV inputs and emits
the ignored `include/RobotSpeechLocal.h`. The private header contains 269144 bytes of PCM samples;
the generated textual source is larger. Audio remains in read-only flash and
is excluded from the default wireless image. No heap copy or playback queue.
The exact WAV sample data is preserved; WAV container metadata is not embedded.

These synthesized assets are a **local personal-use candidate**. They are not
automatically covered by the repository's source-code MIT license. Before public
distribution or commercial use, independently verify the system voice's output
usage rights or replace the assets with appropriately licensed recordings.
This change does not authorize merge/push or imply redistribution clearance.

## Runtime safety

### 2026-09-21 central-voice candidate

The user approved a stronger locally synthesized mechanical voice audition for
the unchanged central-tap task phrase. It lowers pitch, tightens tempo, adds
controlled saturation and a light metallic modulation without downloading a
model or cloning a performer. The approved WAV is mono PCM16, 24kHz,
3.226375 seconds; SHA-256
`f775ff01dcfee20767009a292bf9db9c4ae889332ecbd199b50dac23ffb6cc3c`.
It is embedded only in the ignored private header, not distributed here.
Up/down/right remain silent character selection.

The subsequent equal-spacing follow-up halves only this central clip's PCM
amplitude (approximately -6 dB), preserving its duration and tone. Its private
WAV SHA-256 is
`40d5f40f394358f86e4e2fcff1faf50ed5c29ae01f32bcfc9a1a0bd5872c8e49`.
After upload, the user confirmed the reduced voice level, centered/equally
spaced Home layout, character selection and four-workspace controls normal.
This is user-observed acceptance, not an inference from the build. No new
microphone recording test was performed for this follow-up. See
`superpowers/plans/2026-09-21-home-equal-spacing-half-volume.md`.

### Ownership and cancellation

Only the capture task changes microphone/speaker codec ownership, using the
existing 200 ms idle guard. A USB stream request (including a brief alt1 pulse)
wins over local speech. Playback checks preemption each task tick and restores
capture before declaring completion. Codec failure also goes through restoration.
Leaving Home, display sleep or a power overlay cancels speech. No new haptics.
Left navigation keeps its existing single ready-link haptic. Wake-only touch and
long holds never start speech. Input-only USB descriptors and all app controls
are unchanged; no Companion installation or permission changes are needed.

The four-character Home selector introduces no additional voice samples. Up,
down and right only select local portraits and remain silent; center tap on any
portrait uses the same authorized local task clip and one Talking animation.
Pending/playing audio status holds it;
terminal status ends it. Skipped/unavailable speech produces 1200 ms of silent
animation. Repeated inputs during either response are ignored, never retried.
The existing `chime_*` local audio counters now also include speech requests;
`Cancelled` is an additional local terminal result, not a new wire message.

## Verification layers

Native tests exercise actual production request, audio-owner, reaction and swipe
functions with hardware-boundary doubles. They are not physical audio tests.
Renderer tests check circular geometry and centered battery across animation frames.
USB-mic firmware must build before a freshly confirmed port can be flashed.
Companion/XCTest is outside this firmware-only change and is not claimed tested.

User-observed checks passed after upload: both lines, common face animation,
repeat suppression, left cancellation, recording quality, silence during USB
recording and speech restoration after closing the recording application.
Wake/power behavior, offline interaction and a complete four-screen regression
remain unverified for this image. See the implementation plan's acceptance record.
