extends "res://game/dawn/minigames/mini_game.gd"
## ACT 1 · NAVIGATOR · Newton's cannon. Set the sideways speed and FIRE: too slow falls back,
## just right circles the Earth, too fast escapes. Earth Navigation, Moon trip prep.
## Data: Earth radius 6,371 km, GM = 398,600 km³/s² (NASA Earth Fact Sheet). Start height 400 km.

const GM := 398600.4
const RE := 6371.0
const ALT := 400.0

var v := 6.0
var st := {}
var tries := 0


func _init() -> void:
	lo = true
	title = "NEWTON'S CANNON"
	goal = "Before the shuttle can head to the Moon it must reach orbit. Set the sideways speed and FIRE. Too slow falls back like the sounding rocket. Just right circles the Earth. Very fast shots escape."


func setup() -> void:
	v = 6.0
	st = {}
	tries = 0
	add_slider("SPEED", 1.0, 11.5, 0.1, v, func(x): v = x)
	add_button("FIRE", func(_b): fire())
	say("Pick a speed and fire.")


func key(kc: int, down: bool) -> bool:
	if kc == KEY_SPACE:
		if down:
			fire()
		return true
	return false


func fire() -> void:
	if not st.is_empty() and st["run"]:
		return
	tries += 1
	var r0 := RE + ALT
	var eps := v * v / 2.0 - GM / r0
	var kk := 40
	if eps >= 0:
		kk = 320
	else:
		var a := -GM / (2.0 * eps)
		var tp := TAU * sqrt(a * a * a / GM)
		kk = clampi(ceili(tp / (1.5 * 6 * 60)), 40, 320)
	st = {"x": 0.0, "y": r0, "vx": v, "vy": 0.0, "sw": 0.0, "pa": PI / 2, "run": true, "trail": [], "k": kk, "n": 0}


func tick(_dt: float) -> void:
	if st.is_empty() or not st["run"]:
		return
	for j in st["k"]:
		var h := 1.5
		var r := Vector2(st["x"], st["y"]).length()
		var a := -GM / (r * r * r)
		st["vx"] += a * st["x"] * h
		st["vy"] += a * st["y"] * h
		st["x"] += st["vx"] * h
		st["y"] += st["vy"] * h
		st["n"] += 1
		var r2 := Vector2(st["x"], st["y"]).length()
		var an := atan2(st["y"], st["x"])
		var d: float = wrapf(an - st["pa"], -PI, PI)
		st["sw"] += d
		st["pa"] = an
		if st["n"] % maxi(4, roundi(st["k"] / 10.0)) == 0:
			st["trail"].append([st["x"], st["y"]])
		if r2 < RE + 100:
			st["run"] = false
			say("Fell back after %d° around. That's a suborbital hop, like the sounding rocket. Go faster sideways." % roundi(absf(rad_to_deg(st["sw"]))), "bad")
			return
		var sp2: float = st["vx"] * st["vx"] + st["vy"] * st["vy"]
		if r2 > 80000 and sp2 > 2 * GM / r2:
			st["run"] = false
			say("Escaped Earth completely! Way too fast for the first step: we need orbit before the Moon. Lower the speed and fire again.", "bad")
			return
		if absf(st["sw"]) >= TAU:
			st["run"] = false
			var vc := sqrt(GM / (RE + ALT))
			var e := absf(v - vc)
			finish(3 if e < 0.15 else (2 if e < 0.6 else 1),
				"You orbited at %.1f km/s. At 400 km the speed for a circle is about %.1f km/s. Orbit means falling around the Earth: you move sideways so fast that the ground curves away below you." % [v, vc],
				"Newton imagined this cannon in 1687. The ISS travels about 7.7 km/s at ~400 km.")
			return


func paint() -> void:
	sky()
	var cx := 160.0
	var cy := 92.0
	var sc := 34.0 / RE
	earth(cx, cy, 34, 0)
	R(cx - 1.5, cy - 39, 3, 5, P["br"])
	R(cx - 4, cy - 39, 8, 2.5, P["lg"])
	ring(cx, cy, (RE + 100) * sc, Color("#4b6cb7"), -1, 0.6, true)
	T("AIR 100 km", cx + 39, cy - 5, Color("#4b6cb7"), 0, 5)
	if not st.is_empty():
		var pts := []
		for q in st["trail"]:
			pts.append([cx + q[0] * sc, cy - q[1] * sc])
		pts.append([cx + st["x"] * sc, cy - st["y"] * sc])
		poly(pts, P["o"], 1.1)
		disc(cx + st["x"] * sc, cy - st["y"] * sc, 2, P["w"])
	T("v = %.1f km/s   tries %d" % [v, tries], 6, 6, P["y"])
	if not st.is_empty() and st["run"] and st["k"] > 40:
		T("FAST-FORWARD ×%d" % roundi(st["k"] / 40.0), 314, 6, P["r"], 2)
	T("NOT TO SCALE: trail shrinks far out", 6, 170, P["gy"], 0, 5.5)
