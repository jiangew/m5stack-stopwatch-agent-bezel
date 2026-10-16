# Home faction artwork

The shipped roster contains seventeen 300×300 baseline RGB JPEGs on black. Their
outer 18px remains black within 12/255 JPEG tolerance so the 1.18× Home
animation can stay clear of the status and battery rows. The sixteen full-body
images are built-in imagegen fan illustrations of recognizable Transformers
characters. The preserved portrait and new images are unofficial, unlicensed
artwork embedded in firmware; Home does not fetch images over a network.

## Sources

- `bumblebee.jpg` is the existing project portrait. Its accepted ring-free idle
  JPEG is preserved byte for byte at SHA-256
  `f1bb7e24fe30631b15e1999c35a0b8d4024d3fc52b222aa0ad6c5d6676a9d191`.
- `bumblebeefullbody.png`, `optimus.png`, `jazz.png`, `hotrod.png`,
  `wheeljack.png`, `hound.png`, `ironhide.png`, and `ratchet.png` are fitted 300px,
  black-backed production inputs. All eight original full-resolution illustrations were produced with
  the built-in imagegen tool. The unmodified full-resolution files stay in
  local task outputs, outside Git. Fitting crops only near-black outer canvas,
  scales each complete figure to at most 246×264, and centers it on 300×300
  black; it does not redraw the illustration. The fitted PNGs are committed so
  firmware builds do not need image generation.
- The first three full-body images (Optimus, Jazz, Hot Rod) followed a common
  brief: one classic G1 Autobot, full body from head to boots, approximately
  three heads tall, Japanese mecha cartoon, confident dark ink outlines,
  layered armor and cel shading, centered on solid black with generous margins,
  readable at 280px, and no scene, weapon, text, UI, or other character.
  Optimus has red truck-cab chest, blue windows, blue helmet and legs, silver
  mouthplate and a greeting pose. Jazz has white race-car chest, blue visor,
  black joints, blue/red striping and a thumbs-up pose. Hot Rod has red/orange
  armor, yellow flame chest, gold spoiler silhouette and an energetic stance.
- The later three prompts used the same full-body framing. Bumblebee adds a
  yellow/black car-robot body, blue eyes, hood chest, wheel calves and a wave;
  Wheeljack adds white racing armor, cyan ear panels, green/red markings and a
  small engineering wrench; Hound adds olive jeep armor, circular lamps,
  off-road wheels, radio antenna and a salute. Their complete prompt text is
  retained in the local task output `new-character-prompts.md`.
- Ironhide and Ratchet use the same three-head-tall, cel-shaded, black-background
  style. Ironhide has a red van-cab chest, black windshield, silver thighs and
  a stocky veteran pose. Ratchet has white ambulance armor, red medical marks,
  blue eyes and a friendly medic pose. Their exact built-in imagegen prompts
  and full-resolution originals remain in the local task output
  `home-autobots-ironhide-ratchet`; the committed 300px PNGs are the fitted
  production inputs. No external image service or API key was used.

The generated imagery may include small insignia-like armor graphics. Asset
provenance describes how the files were made; it does not claim ownership of
the underlying characters.

## Reproduce the embedded files

With Python, Pillow, numpy and Ruby available, run from the repository root:

```sh
python3 scripts/prepare_robot_home_art.py
ruby scripts/embed_robot_home_art.rb assets/robot-home/generated include/RobotHomeArtData.h
python3 simulator/robot_home_art_test.py
swift -module-cache-path /private/tmp/autobot-swift-cache simulator/robot_home_art_test.swift
```

The preparation script preserves the accepted Bumblebee radial crop and JPEG
encoder settings. It serializes the sixteen black-backed PNGs without resizing
them, then removes retired generated JPEGs. Existing assets keep quality=95; the eight new
Decepticons use quality=93, 4:4:4 sampling and the same baseline RGB encoding
to remain below 50KiB. The embed script validates the JPEG
boundary and 50 KiB ceiling. The tests check exact header payloads, ImageIO
decoding, margins, distinct decoded artwork, deterministic regeneration and the
preserved Bumblebee digest. Pillow/libjpeg upgrades can change JPEG bytes and
therefore require deliberate regeneration and review.

## Decepticon sources added 2026-10-16

`megatron.png`, `starscream.png`, `soundwave.png`, `shockwave.png`,
`thundercracker.png`, `skywarp.png`, `blitzwing.png`, and `astrotrain.png` are
fitted full-body PNGs from built-in imagegen. The former ring portraits
`megatron.jpg` and `starscream.jpg` remain unchanged and are not embedded for
these new identities. The existing nine idle and ten response JPEGs remain
byte-identical to the accepted baseline.

All sixteen new originals (eight idle / response pairs) were generated or
edited through built-in imagegen, with no API key or external image service.
The brief requires recognizable G1 identities, roughly three-head-tall chibi
proportions, dark outlines, crisp cel shading, a pure black background, and
complete helmets, wings, hands and boots. Starscream, Soundwave and Shockwave
received proportion refinements; Thundercracker, Skywarp and Blitzwing received
face refinements. The response edits change one arm into an acknowledgement,
retaining the idle's square canvas, head, torso, feet, scale and visual style.
Exact path-free prompts, selected source SHA-256 values, fitted PNG and final
JPEG hashes, and numeric transforms are in `actions/manifest.json`; readable
prompt copies are in `actions/PROMPTS.md`. Raw originals, discarded variants
and local source paths stay in ignored task outputs.

Fitting uses the idle's non-black bounding box (>12/255), one uniform scale
that fits within 246×252px, and one centered translation. The **same** affine
transform defines an identical source box for each paired response's whole
original canvas, retaining arm extensions beyond the idle bounding box. Black
padding permits source coordinates outside that canvas. LANCZOS box resizing
applies a scale-aware antialias filter: the previous affine BICUBIC sampler
introduced jagged lines and moire during the roughly 4.5× reduction. The source
illustrations, figure dimensions, translation and JPEG quality remain unchanged.
Both frames are composited through
the same 24px black safety canvas aperture; fitting rejects any visible pixels
(>24/255) outside it. The 24px block-aligned canvas prevents JPEG ringing at the
required 18px idle margin. No character or response artwork is drawn by Python.

For a deliberate local re-fit with the selected ignored imagegen input record:

```sh
python3 scripts/prepare_robot_home_art.py --imagegen-inputs artifacts/home-factions/imagegen/inputs.json
```

Ordinary builds use the committed fitted PNGs and response JPEGs and need no
originals or image generation. Tests replay the full pair fitting in an
isolated directory when the ignored originals are available, compare final
bytes and manifests, check real head/boot registration and substantive response
changes, and execute the C++ enum-to-payload mapping. Swift ImageIO independently
decodes all 17 idle and 18 response assets (`--actions` for the response bank).
These checks and the local previews establish asset-level evidence only;
physical-device display and animation acceptance remain separate.

The antialiasing correction is an unflashed asset revision. Physical Home
acceptance recorded for `81f91fef` / `0aaa4606a3c3` belongs to the previous
sampling output; the corrected display must be checked on the device separately.
