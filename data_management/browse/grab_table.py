"""Grab every table from a static web page and save each one as a raw CSV.

Usage (from inside the browse folder):
    python grab_table.py <page-url> <short_name>

Example:
    python grab_table.py https://nssdc.gsfc.nasa.gov/planetary/factsheet/ planets

Writes  raw_<short_name>.html       (the page exactly as downloaded = proof)
        raw_<short_name>_0.csv, raw_<short_name>_1.csv, ...
Values are kept as TEXT exactly as shown on the page (0.330 stays 0.330).
Powers of ten written as 10<sup>24</sup> become 10^24 instead of 1024.
"""
import collections
import io
import re
import sys
from pathlib import Path

import pandas as pd
import requests

HERE = Path(__file__).resolve().parent


def main(url, name):
    reply = requests.get(
        url,
        headers={"User-Agent": "Mozilla/5.0 (student research script)"},
        timeout=30,
    )
    reply.raise_for_status()
    html = reply.text
    (HERE / f"raw_{name}.html").write_text(html, encoding="utf-8")

    # 10<sup>24</sup> -> 10^24  (otherwise the text reader flattens it to 1024)
    html, fixed = re.subn(r"10\s*<sup[^>]*>\s*([^<]*?)\s*</sup>", r"10^\1", html, flags=re.I)
    if fixed:
        print(f"Fixed {fixed} power(s) of ten, e.g. 10<sup>24</sup> -> 10^24")
    left = len(re.findall(r"<su[pb][ >]", html, flags=re.I))
    if left:
        print(f"CHECK: {left} other superscript/subscript(s) on the page were flattened to plain text. "
              f"Compare units with the real page.")

    try:
        tables = pd.read_html(
            io.StringIO(html),
            converters=collections.defaultdict(lambda: str),   # keep text exactly as shown
        )
    except ValueError:
        sys.exit("No tables found. The page may build its table with JavaScript. "
                 "Use copy-paste instead.")

    print(f"Found {len(tables)} table(s) on the page")
    for i, table in enumerate(tables):
        out = HERE / f"raw_{name}_{i}.csv"
        table.to_csv(out, index=False, encoding="utf-8-sig")
        print(f"\n--- table {i}: {table.shape[0]} rows x {table.shape[1]} columns -> {out.name}")
        print(table.head(5).to_string())


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: python grab_table.py <page-url> <short_name>")
    main(sys.argv[1], sys.argv[2])