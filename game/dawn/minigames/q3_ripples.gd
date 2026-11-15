extends "res://game/dawn/minigames/mini_game.gd"
## ACT 3 · QUARTERMASTER · Data ripples. Pick ONE instrument, then click the ripples before they fade
## to fill the data bar in 15 s. Faster instruments send more per ripple, but their ripples are small
## and quick. Moon Lunar Control: link the shield's data home (before the launch seats).
## Real: data rates from instruments.csv; SOHO streams 200 kbit/s from L1 (NASA DSN).
## Game: "faster = smaller ripple" stands for precise antenna pointing; per-hit amounts.

const ITEMS := [{"n": "OMI", "p": "Ozone mapper", "r": 0.8}, {"n": "CRaTER", "p": "Radiation meter", "r": 0.0891},
	{"n": "MARCI-UV", "p": "UV camera", "r": 0.0718}, {"n": "LOLA", "p": "Laser altimeter", "r": 0.01},
	{"n": "LEND", "p": "Neutron counter", "r": 0.0029}]

var inst = null
var rip: Array = []
var data := 0.0
var time := 15.0
var miss := 0
var sp := 0.0
var pops: Array = []
var per := 0.0
var life := 0.0
var rad := 0.0


func _init() -> void:
	title = "DATA RIPPLES"
	goal = "Click ONE instrument card to send its data home. Ripples pop up at random places: click inside each ripple before it fades. Fill the data bar in 15 s. Faster instruments send more per ripple, but their ripples are small and quick."


func setup() -> void:
	inst = null
	rip = []
	data = 0.0
	time = 15.0
	miss = 0
	sp = 0.0
	pops = []
	say("Click an instrument card to start.")


func choose(i: int) -> void:
	if inst != null:
		return
	inst = ITEMS[i]
	var f := (log(inst["r"]) - log(0.0029)) / (log(0.8) - log(0.0029))
	per = 4 + f * 12
	life = 1.8 - f * 1.2
	rad = 36 - f * 20
	say("%s: %d%% per ripple, ripples last %.1f s. GO!" % [inst["n"], roundi(per), life], "ok")


func _card(i: int) -> Rect2:
	return Rect2(62 + i * 104, 120, 96, 100)


func press(q: Vector2) -> void:
	if inst == null:
		for i in ITEMS.size():
			if _card(i).has_point(q):
				choose(i)
		return
	for i in range(rip.size() - 1, -1, -1):
		var r: Dictionary = rip[i]
		if q.distance_to(r["p"]) <= r["R"] + 6:
			data += per
			pops.append({"p": r["p"], "t": 0.7, "s": "+%d%%" % roundi(per)})
			rip.remove_at(i)
			return


func tick(dt: float) -> void:
	for p in pops:
		p["t"] -= dt
	pops = pops.filter(func(p): return p["t"] > 0)
	if inst == null:
		return
	time -= dt
	sp -= dt
	if sp <= 0 and rip.size() < 4:
		sp = 0.45
		for _k in 12:
			var p := Vector2(randf_range(rad + 16, W - rad - 16), randf_range(54 + rad, H - 34 - rad))
			if rip.all(func(r): return r["p"].distance_to(p) > r["R"] + rad + 10):
				rip.append({"p": p, "t": 0.0, "R": rad})
				break
	for r in rip:
		r["t"] += dt
	var before := rip.size()
	rip = rip.filter(func(r): return r["t"] < life)
	miss += before - rip.size()
	if data >= 100:
		finish(3 if (time >= 3 and miss == 0) else (2 if time >= 3 else 1),
			"Data home with %s (%s Mbps) and %.1f s to spare. A fast link moves more data, but it needs precise pointing; a slow link is easy to catch but may not be enough." % [inst["n"], str(inst["r"]), time],
			"NASA's Deep Space Network dishes receive spacecraft data every day; SOHO streams 200 kbit/s from L1.")
	elif time <= 0:
		finish(0, "Only %d%% sent. Try a different instrument: the slowest ones need almost every ripple, the fastest ones need sharp aim." % roundi(data),
			"Deep Space Network data rates range from a few bits to millions of bits per second.")


func paint() -> void:
	sky(Color("#0b0913"))
	for r in rip:
		var kk: float = r["t"] / life
		var a := 1.0 - kk
		for j in 3:
			var rr: float = r["R"] * clampf(kk * 1.3 - j * 0.18 + 0.25, 0.05, 1.0)
			ring(r["p"].x, r["p"].y, rr, Color(P["b"], a * (1 - j * 0.25)), -1, 2.4)
		disc(r["p"].x, r["p"].y, 3, Color(P["w"], a))
	for p in pops:
		T(p["s"], p["p"].x, p["p"].y - 26 + p["t"] * 14, P["y"], 1, 18)
	T("DATA HOME", 12, 10, P["w"], 0, 14)
	bar(100, 12, 360, 12, data / 100.0, P["g"])
	T("%d%%" % roundi(minf(100.0, data)), 470, 10, P["lg"], 0, 14)
	T("TIME %.1f s" % maxf(0.0, time), W - 12, 10, P["y"], 2, 16)
	if inst == null:
		T("CHOOSE ONE INSTRUMENT", W / 2, 84, P["y"], 1, 15)
		for i in ITEMS.size():
			var r := _card(i)
			var hov := r.has_point(mouse)
			RR(r.position.x, r.position.y, r.size.x, r.size.y, P["nv"], P["y"] if hov else P["st"], 2)
			T(ITEMS[i]["n"], r.get_center().x, r.position.y + 12, P["y"], 1, 13)
			T(ITEMS[i]["p"], r.get_center().x, r.position.y + 34, P["w"], 1, 9.5)
			T("%s Mbps" % num(ITEMS[i]["r"]), r.get_center().x, r.position.y + 62, P["b"], 1, 12)
		T("faster = more data per ripple, but smaller and quicker ripples", W / 2, 240, P["gy"], 1, 11)
	else:
		T("%s · %s Mbps · missed %d" % [inst["n"], str(inst["r"]), miss], 12, H - 24, P["lg"], 0, 13)
