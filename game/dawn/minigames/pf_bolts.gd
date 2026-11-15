extends "res://game/dawn/minigames/mini_game.gd"
## ACT 1 · ENGINEER · Pre-flight check (easy). Four bolts on the shuttle's hatch panel are loose and
## blink red: click each one to tighten it. No timing and no way to fail. Earth Launch Pad, Moon trip prep.
## Real: launch vibration shakes loose anything not torqued right, so every bolt is checked before flight.

const BOLTS := [Vector2(212, 108), Vector2(428, 108), Vector2(212, 252), Vector2(428, 252)]
const R_BOLT := 26.0

var tight: Array = []           # true when a bolt is done
var turn: Array = []            # how far each bolt has turned (0..1), for the little animation


func _init() -> void:
	title = "PRE-FLIGHT CHECK"
	goal = "Launch shakes the shuttle hard. Four bolts on the hatch panel are loose (blinking red). Click each bolt to tighten it."


func setup() -> void:
	tight = [false, false, false, false]
	turn = [0.0, 0.0, 0.0, 0.0]
	say("Click the red bolts.")


func press(q: Vector2) -> void:
	for i in BOLTS.size():
		if not tight[i] and q.distance_to(BOLTS[i]) <= R_BOLT + 10:
			tight[i] = true
			_sfx("click")
			var left := tight.count(false)
			if left > 0:
				say("Bolt tight. %d to go." % left, "ok")
			return


func tick(dt: float) -> void:
	for i in BOLTS.size():
		if tight[i]:
			turn[i] = minf(1.0, turn[i] + dt * 3.0)
	if tight.count(false) == 0 and turn.min() >= 1.0:
		finish(3, "All four bolts are torqued. Launch vibration shakes loose anything that isn't tight, so engineers check every bolt before flight.",
			"NASA engineers torque every fastener to a set value and mark it before launch.")


func _sfx(name: String) -> void:
	var snd: Node = get_tree().root.get_node_or_null("Sound") if is_inside_tree() else null
	if snd:
		snd.play(name)


func paint() -> void:
	R(0, 0, W, H, P["k"])
	# hatch panel
	RR(150, 50, 340, 260, P["sl"], P["st"], 4)
	RR(170, 70, 300, 220, Color("#262b44"), P["st"], 2)
	R(296, 140, 48, 80, P["st"])                        # handle
	R(304, 148, 32, 64, P["sl"])
	T("SHUTTLE HATCH PANEL", W / 2, 22, P["lg"], 1, 16)
	var blink := int(Time.get_ticks_msec() / 350) % 2 == 0
	for i in BOLTS.size():
		var c: Vector2 = BOLTS[i]
		var done: bool = tight[i]
		var ring_col: Color = P["g"] if done else (P["r"] if blink else Color("#be4a2f"))
		disc(c.x, c.y, R_BOLT + 6, ring_col)
		disc(c.x, c.y, R_BOLT, P["lg"])
		disc(c.x, c.y, R_BOLT - 6, P["gy"])
		# the slot turns while tightening (a quarter turn), stays still once done
		var a: float = PI / 4 + turn[i] * PI / 2
		var d := Vector2.from_angle(a) * (R_BOLT - 8)
		line(c.x - d.x, c.y - d.y, c.x + d.x, c.y + d.y, P["k"], 5)
		if not done and started and c.distance_to(mouse) <= R_BOLT + 10:
			ring(c.x, c.y, R_BOLT + 12, P["y"], -1, 2)
		T("TIGHT" if done else "LOOSE", c.x, c.y + R_BOLT + 12, P["g"] if done else P["r"], 1, 13)
	T("BOLTS %d / 4" % tight.count(true), W / 2, H - 30, P["y"], 1, 16)
