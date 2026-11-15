# Image pack for Project Dawn minigames

## Steps
1. Download each picture from its `source_url` in `image_manifest.csv` and save it in `raw/` as the name in `raw_file` (e.g. `raw/sam.jpg`).
2. `pip install pillow`, then `python prepare_images.py`.
3. Copy the new `img/` and `ozone/` folders next to `dawn_minigames_v3.html` (and later into the Godot project's assets).

## Standard frames
| kind | frame | fit | why |
|---|---|---|---|
| instrument photo | 256 x 256 (square) | cover (centre crop) | The games show these in slots of different shapes (40x40 card, 38x28 scanner, 90x70 rocket card), so a square works for all. Keep the instrument in the middle 70%: the edges may be cropped. |
| ozone map | 720 x 510 | contain (no crop, black padding) | It's data, so nothing may be cut off. Matches the NASA Earth Observatory size. |

256 px is plenty: the pixel-art canvas shows a photo at under 60 real pixels.

## How images connect to the data
`instruments.csv` id → `image_manifest.csv` instrument_id → game_file.
Example: `sam_suite` → key `sam` → `img/sam.png`.
The game looks up `img/<key>` by key, so keep the keys exactly as in the manifest.

## Credits
Show the `credit` column on the in-game sources screen (NASA asks for a credit line). LROC and MARCI are flagged `credit=CHECK`: confirm before using.

## `DATA_REPORT_original.md`
This is your DATA_REPORT.md from before Claude overwrote it. Copy it back over `data_management/DATA_REPORT.md` to restore it.
