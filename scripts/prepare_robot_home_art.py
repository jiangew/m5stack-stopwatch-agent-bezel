#!/usr/bin/env python3
"""Derive ring-free portraits and mechanical eyelids from the original artwork.

Requires Pillow and numpy. Originals in assets/robot-home stay untouched.
Run before embed_robot_home_art.rb; generated JPEGs are deterministic.
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/robot-home'
OUTPUT = SOURCE / 'generated'
# A feathered radial mask removes the baked rim and glow. Central face and
# inner helmet detail remain intact, but shoulder/helmet edges that meet the
# old rim are trimmed too (especially Starscream). Native previews need human
# visual acceptance; this is not a reconstruction of missing outer artwork.
CENTERS = {'bumblebee': (150, 148.3), 'optimus': (149.15, 148.3),
           'megatron': (149.58, 147.88), 'starscream': (148.3, 145.1)}
# Actual luminous eye apertures in the 300px source, not the lower mouth plate.
EYES = {
    'bumblebee': [[(113,156),(123,156),(130,165),(130,173),(124,180),(112,180),(105,174),(105,164)],
                  [(177,156),(185,156),(194,164),(194,173),(188,180),(176,180),(169,173),(169,164)]],
    'optimus': [[(100,161),(110,163),(136,169),(136,173),(121,177),(111,174),(103,168)],
                [(198,161),(189,163),(162,169),(162,173),(177,177),(188,174),(195,168)]],
    'megatron': [[(108,138),(119,140),(129,146),(128,151),(118,151),(111,146)],
                 [(192,138),(180,140),(170,146),(171,151),(182,151),(189,146)]],
    'starscream': [[(106,143),(115,146),(129,156),(129,160),(120,160),(111,154)],
                   [(192,143),(183,146),(169,156),(169,160),(178,160),(187,154)]]
}


def derive(name):
    original = np.array(Image.open(SOURCE / (name + '.jpg')).convert('RGB'))
    yy, xx = np.mgrid[:300, :300]
    cx, cy = CENTERS[name]
    radius = np.hypot(xx - cx, yy - cy)
    # Original ring radius is 135-140px. The 126..130px transition is
    # confined to the black gap / outermost shoulder, leaving the face intact.
    alpha = np.clip((130.0 - radius) / 4.0, 0, 1)
    idle = np.rint(original * alpha[:, :, None]).astype(np.uint8)
    frames = {'idle': Image.fromarray(idle)}
    for phase, closure in [('half', .52), ('closed', 1.0)]:
        result = idle.copy()
        for eye in EYES[name]:
            mask_image = Image.new('L', (300, 300))
            ImageDraw.Draw(mask_image).polygon(eye, fill=255)
            # Soft subpixel edge merges into the surrounding eye socket.
            mask = np.array(mask_image.filter(ImageFilter.GaussianBlur(.55))) / 255.0
            ys = [p[1] for p in eye]
            top, bottom = min(ys), max(ys)
            if closure < 1:
                mask *= yy <= top + (bottom - top) * closure
            # Neutral gunmetal shutter with a shallow horizontal bevel. Keep
            # the original fine texture, but extinguish the blue/red optic.
            texture = idle.mean(axis=2) * .10
            shade = 24 + 18 * (yy - top) / max(1, bottom - top) + texture
            lid = np.stack([shade * .78, shade * .88, shade], axis=2)
            result = np.rint(result * (1-mask[:, :, None]) + lid * mask[:, :, None]).astype(np.uint8)
        frames[phase] = Image.fromarray(result)
    return original, idle, frames


if __name__ == '__main__':
    OUTPUT.mkdir(exist_ok=True)
    for name in CENTERS:
        _, _, frames = derive(name)
        for phase, frame in frames.items():
            path = OUTPUT / f'{name}-{phase}.jpg'
            frame.save(path, quality=95, subsampling=0, optimize=True)
            print(f'{path.relative_to(ROOT)}: {path.stat().st_size} bytes')
