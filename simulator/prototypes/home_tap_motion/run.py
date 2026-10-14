#!/usr/bin/env python3
"""THROWAWAY: render two Home motion pilots and a standalone click preview.

Run with a Python environment containing Pillow and numpy. Requires the existing
native-preview M5GFX library, clang++, and Homebrew SDL2; installs nothing.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output-dir', type=Path, default=ROOT/'outputs/home-tap-motion-pilot')
args = parser.parse_args()
out = args.output_dir.resolve()
library = ROOT/'.pio/build/native-preview/lib02f/libM5GFX.a'
if not library.is_file():
    sys.exit('Build the existing native-preview environment first: pio run -e native-preview')
for name in ['frames','fitted']:
    (out/name).mkdir(parents=True,exist_ok=True)
for hero in ['bumblebeefullbody','optimus']:
    shutil.copy2(ROOT/f'assets/robot-home/generated/{hero}-idle.jpg',out/f'fitted/{hero}-0.jpg')
    for pose in [1,2]:
        shutil.copy2(HERE/f'poses/{hero}-{pose}.jpg',out/f'fitted/{hero}-{pose}.jpg')
brew = Path(os.environ.get('HOMEBREW_PREFIX','/opt/homebrew'))
subprocess.run(['clang++','-std=c++17','-Wno-vla-cxx-extension',
                f'-I{ROOT}/include',f'-I{ROOT}/.pio/libdeps/m5stack-stopwatch/M5GFX/src',
                f'-I{brew}/include/SDL2',str(HERE/'motion_prototype.cpp'),str(library),
                f'-L{brew}/lib','-lSDL2','-o',str(out/'motion-prototype')],check=True)
subprocess.run([str(out/'motion-prototype'),str(out)],check=True)
subprocess.run([sys.executable,str(HERE/'package_preview.py'),str(out)],check=True)
print(f'Open {out / "index.html"}, or serve this output directory on localhost.')
