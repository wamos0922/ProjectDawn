"""Flip the NASA planet table and clean it into a proper shelf CSV.
Usage (inside browse):  python transpose_table.py raw_planets_0.csv destinations
Reads  raw_planets_0.csv   Writes  <name>.csv  (id, name, clean column names, source info, flags)
"""
import csv, sys, datetime

SOURCE_URL = "https://nssdc.gsfc.nasa.gov/planetary/factsheet/"

# label in the NASA table (start of the text)  ->  short column name
NAMES = {
    "Mass": "mass_1e24_kg",
    "Diameter": "diameter_km",
    "Density": "density_kg_m3",
    "Gravity": "gravity_m_s2",
    "Escape Velocity": "escape_velocity_km_s",
    "Rotation Period": "rotation_period_h",
    "Length of Day": "day_length_h",
    "Distance from Sun": "distance_from_sun_1e6_km",
    "Perihelion": "perihelion_1e6_km",
    "Aphelion": "aphelion_1e6_km",
    "Orbital Period": "orbital_period_days",
    "Orbital Velocity": "orbital_velocity_km_s",
    "Orbital Inclination": "orbital_inclination_deg",
    "Orbital Eccentricity": "orbital_eccentricity",
    "Obliquity": "obliquity_deg",
    "Mean Temperature": "mean_temp_c",
    "Surface Pressure": "surface_pressure_bar",
    "Number of Moons": "moons",
    "Ring System": "has_rings",
    "Global Magnetic Field": "has_magnetic_field",
}


def clean(text):
    text = text.replace("*", "").strip()
    return "" if text.lower() == "unknown" else text


def short_name(label):
    for start, short in NAMES.items():
        if label.strip().lower().startswith(start.lower()):
            return short
    return None


def main(infile, name):
    with open(infile, encoding="utf-8-sig", newline="") as f:
        rows = list(csv.reader(f))

    # the row with an EMPTY first cell holds the planet names
    top = next(i for i, r in enumerate(rows)
               if r and r[0].strip() == "" and any(c.strip() for c in r[1:]))
    planets = rows[top][1:]
    body = rows[top + 1:]

    columns = list(NAMES.values())
    header = ["id", "name"] + columns + ["source_url", "retrieved", "flags", "notes"]
    today = datetime.date.today().isoformat()

    out = []
    for j, planet in enumerate(planets, start=1):
        planet = planet.strip()
        if not planet:
            continue
        values = {c: "" for c in columns}
        for r in body:
            if not r or not r[0].strip():
                continue
            col = short_name(r[0])
            if col and j < len(r):
                values[col] = clean(r[j])
        note = ""
        if planet.upper() == "MOON":
            note = "orbital values are relative to Earth"
        out.append([planet.lower(), planet.title()]
                   + [values[c] for c in columns]
                   + [SOURCE_URL, today, "facts=REAL", note])

    with open(name + ".csv", "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(out)
    print(f"OK: {len(out)} rows -> {name}.csv")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: python transpose_table.py raw_planets_0.csv destinations")
    main(sys.argv[1], sys.argv[2])