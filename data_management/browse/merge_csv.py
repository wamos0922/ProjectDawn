"""Add the new columns of an extra CSV to a master CSV, matching rows by id.
Usage (inside browse):  python merge_csv.py destinations.csv extra_destinations_delay.csv
The extra CSV needs: id, the new columns, and (optional) source_url, flags.
A backup of the master is saved as <master>.bak
"""
import csv, shutil, sys


def read(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        return reader.fieldnames, list(reader)


def join(a, b):
    parts = [x for x in (a or "").split(";") if x]
    for x in (b or "").split(";"):
        if x and x not in parts:
            parts.append(x)
    return ";".join(parts)


def main(master, extra):
    mcols, mrows = read(master)
    ecols, erows = read(extra)
    lookup = {r["id"]: r for r in erows}

    new = [c for c in ecols if c not in mcols]
    skipped = [c for c in ecols if c in mcols and c not in ("id", "source_url", "flags", "retrieved", "notes")]
    if skipped:
        print("SKIPPED (already in master, not overwritten):", skipped)

    at = mcols.index("source_url") if "source_url" in mcols else len(mcols)
    cols = mcols[:at] + new + mcols[at:]

    for r in mrows:
        e = lookup.get(r["id"])
        for c in new:
            r[c] = e[c] if e else ""
        if e:
            r["source_url"] = join(r.get("source_url"), e.get("source_url"))
            r["flags"] = join(r.get("flags"), e.get("flags"))

    for i in lookup:
        if i not in {r["id"] for r in mrows}:
            print("WARNING: id in extra but not in master:", i)

    shutil.copy(master, master + ".bak")
    with open(master, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(mrows)
    print(f"OK: added {new} to {master}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: python merge_csv.py master.csv extra.csv")
    main(sys.argv[1], sys.argv[2])