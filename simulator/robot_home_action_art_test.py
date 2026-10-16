"""Validate actual action JPEG payloads, decode, pilot preservation and embedding."""
from pathlib import Path
from io import BytesIO
from hashlib import sha256
import json
import subprocess
import shutil
import sys
import tempfile
import unittest
import numpy as np
from PIL import Image
from robot_home_art_test import payloads

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT/'assets/robot-home/actions'
POSES = [('BumblebeeFullbody',1),('BumblebeeFullbody',2),('Optimus',1),('Optimus',2)]+[(hero,1) for hero in ['Jazz','Hotrod','Wheeljack','Hound','Ironhide','Ratchet','Megatron','Starscream','Soundwave','Shockwave','Thundercracker','Skywarp','Blitzwing','Astrotrain']]
HEADER = ROOT/'include/RobotHomeActionArtData.h'
NEW_HEROES = ['Megatron', 'Starscream', 'Soundwave', 'Shockwave', 'Thundercracker', 'Skywarp', 'Blitzwing', 'Astrotrain']
PRESERVED = {'bumblebeefullbody-1.jpg': 'abfbb6c0a22f06ac311f8a8b11222a554e9b621f9aadd4347a21f30d1e951340', 'bumblebeefullbody-2.jpg': '0779f3840382e5adad89b50a312d12c43be86b90da2ac9355729e81634dd2782', 'optimus-1.jpg': 'c65a81955cc586a93b5b33e1fedb24d8ec4663b601432801a40a190b922fbf4f', 'optimus-2.jpg': 'a967fe5492fa7c659525bb20a3820d03f45a7ea221bb5e25b9f26bc8de0bc2e5', 'jazz-1.jpg': '55ad75de174d99d20a240d497d93cefdc9f032d1efed34baa7058266e31e7a7c', 'hotrod-1.jpg': '001b3abfbc03ed2881e8d4f324dacc09adfc8dab2e68c39032a2c6d7d6b0c11b', 'wheeljack-1.jpg': 'ddfbda73dfeeed21a5ad5ba6c6b1fbbef87fdf63e1aee9efd87eb89aa25ac8d3', 'hound-1.jpg': 'ee024c044727cee63b7a947b73a143a1c827923c7f85f73a423d7da403a2ae38', 'ironhide-1.jpg': '0fc35b270e3dd174eef83d0e86a83554bed1fe159642d65841dd28539fe30fa7', 'ratchet-1.jpg': 'c3640de8c0411c9dbf8fcac6388413e22296c50ba090c81bb17ebd973ec24c95'}

