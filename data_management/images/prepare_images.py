"""Turn raw NASA downloads into game-ready images with standard frames.

Usage (inside image_pack):   python prepare_images.py
Needs:  pip install pillow
Reads   image_manifest.csv  and  raw/<key>.jpg (or .png/.jpeg)
Writes  img/<key>.png and ozone/<key>.jpg at the frame size in the manifest
  fit=cover   : centre-crop to the frame's shape, then resize (fills the frame)
  fit=contain : resize to fit inside, pad with black (nothing is cut off; use for data maps)
"""
import csv
from pathlib import Path
from PIL import Image, ImageOps

HERE = Path(__file__).resolve().parent

def find_raw(p):
    p = HERE / p
    for ext in (p.suffix, ".jpg", ".jpeg", ".png"):
        q = p.with_suffix(ext)
        if q.exists():
            return q
    return None

done, missing = 0, []
for row in csv.DictReader(open(HERE / "image_manifest.csv", encoding="utf-8")):
    src = find_raw(row["raw_file"])
    if not src:
        missing.append(row["raw_file"]); continue
    w, h = map(int, row["frame"].split("x"))
    im = ImageOps.exif_transpose(Image.open(src)).convert("RGB")
    if row["fit"] == "cover":
        out = ImageOps.fit(im, (w, h), Image.LANCZOS, centering=(0.5, 0.5))
    else:
        im.thumbnail((w, h), Image.LANCZOS)
        out = Image.new("RGB", (w, h), (0, 0, 0))
        out.paste(im, ((w - im.width) // 2, (h - im.height) // 2))
    dst = HERE / row["game_file"]
    dst.parent.mkdir(exist_ok=True)
    out.save(dst, quality=92) if dst.suffix == ".jpg" else out.save(dst)
    done += 1
    print(f"OK  {src.name:<22} -> {row['game_file']}  ({w}x{h}, {row['fit']})")

print(f"\n{done} images ready.")
if missing:
    print("Still missing (download these into raw/):")
    for m in missing: print("  ", m)
