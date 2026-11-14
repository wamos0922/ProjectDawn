extends RefCounted
## The three worlds (Earth · Bunker 4, Moon · Shackleton Outpost, Mars · Jezero Base):
## rooms, doors, furniture and stations, loaded from data/worlds.json. Owner: Sufi (gameplay).
## Pure data + geometry, no nodes, so tests can call everything.
##
## A room id is "<world>.<key>", e.g. "moon.mine". Every room is one 320x180 screen in its own
## grid cell; walking through a door moves you to the matching door of the next room.
## Shapes are drawn inside the interior box (centre IB_CENTER, half size IB_HALF) in units u,v from -1 to 1.

const FILE := "res://data/worlds.json"
const WORLDS := ["earth", "moon", "mars"]
const ROOM_SIZE := Vector2(320, 180)
const IB_CENTER := Vector2(160, 102)
const IB_HALF := Vector2(134, 64)
const DOOR_WIDTH := 18.0      ## gap in the wall, pixels
const EXIT_DEPTH := 4.0       ## how far past the wall line counts as "walked through"
const ENTRY_DEPTH := 16.0     ## where you appear inside the next room
const SEAT_RANGE := 16.0      ## how close to a seat counts as "on it"

const PAL := {
	"ink": Color("#181425"), "navy": Color("#262b44"), "slate": Color("#3a4466"), "steel": Color("#5a6988"),
	"grey": Color("#8b9bb4"), "light": Color("#c0cbdc"), "white": Color("#ffffff"), "red": Color("#e43b44"),
	"orange": Color("#f77622"), "amber": Color("#feae34"), "yellow": Color("#fee761"), "green": Color("#63c74d"),
	"dgreen": Color("#3e8948"), "forest": Color("#265c42"), "teal": Color("#193c3e"), "blue": Color("#124e89"),
	"sky": Color("#0099db"), "cyan": Color("#2ce8f5"), "plum": Color("#68386c"), "pink": Color("#b55088"),
	"rose": Color("#f6757a"), "brown": Color("#733e39"), "dbrown": Color("#3e2731"), "sand": Color("#ead4aa"),
	"peach": Color("#e4a672"), "clay": Color("#b86f50"), "rust": Color("#be4a2f"), "burnt": Color("#d77643"),
}
const TONES := {
	"shared": {"f": "steel", "b": "light", "t": "slate"}, "eng": {"f": "rust", "b": "orange", "t": "clay"},
	"sci": {"f": "blue", "b": "sky", "t": "blue"}, "nav": {"f": "plum", "b": "pink", "t": "plum"},
	"qm": {"f": "clay", "b": "amber", "t": "brown"},
}
const VOID := {"earth": Color("#120f1d"), "moon": Color("#0b0c10"), "mars": Color("#2a120c")}

