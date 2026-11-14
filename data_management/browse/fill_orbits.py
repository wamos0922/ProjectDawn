"""Fill period_min in orbits.csv from the destinations shelf (Kepler's 3rd law).
Usage (inside browse):  python fill_orbits.py
Needs processed/destinations.json (run make_data.py destinations first).
"""
import csv, json, math
from pathlib import Path

G = 6.674e-11  # m^3 kg^-1 s^-2 (gravitational constant; cite CODATA/NIST in the final sources)
HERE = Path(__file__).resolve().parent

with open(HERE.parent / "processed" / "destinations.json", encoding="utf-8") as f:
    bodies = {b["id"]: b for b in json.load(f)}

with open(HERE / "orbits.csv", encoding="utf-8-sig", newline="") as f:
    reader = csv.DictReader(f)
    cols = reader.fieldnames
    rows = list(reader)

for r in rows:
    b = bodies[r["body"]]
    mu = G * b["mass_1e24_kg"] * 1e24                      # m^3/s^2
    a_m = (b["diameter_km"] / 2 + float(r["altitude_km"])) * 1000
    period_s = 2 * math.pi * math.sqrt(a_m ** 3 / mu)
    r["period_min"] = round(period_s / 60, 1)
    flags = [x for x in r["flags"].split(";") if x]
    if "period_min=DERIVED" not in flags:
        flags.append("period_min=DERIVED")
    r["flags"] = ";".join(flags)
    print(f'{r["id"]}: {r["period_min"]} min')

with open(HERE / "orbits.csv", "w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, fieldnames=cols)
    w.writeheader()
    w.writerows(rows)
print("OK: period_min filled")