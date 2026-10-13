"""Decode the shipped nine-portrait JPEGs and verify reproducible embedding.

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
HEROES = ('Bumblebee', 'BumblebeeFullbody', 'Optimus', 'Jazz', 'Hotrod', 'Wheeljack', 'Hound', 'Ironhide', 'Ratchet')
PRESERVED = {
    'bumblebee': 'f1bb7e24fe30631b15e1999c35a0b8d4024d3fc52b222aa0ad6c5d6676a9d191',
    'bumblebeefullbody': '6a8b98ad78c0b872d121fba3c785a65db655bd8c461014b3b96888e9427e06a6',
    'optimus': '81baea5cfdf87850c56756b53f920e1e8e1ffac084b37bed8c6db375cbb149d7',
    'jazz': '85603f6a2b668aa796b6c4173d020c92cd7f675eb2dbe13f5c8f6e8eb9e6fe08',
    'hotrod': '46a4a235e29b49420ff0dc1c22474a3efaf92176608f3822bcd8160e2b4934bf',
    'wheeljack': '5633b4a2f7353838b4b363e7fc835a11bc6b09fbae7e16d53b9c9672e44e35e9',
    'hound': '6dafdb61e4e349cb99cbb61919106f2d4e092d3bfd398412ae03cc71a559862c',
}
HEADER = ROOT / 'include/RobotHomeArtData.h'


def payloads(text):
    return {
        name: bytes(int(byte, 16) for byte in re.findall(r'0x([0-9a-fA-F]{2})', body))
        for name, body in re.findall(
            r'k(\w+)Jpg\[\][^=]*=\s*\{(.*?)\};', text, re.S)
    }


def visually_distinct(first, second):
    # Downsample to suppress JPEG blocks and compare only the union of the
    # visible figures, so shared black margins cannot dominate the result.
    thumbs = [np.array(Image.fromarray(pixels).resize((48, 48), Image.Resampling.BILINEAR),
                      dtype=np.int16) for pixels in (first, second)]
    foreground = np.maximum(thumbs[0].max(axis=2), thumbs[1].max(axis=2)) > 24
    if not foreground.any():
        return False
    close = np.max(np.abs(thumbs[0] - thumbs[1]), axis=2) <= 12
    # Calibration on all seven shipped figures: their largest close fraction
    # is 0.045 (Jazz/Wheeljack); quality-20 re-encodes are at least 0.743.
    return float(close[foreground].mean()) < 0.5


class HeroArtTest(unittest.TestCase):
    def test_exactly_nine_idle_assets_are_embedded(self):
        embedded = payloads(HEADER.read_text())
        self.assertEqual(set(embedded), set(HEROES))
        for name in HEROES:
            with self.subTest(hero=name):
                shipped = (ASSETS / f'{name.lower()}-idle.jpg').read_bytes()
                if name.lower() in PRESERVED:
                    self.assertEqual(sha256(shipped).hexdigest(), PRESERVED[name.lower()])
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
                decoded.append(pixels)
        self.assertEqual(len(set(fingerprints)), 9, 'heroes must not alias one JPEG')
        for index, first in enumerate(decoded):
            for second in decoded[index + 1:]:
                self.assertTrue(visually_distinct(first, second),
                                f'{HEROES[index]} and another hero share artwork')

    def test_reencoded_artwork_is_not_a_distinct_identity(self):
        # A duplicate drawing can have a different JPEG digest and decoded
        # pixels; run it through the same check used for the shipped roster.
        for name in HEROES:
            with self.subTest(hero=name):
                original_data = (ASSETS / f'{name.lower()}-idle.jpg').read_bytes()
                original = Image.open(BytesIO(original_data)).convert('RGB')
                output = BytesIO()
                original.save(output, format='JPEG', quality=20, subsampling=2)
                self.assertNotEqual(sha256(original_data).digest(), sha256(output.getvalue()).digest())
                reencoded = np.array(Image.open(BytesIO(output.getvalue())).convert('RGB'))
                pixels = np.array(original)
                self.assertFalse(np.array_equal(pixels, reencoded))
                self.assertFalse(visually_distinct(pixels, reencoded), name)

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
