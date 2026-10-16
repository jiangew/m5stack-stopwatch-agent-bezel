# Character response poses

Eighteen baseline JPEGs, 300×300, each below 50KiB. They are separate from the
seventeen accepted idle JPEGs; selection chooses among the sixteen full-body identities.

Four JPEGs are exact copies of the Bumblebee full-body and Optimus pilots
accepted on 2026-10-14; their captured source details are in
`simulator/prototypes/home_tap_motion/manifest.json`. The six other poses are
built-in imagegen edits of the original full-resolution idle artwork. Their
exact prompts (including the discarded first Hound variant) are in `PROMPTS.md`;
hashes and fixed original-idle registration are in `manifest.json`.

Only geometry fitting and JPEG serialization used Pillow. Pose artwork was
produced by imagegen. The source-size wording in prompts describes a square
canvas; delivered sources were 1254×1254, matching the originals. Edited arm
silhouettes may extend beyond the original idle box, so each pose is sampled
using the fixed idle transform rather than being independently recentered.
Small generated differences in untouched details remain, especially Hot Rod's
legs; the same identity, scale, foot extents and visual style were inspected at
actual size. These are discrete pose changes, not skeletal interpolation.

Regenerate the embedded action header without modifying idle artwork:

```sh
ruby scripts/embed_robot_home_action_art.rb assets/robot-home/actions include/RobotHomeActionArtData.h
```

`RobotHomeMotion.h` selects the pose and a small native transform for each
600ms response. The portrait uses native nod/tilt motion with its unchanged
JPEG. No energy-effect overlays or audio are used. Low-memory fallback keeps
the correct idle figure and its native transform rather than decoding action
JPEGs per frame. These remain unofficial fan-art assets.

Eight Decepticon responses added on 2026-10-16 are built-in imagegen edits of
their selected full-body idle originals. Their 300px JPEGs use quality=93 with
4:4:4 sampling and optimized baseline RGB encoding. The existing ten response
payloads and nine idle payloads retain their accepted bytes. Every new response
uses the corresponding idle's exact uniform scale, translation, whole-canvas
sampling and black safety aperture; none is independently centered. Source,
fitted-input and JPEG SHA-256 values and both fixed transforms are recorded in
`manifest.json`; no personal paths are tracked. The fitting method and local
reproduction command are documented in `../GENERATION.md`.

The eight gestures are Megatron's raised non-cannon fist, Starscream's greeting,
Soundwave's listening hand, Shockwave's raised index finger, Thundercracker's
thumbs-up, Skywarp's open-hand wave, Blitzwing's raised fist, and
Astrotrain's temple salute. These are unofficial fan illustrations
embedded locally in firmware; Home performs no network image fetch.
