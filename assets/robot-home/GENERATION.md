# Home Autobot artwork

The shipped roster contains seven 300×300 baseline RGB JPEGs on black. Their
outer 18px remains black within 12/255 JPEG tolerance so the 1.18× Home
animation can stay clear of the status and battery rows. The six full-body
images are built-in imagegen fan illustrations of recognizable Transformers
characters. The preserved portrait and new images are unofficial, unlicensed
artwork embedded in firmware; Home does not fetch images over a network.

## Sources

- `bumblebee.jpg` is the existing project portrait. Its accepted ring-free idle
  JPEG is preserved byte for byte at SHA-256
  `f1bb7e24fe30631b15e1999c35a0b8d4024d3fc52b222aa0ad6c5d6676a9d191`.
- `bumblebeefullbody.png`, `optimus.png`, `jazz.png`, `hotrod.png`,
  `wheeljack.png`, and `hound.png` are fitted 300px, black-backed production
  inputs. All six original full-resolution illustrations were produced with
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
encoder settings. It serializes the other six black-backed PNGs without resizing
them, then removes retired generated JPEGs. The embed script validates the JPEG
boundary and 50 KiB ceiling. The tests check exact header payloads, ImageIO
decoding, margins, distinct decoded artwork, deterministic regeneration and the
preserved Bumblebee digest. Pillow/libjpeg upgrades can change JPEG bytes and
therefore require deliberate regeneration and review.
