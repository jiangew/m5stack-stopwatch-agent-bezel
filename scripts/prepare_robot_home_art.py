#!/usr/bin/env python3
"""Serialize the seventeen idle portraits as deterministic baseline JPEGs.

Requires Pillow and numpy. Preserve the existing accepted ring-free Bumblebee crop;
the sixteen full-body sources are fitted, black-backed 300px PNGs.
No blink frames are produced or embedded.
"""
import argparse
from hashlib import sha256
from io import BytesIO
import json
from math import ceil
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/robot-home'
OUTPUT = SOURCE / 'generated'
HEROES = ('bumblebee', 'bumblebeefullbody', 'optimus', 'jazz', 'hotrod', 'wheeljack', 'hound', 'ironhide', 'ratchet', 'megatron', 'starscream', 'soundwave', 'shockwave', 'thundercracker', 'skywarp', 'blitzwing', 'astrotrain')
DECEPTICONS = HEROES[9:]
# Keep the accepted radial crop exactly: the original files remain untouched.
CENTERS = {'bumblebee': (150, 148.3)}


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
        # Fitted sources are already 300px and black-backed. Do not transform
        # the accepted source pixels during build serialization.
        if image.size != (300, 300):
            raise ValueError(f'{name}: fitted artwork must be 300x300')
        return image.convert('RGB')


def fit_imagegen(inputs_path):
    """Fit selected imagegen pairs with ONE uniform transform derived from idle.

    Raw inputs and their local paths remain ignored. The tracked manifest keeps
    only source hashes, prompts, and numeric transforms; no service/API needed.
    Whole-canvas affine sampling retains gestures outside the idle's own box.
    """
    inputs = json.loads(inputs_path.read_text())
    roles = inputs['roles']
    if [role['name'] for role in roles] != list(DECEPTICONS):
        raise ValueError('imagegen inputs must contain the eight Decepticons in roster order')
    prepared = []
    for role in roles:
        name = role['name']
        originals = []
        for path_key, hash_key in [('idle_local_source', 'idle_sha256'),
                                   ('response_local_source', 'response_sha256')]:
            path = Path(role[path_key])
            if sha256(path.read_bytes()).hexdigest() != role[hash_key]:
                raise ValueError(f'{name}: raw imagegen source hash mismatch')
            with Image.open(path) as image:
                originals.append(image.convert('RGB'))
        idle, response = originals
        if idle.size != response.size:
            raise ValueError(f'{name}: response must use the original idle canvas')
        yy, xx = np.where(np.array(idle).max(axis=2) > 12)
        if len(xx) == 0:
            raise ValueError(f'{name}: idle has no visible artwork')
        left, top, right, bottom = (int(xx.min()), int(yy.min()),
                                   int(xx.max()) + 1, int(yy.max()) + 1)
        width, height = right-left, bottom-top
        scale = min(246/width, 252/height)
        paste = ((300-width*scale)/2, (300-height*scale)/2)
        affine = (1/scale, 0, left-paste[0]/scale,
                  0, 1/scale, top-paste[1]/scale)
        transform = {'source_size': list(idle.size),
                     'idle_bbox': [left, top, right, bottom],
                     'scale': scale, 'paste_xy': list(paste),
                     'affine_output_to_source': list(affine),
                     'resampling': 'LANCZOS antialiased box resize', 'canvas_size': [300, 300],
                     'black_canvas_aperture': [24, 24, 276, 276]}
        # transform(BICUBIC) samples a fixed-size kernel even for ~4.5x
        # reductions, aliasing fine lines into jagged detail. resize() widens
        # its low-pass kernel for downsampling. The source box expresses the
        # SAME inverse affine geometry; black padding permits out-of-canvas
        # coordinates without cropping/recentering either response frame.
        x0, y0 = affine[2], affine[5]
        x1, y1 = x0 + 300/scale, y0 + 300/scale
        padding = ceil(max(0, -x0, -y0, x1-idle.width, y1-idle.height))
        source_box = (x0+padding, y0+padding, x1+padding, y1+padding)
        fitted = [ImageOps.expand(image, border=padding, fill=(0,0,0)).resize(
                      (300,300), resample=Image.Resampling.LANCZOS, box=source_box)
                  for image in originals]
        # Composite onto a pure black safety canvas. Only near-black outer
        # source background is outside this aperture; the complete figures and
        # gestures remain inside. Use the same aperture for both paired frames.
        for index, image in enumerate(fitted):
            pixels = np.array(image)
            outside = np.ones((300,300), dtype=bool)
            outside[24:276,24:276] = False
            if int(pixels[outside].max()) > 24:
                raise ValueError(f'{name}: visible artwork would be clipped by safety canvas')
            canvas = Image.new('RGB', (300,300), (0,0,0))
            canvas.paste(image.crop((24,24,276,276)), (24,24))
            fitted[index] = canvas
        record = {'hero': name, 'pose': 1,
                  'source_sha256': role['response_sha256'],
                  'idle_source_sha256': role['idle_sha256'],
                  'idle_transform': transform, 'response_transform': transform,
                  'jpeg_encoder': {'quality': 93, 'subsampling': 0, 'optimize': True, 'progressive': False},
                  'fit': 'Fixed idle transform; wholecanvas sampling, no independent pose fit'}
        # Prompt fields are copied explicitly, never arbitrary input metadata.
        for key in ('idle_prompt', 'pose_prompt', 'proportion_edit_prompt', 'face_edit_prompt'):
            if key in role:
                if '/Users/' in role[key] or '/private/' in role[key]:
                    raise ValueError(f'{name}: prompt contains a personal path')
                record[key] = role[key]
        prepared.append((name, fitted, record))
    manifest_path = SOURCE/'actions/manifest.json'
    manifest = json.loads(manifest_path.read_text())
    manifest['poses'] = [item for item in manifest['poses'] if item['hero'] not in DECEPTICONS]
    # Validate all pairs before writing any production inputs.
    for name, (idle, response), record in prepared:
        png = SOURCE/f'{name}.png'
        idle.save(png)
        jpeg = SOURCE/f'actions/{name}-1.jpg'
        response.save(jpeg, quality=93, subsampling=0, optimize=True, progressive=False)
        idle_jpeg = BytesIO()
        idle.save(idle_jpeg, format='JPEG', quality=93, subsampling=0, optimize=True, progressive=False)
        record['idle_jpeg_sha256'] = sha256(idle_jpeg.getvalue()).hexdigest()
        record['idle_fitted_sha256'] = sha256(png.read_bytes()).hexdigest()
        record['jpeg_sha256'] = sha256(jpeg.read_bytes()).hexdigest()
        manifest['poses'].append(record)
    manifest_path.write_text(json.dumps(manifest, indent=2)+'\n')


def prepare(output):
    # Validate every input before touching the generated set.
    portraits = {name: derive(name) for name in HEROES}
    output.mkdir(parents=True, exist_ok=True)
    for name, image in portraits.items():
        path = output / f'{name}-idle.jpg'
        image.save(path, quality=93 if name in DECEPTICONS else 95, subsampling=0, optimize=True, progressive=False)
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
    parser.add_argument('--imagegen-inputs', type=Path,
                        help='optional ignored selected imagegen pairs; fit production inputs first')
    args = parser.parse_args()
    if args.imagegen_inputs:
        fit_imagegen(args.imagegen_inputs)
    prepare(args.output_dir)
