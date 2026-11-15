extends "res://game/dawn/minigames/mini_game.gd"
## ACT 3 · NAVIGATOR · Hold the shield at L1. L1 is a balance point but unstable: the shield drifts.
## Tap ◄ / ► thrusters to keep it in the green zone for 20 s with only 10 taps of fuel.
## Moon Port: aim the shield at L1 (replaces the old slider task "l1").
## Real: L1 is ~1.5 million km from Earth toward the Sun; SOHO and DSCOVR fly halo paths there with
## small correction burns. Game: drift, fuel and timer. Not to scale.
## Optional later: a real DSCOVR halo from NASA SSCWeb (the HTML had a CSV loader; left out here).

var d := 0.0
var v := 0.0
var fuel := 10
var hold := 0.0
var left_zone := false
var fx := 0.0


func _init() -> void:
	lo = true
	title = "HOLD THE SHIELD AT L1"
	goal = "L1 is a balance point between Sun and Earth, but it is unstable: the shield slowly drifts away. Tap ◄ / ► (buttons or arrow keys) to keep it in the green zone for 20 seconds. Only 10 taps of fuel."


func setup() -> void:
	d = randf_range(-2, 2)
	v = 0.0
	fuel = 10
	hold = 0.0
	left_zone = false
	fx = 0.0
	add_button("◄ TOWARD SUN", func(_b): thrust(-1))
	add_button("TOWARD EARTH ►", func(_b): thrust(1))
	say("The shield is drifting. Small taps!")


func key(kc: int, down: bool) -> bool:
	if kc == KEY_LEFT or kc == KEY_RIGHT:
		if down:
			thrust(-1 if kc == KEY_LEFT else 1)
		return true
	return false


func thrust(s: int) -> void:
	if not started or over:
		return
	if fuel <= 0:
		say("Out of fuel!", "bad")
		return
	fuel -= 1
	v += s * 5
	fx = 0.25


func tick(dt: float) -> void:
	fx = maxf(0.0, fx - dt)
	v += (0.45 * d + randf_range(-1.2, 1.2)) * dt
	d += v * dt
	if absf(d) < 8:
		hold += dt
	else:
		left_zone = true
	if absf(d) > 45:
		finish(0, "The shield drifted %s and left L1. L1 is a balance point, not a parking spot: small early burns beat big late ones." % ("toward the Sun" if d < 0 else "toward Earth"),
			"SOHO and DSCOVR stay near L1 with regular small station-keeping burns.")
		return
	if hold >= 20:
		finish(3 if (not left_zone and fuel >= 5) else (2 if fuel >= 3 else 1),
			"Held at L1 with %d taps of fuel left. Fuel is mission lifetime: when it runs out, the shield drifts away. From L1 the shield stays between the Sun and Earth all year, and Earth spins under it, so every place is shaded during its own daytime." % fuel,
			"DSCOVR's EPIC camera at L1 always sees the fully sunlit Earth. Angel (2006) proposed a sunshade near L1 blocking 1.8% of sunlight; a UV-only shield is game fiction.")


func paint() -> void:
	sky(Color("#04040c"))
	for b in 4:
		disc(-40, 90, 72 - b * 8, Color(P["y"] if b > 1 else P["o"], 0.4 + b * 0.2))
	for i in 8:
		line(24, 40 + i * 14, 270, 82 + i * 2, Color(P["y"], 0.14), 1)
	earth(285, 90, 18, t * 2)
	var lx := 200.0
	var sx := lx + d
	var sy := 90 + 14 * sin(t * 0.6)
	ring(lx, 90, 6, Color(P["g"], 0.8), 18, 1, true)
	R(lx - 8, 30, 16, 120, Color(P["g"], 0.08))
	line(lx - 8, 30, lx - 8, 150, P["dg"], 0.7)
	line(lx + 8, 30, lx + 8, 150, P["dg"], 0.7)
	T("L1", lx, 152, P["g"], 1)
	if absf(d) < 8:
		fill_poly([[sx, sy - 8], [285, 68], [285, 112], [sx, sy + 8]], Color(P["b"], 0.18))
	R(sx - 1.5, sy - 9, 3, 18, P["lg"])
	R(sx - 3.5, sy - 1.5, 7, 3, P["gy"])
	if fx > 0:
		disc(sx + (-6 if v > 0 else 6), sy, 2, P["or"])
	T("SUN", 4, 4, P["y"])
	T("EARTH", 285, 112, P["b"], 1)
	T("day side faces the shield", 316, 124, P["lg"], 2, 6)
	T("FUEL", 100, 4, P["y"])
	for i in 10:
		R(122 + i * 6, 6, 4, 5, P["y"] if i < fuel else P["sl"])
	T("IN ZONE", 100, 14, P["w"])
	bar(140, 15, 80, 6, hold / 20.0, P["g"])
	T("%.1f/20 s" % hold, 224, 14, P["lg"])
	T("not to scale: L1 is 1.5 million km from Earth", 4, 170, P["gy"], 0, 5.5)
