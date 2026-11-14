"""Check every shelf, then write DATA_REPORT.md (honesty meter + sources + problems).
Usage (inside data_management):  python check_data.py
"""
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROC = ROOT / "processed"
LEVELS = ROOT / "levels"

# column of a shelf that must point at an id in another shelf
REFS = {
    ("orbits", "body"): "destinations",
    ("instruments", "mission_id"): "missions",
}
# keys of a level file that must point at ids in a shelf
LEVEL_REFS = {
    "destination": "destinations",
    "orbit": "orbits",
    "reference_missions": "missions",
    "instruments_allowed": "instruments",
    "needs_functions": "functions",
    "platforms_allowed": "platforms",
}

shelves = {p.stem: json.loads(p.read_text(encoding="utf-8")) for p in sorted(PROC.glob("*.json"))}
problems, ids = [], {}

for name, rows in shelves.items():
    seen = set()
    for r in rows:
        if r.get("id") in seen:
            problems.append(f"{name}: duplicate id {r.get('id')}")
        seen.add(r.get("id"))
    ids[name] = seen

for (shelf, col), target in REFS.items():
    for name, rows in shelves.items():
        if not rows:
            problems.append(f"{name}: shelf is empty (is the CSV saved?)")
for (shelf, col), target in REFS.items():
    if shelf in shelves and shelves[shelf] and col not in shelves[shelf][0]:
        problems.append(f"{shelf}: column '{col}' is missing")
    for name, rows in shelves.items():
        for r in rows:
            if r.get("flags") and not r.get("source_url"):
                problems.append(f"{name}/{r['id']}: has flags but no source_url")
    if shelf in shelves and target in ids:
        for r in shelves[shelf]:
            v = r.get(col)
            if v is not None and v not in ids[target]:
                problems.append(f"{shelf}/{r['id']}: {col}={v!r} not found in {target}")

if LEVELS.exists():
    for p in sorted(LEVELS.glob("*.json")):
        text = p.read_text(encoding="utf-8-sig").strip()
        if not text:
            problems.append(f"level {p.name}: file is empty")
            continue
        try:
            level = json.loads(text)
        except json.JSONDecodeError as e:
            problems.append(f"level {p.name}: not valid JSON ({e})")
            continue
        for key, target in LEVEL_REFS.items():
            vals = level.get(key, [])
            vals = vals if isinstance(vals, list) else [vals]
            for v in vals:
                if v not in ids.get(target, set()):
                    problems.append(f"level {p.name}: {key}={v!r} not found in {target}")

report = ["# Data report", "", "## Honesty meter", "",
          "| shelf | rows | REAL | DERIVED | SCALED | PROTOTYPE |", "|---|---|---|---|---|---|"]
sources = {}
for name, rows in shelves.items():
    c = Counter()
    for r in rows:
        for flag in (r.get("flags") or {}).values():
            c[flag] += 1
        for url in str(r.get("source_url") or "").split(";"):
            if url.strip():
                sources.setdefault(url.strip(), r.get("retrieved"))
    report.append(f"| {name} | {len(rows)} | {c['REAL']} | {c['DERIVED']} | {c['SCALED']} | {c['PROTOTYPE']} |")

report += ["", "## Sources (cite these at submission)", ""]
report += [f"- {u} (retrieved {d})" for u, d in sorted(sources.items())]
report += ["", "## Problems", ""] + ([f"- {p}" for p in problems] or ["- none"])

(ROOT / "DATA_REPORT.md").write_text("\n".join(report), encoding="utf-8")
print("\n".join(report))