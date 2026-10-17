"""Load from the checkout via an opt-in Hermes plugin symlink; do not copy in isolation."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from notifications.adapters.hermes_plugin import register
