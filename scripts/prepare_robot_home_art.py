#!/usr/bin/env python3
"""Serialize the four idle portraits as deterministic baseline JPEGs.

Requires Pillow and numpy. Preserve the existing accepted ring-free robot crop;
new hero PNGs are rasterizations of the editable SVG artwork beside them.
No blink frames are produced or embedded.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/robot-home'
OUTPUT = SOURCE / 'generated'
HEROES = ('bumblebee', 'optimus', 'ironman', 'spiderman')
# Keep the accepted radial crop exactly: the original files remain untouched.
CENTERS = {'bumblebee': (150, 148.3), 'optimus': (149.15, 148.3)}


def derive(name):
    if name in CENTERS:
        original = np.array(Image.open(SOURCE / f'{name}.jpg').convert('RGB'))
        if original.shape != (300, 300, 3):
            raise ValueError(f'{name}: original robot artwork must be 300x300')
        yy, xx = np.mgrid[:300, :300]
        cx, cy = CENTERS[name]
        alpha = np.clip((130.0 - np.hypot(xx - cx, yy - cy)) / 4.0, 0, 1)
        return Image.fromarray(np.rint(original * alpha[:, :, None]).astype(np.uint8))
    if name not in HEROES:
        raise ValueError(f'unknown hero: {name}')
    with Image.open(SOURCE / f'{name}.png') as image:
        # New sources are already black-backed; this is build serialization,
        # not an alteration of the authored SVG/PNG portrait.
        return image.convert('RGB').resize((300, 300), Image.Resampling.LANCZOS)


def prepare(output):
    # Validate every input before touching the generated set.
    portraits = {name: derive(name) for name in HEROES}
    output.mkdir(parents=True, exist_ok=True)
    for name, image in portraits.items():
        path = output / f'{name}-idle.jpg'
        image.save(path, quality=95, subsampling=0, optimize=True, progressive=False)
        print(f'{path.name}: {path.stat().st_size} bytes')
    # This directory is wholly generated; obsolete eyelid/retired portraits
    # must not survive regeneration and be mistaken for shipped hero assets.
    expected = {f'{name}-idle.jpg' for name in HEROES}
    for path in output.glob('*.jpg'):
        if path.name not in expected:
            path.unlink()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, default=OUTPUT)
    prepare(parser.parse_args().output_dir)