static var _data := {}
static var _rooms := {}
static var _doors := {}
static var _outlines := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(FILE, FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
		for w in WORLDS:
			for k in _data[w]["rooms"]:
				var r: Dictionary = _data[w]["rooms"][k]
				r["w"] = w
				r["k"] = k
				r["id"] = w + "." + k
				r["cell"] = Vector2i(int(r["cell"][0]), int(r["cell"][1]))
				r["map"] = Vector2(r["map"][0], r["map"][1])
				if r.has("poly"):
					var pts := PackedVector2Array()
					for p in r["poly"]:
						pts.append(Vector2(p[0], p[1]))
					r["poly"] = pts
				_rooms[r["id"]] = r
	return _data


static func rooms() -> Dictionary:
	data()
	return _rooms


static func room(id: String) -> Dictionary:
	return rooms().get(id, {})


static func world_of(id: String) -> String:
	return id.get_slice(".", 0)


static func key_of(id: String) -> String:
	return id.get_slice(".", 1)


static func arrive(w: String) -> String:
	return w + "." + data()[w]["arrive"]


# ---------------------------------------------------------------- shapes

static func inside(r: Dictionary, u: float, v: float) -> bool:
	var a := absf(u)
	var b := absf(v)
	match r["shape"]:
		"rect": return a <= 1.0 and b <= 1.0
		"ell": return u * u + v * v <= 1.0
		"oct": return a <= 1.0 and b <= 1.0 and a + b <= 1.45
		"hex": return b <= 1.0 and a <= 1.0 - 0.38 * b
		"trap":
			if b > 1.0:
				return false
			var t := (v + 1.0) / 2.0
			return a <= 1.0 - 0.3 * ((1.0 - t) if r.get("flip", false) else t)
		"poly": return Geometry2D.is_point_in_polygon(Vector2(u, v), r["poly"])
	return false


static func to_norm(local: Vector2) -> Vector2:
	return (local - IB_CENTER) / IB_HALF


static func to_local(u: float, v: float) -> Vector2:
	return IB_CENTER + Vector2(u, v) * IB_HALF


static func inside_local(id: String, local: Vector2) -> bool:
	var n := to_norm(local)
	return inside(room(id), n.x, n.y)


## Distance (pixels) from the room centre to its wall in direction `ang`.
static func wall_distance(id: String, ang: float) -> float:
	var r := room(id)
	var dir := Vector2(cos(ang), sin(ang))
	var lo := 0.0
	var hi := 200.0
	for i in 22:
		var mid := (lo + hi) / 2.0
		var n := to_norm(IB_CENTER + dir * mid)
		if inside(r, n.x, n.y):
			lo = mid
		else:
			hi = mid
	return lo


static func outline(id: String, n := 96) -> PackedVector2Array:
	var key := "%s/%d" % [id, n]
	if _outlines.has(key):
		return _outlines[key]
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(IB_CENTER + Vector2(cos(a), sin(a)) * wall_distance(id, a))
	_outlines[key] = pts
	return pts


static func snap_inside(id: String, p: Vector2, margin := 6.0) -> Vector2:
	var dir := p - IB_CENTER
	var ang := dir.angle()
	var max_d := wall_distance(id, ang) - margin
	if dir.length() > max_d:
		return IB_CENTER + Vector2(cos(ang), sin(ang)) * maxf(0.0, max_d)
	return p


# ---------------------------------------------------------------- doors

static func neighbours(id: String) -> Array:
	var w := world_of(id)
	var k := key_of(id)
	var out := []
	for e in data()[w]["edges"]:
		if e[0] == k:
			out.append(w + "." + e[1])
		elif e[1] == k:
			out.append(w + "." + e[0])
	return out


## Doors of a room: [{to, pos (local px on the wall line), dir (unit, pointing out)}].
static func doors(id: String) -> Array:
	if _doors.has(id):
		return _doors[id]
	var r := room(id)
	var out := []
	for n in neighbours(id):
		var d: Vector2 = (room(n)["map"] - r["map"]).normalized()
		var base := atan2(d.y * IB_HALF.y, d.x * IB_HALF.x)
		for off in [0.0, 0.35, -0.35, 0.7, -0.7, 1.05, -1.05, 1.4, -1.4, 1.75, -1.75]:
			var a: float = base + off
			var pos := IB_CENTER + Vector2(cos(a), sin(a)) * wall_distance(id, a)
			var free := true
			for o in out:
				if o["pos"].distance_to(pos) < 30.0:
					free = false
			if free:
				out.append({"to": n, "pos": pos, "dir": Vector2(cos(a), sin(a))})
				break
	_doors[id] = out
	return out


static func door_to(id: String, to: String) -> Dictionary:
	for d in doors(id):
		if d["to"] == to:
			return d
	return {}


static func entry_point(id: String, from: String) -> Vector2:
	var d := door_to(id, from)
	if d.is_empty():
		return IB_CENTER
	return d["pos"] - d["dir"] * ENTRY_DEPTH


## Next room on the shortest open path ("" when unreachable). locked: id -> true.
static func next_hop(from: String, to: String, locked: Dictionary = {}) -> String:
	if from == to:
		return to
	var prev := {from: ""}
	var q := [from]
	while not q.is_empty():
		var cur: String = q.pop_front()
		if cur == to:
			break
		for n in neighbours(cur):
			if not prev.has(n) and not locked.get(n, false):
				prev[n] = cur
				q.append(n)
	if not prev.has(to):
		return ""
	var step := to
	while prev[step] != from:
		step = prev[step]
	return step


# ---------------------------------------------------------------- stations and grid

## Stations of a room: "main" console, extra ones from worlds.json (role seats, locker...) and posters.
static func stations(id: String, posters: Array) -> Array:
	var w := world_of(id)
	var k := key_of(id)
	var list := []
	var extra: Array = data()[w]["stations"].get(k, [])
	var has_main := false
	for s in extra:
		has_main = has_main or s["id"] == "main"
	if not has_main:
		list.append({"id": "main", "u": 0.0, "v": -0.25})
	for s in extra:
		list.append(s.duplicate())
	var mine := posters.filter(func(p): return p["world"] == w and p["room"] == k)
	for i in mine.size():
		list.append({"id": "poster%d" % i, "u": 0.55 if i == 0 else -0.55, "v": -1.0, "poster": mine[i]})
	for s in list:
		s["pos"] = snap_inside(id, to_local(float(s["u"]), float(s["v"])), 10.0)
	return list


static func room_origin(id: String) -> Vector2:
	return Vector2(room(id)["cell"]) * ROOM_SIZE


static func room_at(world_pos: Vector2) -> String:
	var cell := Vector2i(floori(world_pos.x / ROOM_SIZE.x), floori(world_pos.y / ROOM_SIZE.y))
	for id in rooms():
		if _rooms[id]["cell"] == cell:
			return id
	return ""


## Game clock text: minutes since the start of DAY 1 -> "DAY 3 · 06:05".
static func clock_text(minutes: float) -> String:
	var m := int(minutes)
	return "DAY %d · %02d:%02d" % [m / 1440 + 1, (m % 1440) / 60, m % 60]
