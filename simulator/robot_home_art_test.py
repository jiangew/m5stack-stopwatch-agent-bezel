"""Decode the shipped seven-hero JPEGs and verify reproducible embedding.

Run with a Python environment providing Pillow and numpy. Identity is checked
by distinct pixels/palette and exact name-to-header payloads; the generation
record and human thumbnail inspection verify the depicted characters.
"""
from hashlib import sha256
from io import BytesIO
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/robot-home/generated'
HEROES = ('Bumblebee', 'BumblebeeFullbody', 'Optimus', 'Jazz', 'Hotrod', 'Wheeljack', 'Hound')
HEADER = ROOT / 'include/RobotHomeArtData.h'


def payloads(text):
    return {
        name: bytes(int(byte, 16) for byte in re.findall(r'0x([0-9a-fA-F]{2})', body))
        for name, body in re.findall(
            r'k(\w+)Jpg\[\][^=]*=\s*\{(.*?)\};', text, re.S)
    }


class HeroArtTest(unittest.TestCase):
    def test_exactly_seven_idle_assets_are_embedded(self):
        embedded = payloads(HEADER.read_text())
        self.assertEqual(set(embedded), set(HEROES))
        for name in HEROES:
            with self.subTest(hero=name):
                shipped = (ASSETS / f'{name.lower()}-idle.jpg').read_bytes()
                self.assertEqual(embedded[name], shipped)
                self.assertIn(f'k{name}JpgSize = sizeof(k{name}Jpg)', HEADER.read_text())
                # Decode bytes from the actual header, not a surrogate source.
                image = Image.open(BytesIO(embedded[name]))
                image.load()
                self.assertEqual(image.format, 'JPEG')
                self.assertEqual(image.size, (300, 300))
                self.assertFalse(image.info.get('progressive', False))

    def test_real_jpegs_have_black_margins_and_distinct_identity(self):
        fingerprints, decoded = [], []
        for name in HEROES:
            with self.subTest(hero=name):
                data = (ASSETS / f'{name.lower()}-idle.jpg').read_bytes()
                self.assertLess(len(data), 50 * 1024)
                image = Image.open(BytesIO(data))
                image.load()
                self.assertEqual(image.size, (300, 300))
                pixels = np.array(image.convert('RGB'))
                # 18px black edge survives 1.18x portrait animation; JPEG
                # ringing permits at most 12/255 at the margin's inner edge.
                edge = np.ones((300, 300), dtype=bool)
                edge[18:-18, 18:-18] = False
                self.assertLessEqual(int(pixels[edge].max()), 12, name)
                self.assertGreater(int((pixels.max(axis=2) > 70).sum()), 6000, name)
                fingerprints.append(sha256(data).hexdigest())
                decoded.append(pixels.astype(float))
        self.assertEqual(len(set(fingerprints)), 7, 'heroes must not alias one JPEG')
        for index, first in enumerate(decoded):
            for second in decoded[index + 1:]:
                # Compare decoded artwork, so a re-encoded duplicate cannot
                # pass merely because its JPEG bytes differ.
                self.assertFalse(np.array_equal(first, second),
                                 f'{HEROES[index]} and another hero share artwork')

    def test_preserved_robot_portrait_pixels(self):
        # Preserve the accepted ring-free crop, not the removed rim or blink.
        name, center = 'bumblebee', (150, 148.3)
        data = (ASSETS / f'{name}-idle.jpg').read_bytes()
        self.assertEqual(sha256(data).hexdigest(),
                         'f1bb7e24fe30631b15e1999c35a0b8d4024d3fc52b222aa0ad6c5d6676a9d191')
        original = np.array(Image.open(ROOT / f'assets/robot-home/{name}.jpg').convert('RGB'))
        shipped = np.array(Image.open(BytesIO(data)).convert('RGB'))
        yy, xx = np.mgrid[:300, :300]
        inner = np.hypot(xx - center[0], yy - center[1]) <= 124
        error = np.abs(original.astype(float) - shipped.astype(float))[inner]
        self.assertLess(float(error.mean()), 3, name)
        self.assertLess(float(np.quantile(error, .99)), 12, name)

    def test_preparation_and_embedding_are_deterministic(self):
        with tempfile.TemporaryDirectory() as temporary:
            out = Path(temporary) / 'assets'
            command = [sys.executable, str(ROOT / 'scripts/prepare_robot_home_art.py'),
                       '--output-dir', str(out)]
            subprocess.run(command, check=True, capture_output=True)
            first = {p.name: p.read_bytes() for p in out.glob('*.jpg')}
            self.assertEqual(set(first), {f'{name.lower()}-idle.jpg' for name in HEROES})
            subprocess.run(command, check=True, capture_output=True)
            self.assertEqual(first, {p.name: p.read_bytes() for p in out.glob('*.jpg')})
            for name, data in first.items():
                self.assertEqual(data, (ASSETS / name).read_bytes(), name)
            header = Path(temporary) / 'RobotHomeArtData.h'
            embed = ['ruby', str(ROOT / 'scripts/embed_robot_home_art.rb'), str(out), str(header)]
            subprocess.run(embed, check=True, capture_output=True)
            first_header = header.read_bytes()
            subprocess.run(embed, check=True, capture_output=True)
            self.assertEqual(first_header, header.read_bytes())
            self.assertEqual(first_header, HEADER.read_bytes())


if __name__ == '__main__':
    unittest.main(verbosity=2)
