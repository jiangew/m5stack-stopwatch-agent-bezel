"""Validate actual action JPEG payloads, decode, pilot preservation and embedding."""
from pathlib import Path
from io import BytesIO
from hashlib import sha256
import subprocess
import tempfile
import unittest
import numpy as np
from PIL import Image
from robot_home_art_test import payloads

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT/'assets/robot-home/actions'
POSES = [('BumblebeeFullbody',1),('BumblebeeFullbody',2),('Optimus',1),('Optimus',2)]+[(hero,1) for hero in ['Jazz','Hotrod','Wheeljack','Hound','Ironhide','Ratchet']]
HEADER = ROOT/'include/RobotHomeActionArtData.h'

class ActionArtTest(unittest.TestCase):
    def test_shipped_gestures_decode_and_preserve_pilots(self):
        self.assertEqual({p.name for p in ASSETS.glob('*.jpg')}, {f'{h.lower()}-{p}.jpg' for h,p in POSES})
        embedded=payloads(HEADER.read_text())
        self.assertEqual(set(embedded), {f'{h}Pose{p}' for h,p in POSES})
        for hero,pose in POSES:
            with self.subTest(hero=hero,pose=pose):
                raw=(ASSETS/f'{hero.lower()}-{pose}.jpg').read_bytes()
                self.assertEqual(raw,embedded[f'{hero}Pose{pose}'])
                self.assertLess(len(raw),50*1024)
                image=Image.open(BytesIO(raw));image.load()
                self.assertEqual(image.size,(300,300));self.assertFalse(image.info.get('progressive',False))
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

    def test_embedding_is_reproducible(self):
        with tempfile.TemporaryDirectory() as folder:
            dest=Path(folder)/'actions.h'
            command=['ruby',str(ROOT/'scripts/embed_robot_home_action_art.rb'),str(ASSETS),str(dest)]
            subprocess.run(command,check=True,capture_output=True)
            first=dest.read_bytes();self.assertEqual(first,HEADER.read_bytes())
            subprocess.run(command,check=True,capture_output=True)
            self.assertEqual(first,dest.read_bytes())

if __name__=='__main__':unittest.main(verbosity=2)
