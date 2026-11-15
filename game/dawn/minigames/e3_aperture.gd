extends "res://game/dawn/minigames/mini_game.gd"
## ACT 3 · ENGINEER · Open the shield aperture. HOLD OPEN (or SPACE) to open the circular aperture;
## watch TENSION: in the red the mechanism jams. Release to let tension drop. Moon Port, after the
## Navigator has aimed the shield (before the launch seats).
## Real: Hubble's roller-blind solar arrays and aperture door were opened by command in 1990; one array
## showed high tension and controllers paused (NASA). Game: tension rates, opening time.

var open := 0.0
var tension := 0.0
var holding := false
var stick := 0.0
var tk := 0.0
var jams := 0
var jam_t := 0.0


func _init() -> void:
	title = "OPEN THE SHIELD APERTURE"
	goal = "The shield spacecraft must open a wide circular aperture, like the aperture door on the Hubble Space Telescope. HOLD OPEN (or SPACE) to open it. Watch the TENSION gauge: in the red zone the mechanism jams. RELEASE to let tension drop, then keep opening until 100%."


func setup() -> void:
	open = 0.0
	tension = 0.0
	holding = false
	stick = 0.0
	tk = 0.0
	jams = 0
	jam_t = 0.0
	add_hold_button("OPEN (HOLD)", func(d): holding = d)
	say("Hold OPEN. Release when TENSION gets close to the red zone.")


func key(kc: int, down: bool) -> bool:
	if kc == KEY_SPACE:
		holding = down
		return true
	return false


func tick(dt: float) -> void:
	tk -= dt
	if tk <= 0:
		tk = randf_range(0.6, 1.2)
		stick = randf_range(0.7, 1.0) if randf() < 0.35 else randf_range(0.0, 0.4)
	if jam_t > 0:
		jam_t -= dt
		tension = maxf(25.0, tension - 22 * dt)
		if jam_t <= 0:
			say("Mechanism free again. Keep opening, but release sooner.", "ok")
		return
	if holding:
		open = minf(100.0, open + 9 * dt)
		tension += (16 + 40 * stick) * dt
	else:
		tension = maxf(0.0, tension - 34 * dt)
	if tension >= 100:
		jams += 1
		jam_t = 2.0
		tension = 100.0
		say("JAM! The mechanism is snagging. Release and wait.", "bad")
	if open >= 100:
		finish(3 if jams == 0 else (2 if jams == 1 else 1),
			"Aperture fully open with %d jams. In space nobody can push a stuck mechanism free, so deployments go slowly and the team watches tension the whole time." % jams,
			"Hubble's roller-blind arrays unfurled after release in April 1990; one array showed high tension and controllers paused before continuing.")


func paint() -> void:
	sky()
	var cx := 330.0
	var cy := 190.0
	var R0 := 118.0
	var ro := open / 100.0 * 104
	var tw := open / 100.0 * 0.5
	disc(cx, cy, R0 + 10, P["st"])
	disc(cx, cy, R0 + 4, P["lg"])
	# the hole: space, stars and the Sun's glow
	if ro > 2:
		disc(cx, cy, ro, Color("#04050c"))
		for s in STARS:
			var p := Vector2(cx + (s[0] - 320) * 0.4, cy + (s[1] - 180) * 0.45)
			if p.distance_to(Vector2(cx, cy)) < ro - 2:
				R(p.x, p.y, 1.5, 1.5, P["w"])
		for b in 4:
			disc(cx, cy, ro * (0.5 - b * 0.11), Color(P["y"], 0.18 + b * 0.18))
	# 8 petals (an iris)
	for kk in 8:
		var a0 := kk * PI / 4 + tw
		var a1 := a0 + PI / 4
		var pts := []
		for j in 9:
			var a := lerpf(a0, a1, j / 8.0)
			pts.append([cx + R0 * cos(a), cy + R0 * sin(a)])
		for j in 9:
			var a := lerpf(a1, a0, j / 8.0)
			pts.append([cx + maxf(1.0, ro) * cos(a), cy + maxf(1.0, ro) * sin(a)])
		fill_poly(pts, Color("#8b9bb4") if kk % 2 else Color("#c0cbdc"))
		pts.append(pts[0])
		poly(pts, P["st"], 1.5)
	if ro > 2:
		ring(cx, cy, ro, P["w"], -1, 2)
	for kk in 12:
		var a := kk * PI / 6
		disc(cx + (R0 - 7) * cos(a), cy + (R0 - 7) * sin(a), 2.6, P["st"])
	T("shield spacecraft, front view", cx, cy + R0 + 16, P["gy"], 1, 11)
	# left: opening + how to play
	T("OPENING", 16, 14, P["lg"], 0, 13)
	T("%d%%" % roundi(open), 16, 30, P["w"], 0, 36)
	bar(16, 80, 150, 12, open / 100.0, P["b"])
	RR(12, 116, 186, 176, Color("#181425", 0.9), P["sl"], 2)
	T("HOW TO PLAY", 24, 124, P["y"], 0, 12)
	var steps := ["Hold OPEN or SPACE", "Watch TENSION (right)", "Near red? RELEASE", "Reach 100% open"]
	for i in steps.size():
		R(25, 151 + i * 32, 18, 18, P["nv"])
		T(str(i + 1), 34, 153 + i * 32, P["y"], 1, 13)
		T(steps[i], 52, 152 + i * 32, P["w"], 0, 12.5)
	# right: tension gauge
	var gx := 566.0
	var gy := 48.0
	var gh := 244.0
	T("TENSION", gx + 16, 16, P["lg"], 1, 13)
	T("(stuck blanket)", gx + 16, 32, P["gy"], 1, 9.5)
	R(gx, gy, 32, gh, Color("#181425"))
	R(gx, gy, 32, gh * 0.15, Color(P["r"], 0.4))
	R(gx, gy + gh * 0.15, 32, gh * 0.25, Color(P["y"], 0.3))
	R(gx, gy + gh * 0.4, 32, gh * 0.6, Color(P["g"], 0.25))
	var tf := clampf(tension / 100.0, 0.0, 1.0)
	R(gx, gy + gh * (1 - tf), 32, gh * tf, P["r"] if tension > 85 else (P["y"] if tension > 60 else P["g"]))
	RR(gx, gy, 32, gh, null, P["st"], 2)
	T("JAM", gx - 6, gy + 2, P["r"], 2, 10)
	T("safe", gx - 6, gy + gh - 14, P["g"], 2, 10)
	if jam_t > 0:
		T("JAMMED… wait", cx, 24, P["r"], 1, 24)
	elif stick > 0.6 and holding:
		T("SNAG! release now", cx, 24, P["or"], 1, 20)
	T("JAMS %d" % jams, W - 12, H - 22, P["y"], 2, 13)
