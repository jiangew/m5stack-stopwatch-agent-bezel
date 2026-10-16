"""Catch aliasing when the real art fitter reduces fine source detail."""
from hashlib import sha256
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]


class ResamplingTest(unittest.TestCase):
    def test_subpixel_checker_detail_averages_instead_of_creating_moire(self):
        # A 2px checker is above Nyquist after this ~4x reduction. Its interior
        # should average to 127.5, rather than create false high-contrast detail.
        # Removing the downsampling low-pass filter must fail this assertion.
        spec = importlib.util.spec_from_file_location(
            'prepare_art', ROOT/'scripts/prepare_robot_home_art.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root/'assets/robot-home'
            (source/'actions').mkdir(parents=True)
            (source/'actions/manifest.json').write_text('{"poses": []}')
            yy, xx = np.mgrid[:1254, :1254]
            checker = (((xx//2 + yy//2) % 2) * 255).astype(np.uint8)
            pixels = np.zeros((1254, 1254, 3), dtype=np.uint8)
            pixels[100:1154, 200:1054] = checker[100:1154, 200:1054, None]
            original = root/'checker.png'
            Image.fromarray(pixels).save(original)
            digest = sha256(original.read_bytes()).hexdigest()
            roles = [dict(name=name, idle_local_source=str(original),
                          response_local_source=str(original),
                          idle_sha256=digest, response_sha256=digest)
                     for name in module.DECEPTICONS]
            inputs = root/'inputs.json'
            inputs.write_text(json.dumps({'roles': roles}))
            module.SOURCE = source
            module.fit_imagegen(inputs)
            fitted = np.array(Image.open(source/'megatron.png'), dtype=float)
            interior = fitted[90:210, 90:210]
            self.assertLess(abs(float(interior.mean()) - 127.5), 1.0)
            self.assertLess(float(interior.std()), 2.0,
                            'fine source detail aliases into visible moire')


if __name__ == '__main__':
    unittest.main(verbosity=2)
