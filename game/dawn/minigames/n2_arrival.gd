extends "res://game/dawn/minigames/mini_game.gd"
## ACT 2 · NAVIGATOR · Moon arrival burn. The ship swings around the Moon: FIRE once at the closest
## point (dashed ring). Too early = crash, too late = fly past. Moon Landing Pad, right after touchdown
## (the flight log is replayed before check-in).
## Real: the path is a NASA GMAT run (Moon gravity only, 100 km closest approach), lunar_gmat.json,
## one [x, y] km point per minute. Game: score bands ±2 / ±6 / ±15 minutes.

const DATA := "res://game/dawn/minigames/lunar_gmat.json"
const S := 0.0165                 # km -> screen
const C := Vector2(372, 186)      # Moon centre on screen
const MOON_R := 1737.4

static var _path: Array = []

var r: Array = []
var v: Array = []
var peri := 0
var i := 0.0
var fired = null                  # timing error in seconds once fired
var t0 := 0.0
var entry := 0


func _init() -> void:
	title = "MOON ARRIVAL BURN"
	goal = "The ship swings around the Moon. Press FIRE (or SPACE) once, right at the closest point (the dashed ring). Too early = crash, too late = fly past. The film slows down near the Moon so you can time it."


func setup() -> void:
	if _path.is_empty():
		_path = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var n := _path.size()
	r = []
	v = []
	for k_ in n:
		r.append(Vector2(_path[k_][0], _path[k_][1]).length())
		var a: Array = _path[mini(n - 1, k_ + 1)]
		var b: Array = _path[maxi(0, k_ - 1)]
		v.append(Vector2(a[0] - b[0], a[1] - b[1]).length() / (60.0 * (1 if k_ == 0 or k_ == n - 1 else 2)))
	peri = r.find(r.min())
	i = 0.0
	fired = null
	entry = 0
	for k_ in n:
		var s := _scr(_path[k_])
		if s.x > 0 and s.y < H:
			entry = k_
			break
	add_button("FIRE", func(_b): fire())
	say("Watch the ship speed up near the Moon. Fire at the ring.")


func _scr(p: Array) -> Vector2:
	return Vector2(C.x + p[0] * S, C.y - p[1] * S)


func key(kc: int, down: bool) -> bool:
	if kc == KEY_SPACE:
		if down:
			fire()
		return true
	return false


func fire() -> void:
	if fired != null:
		return
	var err := (int(i) - peri) * 60.0
	var a := absf(err)
	fired = err
	t0 = t
	if a <= 900:
		finish(3 if a <= 120 else (2 if a <= 360 else 1),
			"Captured with a timing error of %d s. At the closest point the ship is fastest (about %.1f km/s here), so a burn there changes the orbit most for the least fuel." % [roundi(err), v[peri]],
			"LRO braked into lunar orbit near its closest approach in 2009. Trajectory from NASA GMAT.")
	elif err < 0:
		say("Too early! The burn bent our path into the surface.", "bad")
	else:
		say("Too late! The Moon flung us past.", "bad")


func tick(dt: float) -> void:
	var n := _path.size()
	if fired == null:
		var rr: float = r[int(i)]
		i += dt * (4 + maxf(0.0, rr - 3000) * 0.015)
		if i >= n - 1:
			i = 0.0
			say("Missed the whole swing. Try again: watch for the ring.", "bad")
	elif t - t0 > 1.3:
		if fired < 0:
			finish(0, "Fired too early: the ship was still diving toward the Moon, and the burn dropped the path into the surface.", "Real lunar orbit insertion burns are timed to the closest point.")
		else:
			finish(0, "Fired too late: the ship had already swung past the closest point, and the Moon's gravity flung it away.", "Real lunar orbit insertion burns are timed to the closest point.")


func paint() -> void:
	sky()
	if _path.is_empty():
		return
	var mr := MOON_R * S
	moon(C.x, C.y, mr)
	T("Moon", C.x, C.y + mr + 6, P["lg"], 1, 12)
	var kk := int(i)
	var pts := []
	for p in _path:
		var s := _scr(p)
		pts.append([s.x, s.y])
	poly(pts.slice(0, kk + 1), Color("#4b6cb7"), 2)
	for j in range(kk, pts.size() - 1, 2):
		line(pts[j][0], pts[j][1], pts[j + 1][0], pts[j + 1][1], P["sl"], 1.4)
	var pq := Vector2(pts[peri][0], pts[peri][1])
	ring(pq.x, pq.y, 11, P["b"], -1, 1.5, true)
	T("closest point (100 km above surface)", pq.x + 16, pq.y - 6, P["b"], 0, 11)
	var en: Array = pts[maxi(0, entry)]
	T("from Earth (384,400 km away, off screen)", maxf(8, en[0] + 10), H - 26, P["gy"], 0, 11)
	var s := Vector2(pts[kk][0], pts[kk][1])
	var nx := Vector2(pts[mini(pts.size() - 1, kk + 1)][0], pts[mini(pts.size() - 1, kk + 1)][1])
	var ang := (nx - s).angle()
	if fired != null:
		var a := absf(fired)
		var tt := (t - t0) + ((Time.get_ticks_msec() / 1000.0 - _over_at) if over else 0.0)
		if a <= 900:
			var rr := pq.distance_to(C) * (1 + a / 900 * 0.8)
			var th := tt * 1.6 + (pq - C).angle()
			s = Vector2(C.x + rr * cos(th), C.y + rr * 0.82 * sin(th))
			ang = th + PI / 2
			ring(C.x, C.y, rr, P["g"], rr * 0.82, 1.6, true)
		elif fired < 0:
			var f := minf(1.0, tt)
			s = s.lerp(C, f)
			if f >= 1:
				disc(s.x, s.y, 9, P["or"])
		else:
			s += Vector2(tt * 120, -tt * 40)
		if tt < 0.5:
			disc(s.x, s.y, 9, Color(P["o"], 0.7))
	var fw := Vector2.from_angle(ang)
	var sd := fw.orthogonal()
	fill_poly([[s.x + fw.x * 9, s.y + fw.y * 9], [s.x - fw.x * 6 + sd.x * 5.5, s.y - fw.y * 6 + sd.y * 5.5], [s.x - fw.x * 3, s.y - fw.y * 3], [s.x - fw.x * 6 - sd.x * 5.5, s.y - fw.y * 6 - sd.y * 5.5]], P["w"])
	RR(8, 8, 200, 56, Color("#262b44", 0.85), P["sl"], 2)
	var ki := mini(kk, r.size() - 1)
	T("Altitude  %d km" % roundi(maxf(0.0, r[ki] - MOON_R)), 18, 14, P["w"], 0, 14)
	T("Speed  %.2f km/s" % v[ki], 18, 34, P["y"], 0, 14)
	T("SPACE = FIRE", W - 12, 10, P["y"], 2, 16)
	T("path: NASA GMAT run · Moon drawn to scale", 8, H - 14, P["gy"], 0, 10)


var _over_at := 0.0

func finish(stars: int, why: String, nasa := "") -> void:
	_over_at = Time.get_ticks_msec() / 1000.0
	super.finish(stars, why, nasa)
