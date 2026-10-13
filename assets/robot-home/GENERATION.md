# Home hero artwork

All shipped portraits have a solid black field and no decorative boundary ring.
The final four hero JPEGs are 300×300 baseline RGB JPEGs. Their outer 18px margin
is black (up to 12/255 JPEG ringing), allowing the 1.18× animation scale.

## Sources and outcome

- `bumblebee.jpg`, `optimus.jpg`: existing original project artwork. The accepted
  ring-free idle derivatives remain byte-for-byte unchanged.
- `ironman.svg`, `spiderman.svg`: original, editable geometric comic portraits
  drawn for this project. Explicit gold/red faceplate with narrow cyan-white eyes;
  red fabric mask with curved black webbing, white lenses and blue shoulders.
  Matching PNG files were deterministically rasterized from these SVGs using Sharp.
- The built-in imagegen service was attempted once per requested new hero. Both
  requests failed with HTTP 400 `moderation_blocked`, at the output stage, category
  `other`. No generated raster result was returned or used. No alternate image
  model, paid API, API key, external artwork, or unrelated character was used.
  The final images are repo-native vector artwork, not imagegen output.

## Reproduction

With Node.js and Sharp available, rasterize the editable originals:

```sh
node -e 'const sharp=require("sharp"); Promise.all(["ironman","spiderman"].map(name=>sharp("assets/robot-home/"+name+".svg").png().toFile("assets/robot-home/"+name+".png"))).catch(e=>{console.error(e);process.exitCode=1});'
```

With Python, Pillow, numpy and Ruby available:

```sh
python3 scripts/prepare_robot_home_art.py
ruby scripts/embed_robot_home_art.rb assets/robot-home/generated include/RobotHomeArtData.h
python3 simulator/robot_home_art_test.py
swift simulator/robot_home_art_test.swift
```

PNG files are checked in as build inputs. The preparation script preserves the
accepted radial crop of the original robot artwork and serializes only the four
idle portraits. Retired hero and eyelid derivatives are removed from `generated`.
JPEG serialization is reproducible within the same Pillow/libjpeg environment;
encoder upgrades may change bytes and require deliberate regeneration.

## Unsuccessful built-in prompts

Reference image for both requests: `generated/optimus-idle.jpg`, inspected before
use; its role was style/composition only. Opaque black background was requested.

### Iron Man

> Use case: stylized-concept. Asset type: square tiny watch avatar. Create an ORIGINAL Iron Man helmet portrait matching the reference's bold angular comic metal-avatar visual language and scale; the reference is STYLE AND COMPOSITION ONLY, not an edit target. Single centered symmetrical front-facing red-and-gold Iron Man armored helmet with narrow white-cyan eyes, recognizable gold faceplate and dark mouth slit, tiny shoulder hints. Flat graphic cel shading, crisp black outlines, saturated red panels and warm gold faceplate, high readability after resizing to 300x300. Pure solid black RGB(0,0,0) background. Subject occupies central 70 percent of square width and height, entirely contained inside x=15..85%, y=15..85%, with generous pure black margins on every edge for animation scaling. No decorative circle or rim, no halo, no glow outside the helmet, no aura, no text, no logo, no watermark, no particles, no scene, no hands, no torso. Square image.

### Spider-Man

> Create an original stylized Spider-Man masked head portrait for a small watch avatar, using this Optimus portrait only as a reference for bold outlined comic shading and centered scale. Frontal red fabric mask with clear black web lines and large white eye lenses with black borders, small blue-red shoulder hints. Crisp clean shapes readable at 300 pixels. Square canvas with completely solid black background. Keep all artwork centered in the middle 70% of canvas, leaving generous black margins on all four sides. No circular rim, no glow, no background decoration, no text or watermark.