class ActionArtTest(unittest.TestCase):
    def test_shipped_gestures_decode_and_preserve_pilots(self):
        self.assertEqual({p.name for p in ASSETS.glob('*.jpg')}, {f'{h.lower()}-{p}.jpg' for h,p in POSES})
        embedded=payloads(HEADER.read_text())
        self.assertEqual(set(embedded), {f'{h}Pose{p}' for h,p in POSES})
        for hero,pose in POSES:
            with self.subTest(hero=hero,pose=pose):
                raw=(ASSETS/f'{hero.lower()}-{pose}.jpg').read_bytes()
                self.assertEqual(raw,embedded[f'{hero}Pose{pose}'])
                if f'{hero.lower()}-{pose}.jpg' in PRESERVED:
                    self.assertEqual(sha256(raw).hexdigest(), PRESERVED[f'{hero.lower()}-{pose}.jpg'])
                self.assertLess(len(raw),50*1024)
                image=Image.open(BytesIO(raw));image.load()
                self.assertEqual(image.size,(300,300));self.assertEqual(image.mode,'RGB');self.assertFalse(image.info.get('progressive',False))
                pixels=np.array(image.convert('RGB'))
                # Outer padding prevents JPEG noise at clipping edges. Original
                # fixed-fit edits may extend arms beyond the old 18px margin.
                edge=np.ones((300,300),dtype=bool);edge[8:-8,8:-8]=False
                self.assertLessEqual(int(pixels[edge].max()),16)
                idle=Image.open(ROOT/f'assets/robot-home/generated/{hero.lower()}-idle.jpg').convert('RGB')
                self.assertGreater(np.abs(pixels.astype(float)-np.array(idle)).mean(),.8)
                if hero in ['BumblebeeFullbody','Optimus']:
                    pilot=ROOT/f'simulator/prototypes/home_tap_motion/poses/{hero.lower()}-{pose}.jpg'
                    self.assertEqual(raw,pilot.read_bytes())

    def test_new_responses_have_stable_head_and_boot_registration(self):
        manifest = json.loads((ASSETS/'manifest.json').read_text())
        records = {item['hero']: item for item in manifest['poses'] if item['hero'] in [h.lower() for h in NEW_HEROES]}
        self.assertEqual(set(records), {h.lower() for h in NEW_HEROES})
        for hero in NEW_HEROES:
            with self.subTest(hero=hero):
                record = records[hero.lower()]
                self.assertEqual(record['idle_transform'], record['response_transform'])
                self.assertEqual(record['idle_transform']['source_size'], [1254,1254])
                idle = np.array(Image.open(ROOT/f'assets/robot-home/generated/{hero.lower()}-idle.jpg').convert('RGB'), dtype=float)
                response_path = ASSETS/f'{hero.lower()}-1.jpg'
                response = np.array(Image.open(response_path).convert('RGB'), dtype=float)
                self.assertEqual(sha256(response_path.read_bytes()).hexdigest(), record['jpeg_sha256'])
                idle_path = ROOT/f'assets/robot-home/generated/{hero.lower()}-idle.jpg'
                self.assertEqual(sha256(idle_path.read_bytes()).hexdigest(), record['idle_jpeg_sha256'])
                self.assertEqual(sha256((ROOT/f'assets/robot-home/{hero.lower()}.png').read_bytes()).hexdigest(), record['idle_fitted_sha256'])
                # The new arm must change actual pixels, not merely JPEG encoding.
                self.assertGreater(np.abs(idle-response).mean(), 2.0)
                # Lower legs and boots stay in the same screen positions. Compare
                # foreground extent and reject any independent pose recenter/zoom.
                for pixels in (idle,response):
                    self.assertGreater((pixels[210:].max(axis=2)>40).sum(), 1000)
                boxes=[]
                for pixels in (idle,response):
                    yy,xx=np.where(pixels[210:].max(axis=2)>40)
                    boxes.append(np.array([xx.min(),yy.min(),xx.max(),yy.max()]))
                self.assertLessEqual(int(np.abs(boxes[0]-boxes[1]).max()), 4)
                self.assertLess(float(np.abs(idle[225:]-response[225:]).mean()), 8.0)
                # Central helmet anchor is unaffected by the arm gesture.
                self.assertLess(float(np.abs(idle[30:75,125:175]-response[30:75,125:175]).mean()), 12.0)

    def test_selected_raw_pairs_reproduce_with_the_same_fixed_transform(self):
        # Raw originals are intentionally ignored. When present, exercise the
        # actual fitting script in an isolated checkout-shaped directory.
        inputs = ROOT/'artifacts/home-factions/imagegen/inputs.json'
        if not inputs.exists():
            self.skipTest('local imagegen originals are intentionally untracked')
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            scripts = root/'scripts'; scripts.mkdir()
            source = root/'assets/robot-home'; (source/'actions').mkdir(parents=True)
            shutil.copy(ROOT/'scripts/prepare_robot_home_art.py', scripts)
            # Existing nine inputs are needed for the unchanged default encoder.
            for name in ['bumblebee.jpg','bumblebeefullbody.png','optimus.png','jazz.png',
                         'hotrod.png','wheeljack.png','hound.png','ironhide.png','ratchet.png']:
                shutil.copy(ROOT/'assets/robot-home'/name, source)
            shutil.copy(ASSETS/'manifest.json', source/'actions')
            command = [sys.executable,str(scripts/'prepare_robot_home_art.py'),
                       '--imagegen-inputs',str(inputs)]
            # Fail closed if even the last selected original changes: no pair
            # is written before all source hashes and geometry are validated.
            invalid = json.loads(inputs.read_text())
            invalid['roles'][-1]['response_sha256'] = '0'*64
            invalid_path = root/'invalid-inputs.json'
            invalid_path.write_text(json.dumps(invalid))
            bad = subprocess.run(command[:-1]+[str(invalid_path)],capture_output=True)
            self.assertNotEqual(bad.returncode,0)
            self.assertIn(b'raw imagegen source hash mismatch',bad.stderr)
            self.assertFalse((source/'megatron.png').exists())
            self.assertEqual((source/'actions/manifest.json').read_bytes(), (ASSETS/'manifest.json').read_bytes())
            subprocess.run(command,check=True,capture_output=True)
            for hero in NEW_HEROES:
                name=hero.lower()
                self.assertEqual((source/f'{name}.png').read_bytes(), (ROOT/f'assets/robot-home/{name}.png').read_bytes())
                self.assertEqual((source/f'actions/{name}-1.jpg').read_bytes(), (ASSETS/f'{name}-1.jpg').read_bytes())
                self.assertEqual((source/f'generated/{name}-idle.jpg').read_bytes(), (ROOT/f'assets/robot-home/generated/{name}-idle.jpg').read_bytes())
            self.assertEqual((source/'actions/manifest.json').read_bytes(), (ASSETS/'manifest.json').read_bytes())
            # An independently recomputed pose fit or arbitrary image would fail
            # the byte comparison even if its self-declared metadata matched.

    def test_embedding_is_reproducible(self):
        with tempfile.TemporaryDirectory() as folder:
            dest=Path(folder)/'actions.h'
            command=['ruby',str(ROOT/'scripts/embed_robot_home_action_art.rb'),str(ASSETS),str(dest)]
            subprocess.run(command,check=True,capture_output=True)
            first=dest.read_bytes();self.assertEqual(first,HEADER.read_bytes())
            subprocess.run(command,check=True,capture_output=True)
            self.assertEqual(first,dest.read_bytes())

if __name__=='__main__':unittest.main(verbosity=2)
