"""Verify real derived pixels, preservation and eye-only blink changes."""
import importlib.util
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('art', ROOT / 'scripts/prepare_robot_home_art.py')
art = importlib.util.module_from_spec(spec)
spec.loader.exec_module(art)
yy, xx = np.mgrid[:300, :300]
for name, (cx, cy) in art.CENTERS.items():
    original, idle, frames = art.derive(name)
    radius = np.hypot(xx-cx, yy-cy)
    assert np.array_equal(original[radius <= 126], idle[radius <= 126]), name
    assert idle[radius >= 130].max() == 0, name
    closed = np.array(frames['closed'])
    changed = np.max(np.abs(closed.astype(int)-idle.astype(int)), axis=2) > 0
    assert not changed[190:].any(), f'{name}: mouth must not animate'
    assert not changed[:130].any(), f'{name}: forehead must not animate'
    for eye in art.EYES[name]:
        xs, ys = zip(*eye)
        region = np.s_[min(ys):max(ys)+1, min(xs):max(xs)+1]
        before, after = idle[region].astype(int), closed[region].astype(int)
        channel, other = (2, 0) if name in ('bumblebee', 'optimus') else (0, 2)
        # Identify luminous optic cores, excluding tinted surrounding armor.
        optic = (before[:,:,channel] - before[:,:,other] > 80) & (before[:,:,channel] > 180)
        assert optic.sum() > 30, f'{name}: missing eye fixture'
        assert after[:,:,channel][optic].max() < 70, f'{name}: optic not covered'
        assert after[:,:,channel][optic].sum() < before[:,:,channel][optic].sum()*.25
    for phase in frames:
        image = Image.open(art.OUTPUT / f'{name}-{phase}.jpg')
        assert image.size == (300,300)
        decoded = np.array(image)
        assert decoded[radius >= 134].max() < 12, f'{name}: outer rim remains'
    print(f'PASS {name}: inner portrait preserved, baked rim absent, both eyes covered, mouth unchanged')
