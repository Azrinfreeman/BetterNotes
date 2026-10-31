"""Enhance only trailer library-card fills; preserve the original capture and ink."""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent
source = Image.open(root / 'public/screens/library.png').convert('RGB')
pixels = np.array(source).astype(float)
layout = json.loads((root / 'public/screens/layout.json').read_text())
scale = source.width / layout['viewport']['width']
# Existing BetterNotes note palette, in the displayed card order.
colors = ['FFE680', 'FFC7D8', 'FFB88F', 'E6C8F7', 'BCE8D4', 'C9DCEE']
for card, color in zip(layout['library']['cards'], colors):
    x, y, w, h = [round(card[k] * scale) for k in ('x', 'y', 'w', 'h')]
    tile = pixels[y:y+h, x:x+w]
    old = tile[round(20*scale), round(20*scale)].copy()
    new = np.array(tuple(bytes.fromhex(color)), dtype=float)
    # Estimate text coverage against the original flat fill; retain dark ink.
    coverage = np.clip(np.max((old - tile) / np.maximum(old - 28, 1), axis=2), 0, 1)
    mask = Image.new('L', (w, h))
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w-1, h-1), radius=12*scale, fill=255)
    blend = np.array(mask) / 255
    tile += (new - old) * (1 - coverage[..., None]) * blend[..., None]
Image.fromarray(np.uint8(np.clip(np.rint(pixels), 0, 255))).save(root / 'public/screens/library-colorful.png')
print('Created library-colorful.png; original capture preserved.')
