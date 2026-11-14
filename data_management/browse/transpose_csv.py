"""Flip ANY CSV: rows become columns, columns become rows. Nothing else changes.

Usage (from inside the browse folder):
    python transpose_csv.py <input.csv> <output.csv>

Example:
    python transpose_csv.py raw_planets_0.csv planets_flipped.csv
"""
import csv
import sys
from itertools import zip_longest
from pathlib import Path

HERE = Path(__file__).resolve().parent


def main(src, dst):
    with open(HERE / src, newline="", encoding="utf-8-sig") as f:
        rows = list(csv.reader(f))
    flipped = list(zip_longest(*rows, fillvalue=""))      # <- the transpose
    with open(HERE / dst, "w", newline="", encoding="utf-8") as f:
        csv.writer(f).writerows(flipped)
    print(f"OK: {len(rows)} rows x {max(len(r) for r in rows)} cols  ->  "
          f"{len(flipped)} rows x {len(rows)} cols in {dst}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: python transpose_csv.py <input.csv> <output.csv>")
    main(sys.argv[1], sys.argv[2])