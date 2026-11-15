extends RefCounted
## The story of Project Dawn: objectives, actions, holds, storms and effects for the three acts.
## Owner: Sufi (gameplay). Ported from the HTML demo (web/demo, c4.js). dawn.gd owns this object.
##
## Progress lives in g.S (shared, host decides):
##   Act 1 Earth step 0 board · 1 build rocket · 2 readiness review · 3 countdown · 4 results · 5 fly to the Moon · 6 home
##   Act 2 Moon  ms   0 check in · 1 find ice · 2 power cable · 3 mine ice · 4 make fuel (→ solar storm)
##   Act 3 Moon  ms   5 shield design + factory · 6 aim at L1, launch · 7 shield report → fly home → ending
## See docs/STORY_MOON_ONLY.md for the whole flow.
## Everything that changes S runs on the host only (do_effect, host_tick).

const WD := preload("res://game/dawn/world_data.gd")
const RoleSprites := preload("res://game/player/role_sprites.gd")
const StoryUI := preload("res://game/dawn/story_ui.gd")
const ROLES := ["eng", "sci", "nav", "qm"]
const TRIP_DAYS := {"trip": 3, "shield": 90, "home": 3}

## Workshop parts (game values, same as the HTML demo).
const PARTS := {"uv": {"name": "UV sensor", "kg": 5, "cr": 35}, "cam": {"name": "Camera", "kg": 8, "cr": 25},
	"chute": {"name": "Parachute", "kg": 6, "cr": 15}, "radio": {"name": "Radio", "kg": 3, "cr": 25},
	"small": {"name": "Small motor", "kg": 100, "cr": 40, "power": 14664}, "big": {"name": "Big motor", "kg": 160, "cr": 70, "power": 30150}}
const BODY := {"kg": 30, "cr": 30}

## Every role has a job: prep checklists that must be done before the story moves on.
const PREP := {"e1": ["build", "uvcal", "wind", "tune"], "e5": ["perigee", "cargo", "bolts", "site"]}
const PREP_NAMES := {"e1": ["ENG rocket", "SCI ozone maps", "NAV launch hour", "QM instruments"], "e5": ["NAV orbit", "QM cargo", "ENG bolts", "SCI landing site"]}
## task -> [role, world, progress key, value, line said when done]
const TASKS := {
	"cube": ["eng", "earth", "step", 1, "Payload cube assembled: power, data and the UV sensor window all in place."],
	"uvcal": ["sci", "earth", "step", 1, "Ozone maps compared: 1984 had the thickest ozone, 1994 the biggest hole. Now we know what we measure."],
	"wind": ["nav", "earth", "step", 1, "Launch hour picked: daylight, calm wind, no UV storm."],
	"tune": ["qm", "earth", "step", 1, "Instruments loaded: only the ozone mappers fly, inside mass, power and data limits."],
	"perigee": ["nav", "earth", "step", 5, "Orbit speed found: fast enough sideways and we fall around the Earth, not into it."],
	"cargo": ["qm", "earth", "step", 5, "Cargo sealed: water, food, oxygen and the ice drill."],
	"bolts": ["eng", "earth", "step", 5, "Shuttle bolts torqued. She will hold together."],
	"site": ["sci", "earth", "step", 5, "Landing site picked: the rim of a shadowed crater at the south pole."],
	"arrival": ["nav", "moon", "ms", 0, "Arrival burn logged: we braked right at the closest point to the Moon."],
	"outpost": ["qm", "moon", "ms", 2, "Outpost payload packed: it finds ice, watches radiation and sees into the shadows."],
	"icescan": ["eng", "moon", "ms", 3, "Drill spot confirmed: very cold AND few neutrons. That is ice."],
	"sunscan": ["sci", "moon", "ms", 5, "Sunlight scanned: the shield only has to stop the UV that ozone used to stop."],
	"l1": ["nav", "moon", "ms", 6, "Shield held at L1, where the pull of the Sun and Earth balance."],
	"aperture": ["eng", "moon", "ms", 6, "Shield aperture opens all the way. No jams in space."],
	"datahome": ["qm", "moon", "ms", 6, "Data link tested: the shield's readings will reach home."],
}
const BUDGET := 150

const Minigames := preload("res://game/dawn/minigames.gd")
const Designers := preload("res://game/dawn/designers.gd")

var g                       ## dawn.gd
var mg                      ## minigames.gd
var dz                      ## designers.gd
var sui                     ## story_ui.gd: the full-screen moments (workshop, launch, travel...)
var _hold_push := 0.0
var _scene_t := 0.0


func start() -> void:
	mg = Minigames.new()
	mg.g = g
	dz = Designers.new()
	dz.g = g
	sui = StoryUI.new()
	sui.story = self
	sui.g = g
	g.ui.root.add_child(sui)
	sui.intro()


# ---------------------------------------------------------------- helpers

func S() -> Dictionary:
	return g.S


func rid(k: String) -> String:
	return g.S["world"] + "." + k


func seats(room_key: String, pre: String) -> Dictionary:
	var out := {}
	for r in ROLES:
		out[r] = [rid(room_key), pre + r]
	return out


func task_done(t: String) -> bool:
	return g.S["tasks"].get(t, false)


func prep_done(k: String) -> bool:
	for t in PREP[k]:
		if not task_done(t):
			return false
	return true


func checklist(k: String) -> String:
	var out := []
	for i in PREP[k].size():
		out.append(("✓ " if task_done(PREP[k][i]) else "· ") + PREP_NAMES[k][i])
	return "   ".join(out)


func uv_active() -> bool:
	return g.S["world"] == "earth" and g.S["step"] >= 3 and g.S["step"] < 6


## Rocket maths for the workshop and the launch.
static func calc(d: Dictionary) -> Dictionary:
	var keys := ["uv", "cam", "chute", "radio"].filter(func(k): return d.get(k, false))
	var m: Dictionary = PARTS[d.get("motor", "small")]
	var kg: int = BODY["kg"] + m["kg"]
	var cr: int = BODY["cr"] + m["cr"]
	for k in keys:
		kg += PARTS[k]["kg"]
		cr += PARTS[k]["cr"]
	var alt := roundi(float(m["power"]) / kg)
	var ok := {"uv": d.get("uv", false), "alt": alt >= 100, "rec": d.get("chute", false) or d.get("radio", false), "budget": cr <= BUDGET}
	var hint := "Looks good. Lock it in, then the whole crew meets for the readiness review."
	if not ok["uv"]:
		hint = "The Scientist needs a UV sensor on board."
	elif not ok["alt"]:
		hint = "Too heavy: only %d km. Drop weight or fit the big motor." % alt
	elif not ok["rec"]:
		hint = "No way to get the data back. Add a parachute or a radio."
	elif not ok["budget"]:
		hint = "Over budget by %d credits." % (cr - BUDGET)
	return {"kg": kg, "cr": cr, "alt": alt, "ok": ok, "all": ok["uv"] and ok["alt"] and ok["rec"] and ok["budget"], "hint": hint}


# ---------------------------------------------------------------- objective

func objective() -> Dictionary:
	var s := S()
	match s["world"]:
		"earth": return _earth_obj(s)
		"moon": return _moon_obj(s)
	return {"room": "", "text": ""}

## The objective for ONE crew member (what their HUD, blinking door and map arrow point to).
##   1. Storms and holds: everyone gets the same objective (all crew together).
##   2. A job for my role in the room the crew objective points to (e.g. the NAVIGATOR's countdown).
##   3. My role's own task (TASKS: the launch-prep / departure-prep checklists, L1, launch window):
##      during prep, each role is sent to a different room at the same time.
##   4. Otherwise: the crew objective, so I go and help.
func objective_for(role: String) -> Dictionary:
	var ob := objective()
	if ob.get("alert", false) or ob.get("hold", false):
		return ob
	var mine := work_list().filter(func(j): return j["role"] == role and _still_to_do(j))
	for job in mine:
		if job["room"] == ob.get("room", ""):
			return _job_objective(role, job)
	for job in mine:
		if not role_task(WD.key_of(job["room"])).is_empty():
			return _job_objective(role, job)
	return ob


## A job from work_list() that is not finished yet ("REBUILD" = optional redo of a finished build).
func _still_to_do(job: Dictionary) -> bool:
	var what := String(job["what"])
	return not what.ends_with("(done)") and not what.begins_with("REBUILD")


## Objective text for my own job, e.g. "SCIENTIST · CALIBRATE UV SENSOR · OZONE LAB".
func _job_objective(role: String, job: Dictionary) -> Dictionary:
	var where: String = WD.room(job["room"]).get("name", "").replace("\n", " ")
	return {"room": job["room"], "text": "%s · %s · %s" % [RoleSprites.NAMES[role], job["what"], where]}

func _earth_obj(s: Dictionary) -> Dictionary:
	var st: int = s["step"]
	if st == 1:
		var room := "earth.shop" if not task_done("build") else ("earth.ozone" if not task_done("uvcal") else ("earth.nav" if not task_done("wind") else "earth.comms"))
		return {"room": room, "text": "LAUNCH PREP · " + checklist("e1")}
	if st == 5 and not prep_done("e5"):
		var room2 := "earth.nav" if not task_done("perigee") else ("earth.power" if not task_done("cargo") else ("earth.pad" if not task_done("bolts") else "earth.ozone"))
		return {"room": room2, "text": "MOON TRIP PREP · " + checklist("e5")}
	if st == 5 and not all_suited():
		var miss := ROLES.filter(func(r): return not s["suits"].get(r, false)).map(func(r): return r.to_upper())
		return {"room": "earth.crew", "text": "SUIT UP · spacesuit locker in CREW QUARTERS · in uniform: " + ", ".join(miss)}
	var list := [
		{"room": "earth.mc", "text": "ANYONE · open the mission board in MISSION CONTROL"},
		{"room": "earth.shop", "text": "ENGINEER · build the rocket in the WORKSHOP"},
		{"room": "earth.mc", "hold": true, "text": "READINESS REVIEW · all 4 crew on your consoles in MISSION CONTROL"},
		{"room": "earth.pad", "text": "NAVIGATOR · start the countdown at the LAUNCH PAD (UV outside!)"},
		{"room": "earth.mc", "text": "ANYONE · hear the results in MISSION CONTROL"},
		{"room": "earth.pad", "hold": true, "text": "ALL 4 CREW · board the shuttle at the LAUNCH PAD"},
		{"room": "", "text": "The sky is healing. The doors are open: explore Bunker 4"},
	]
	return list[clampi(st, 0, list.size() - 1)]


func _moon_obj(s: Dictionary) -> Dictionary:
	if not s["storm"].is_empty():
		return {"room": "moon.shelter", "alert": true, "text": "SOLAR STORM! ALL 4 crew into the RADIATION SHELTER: %ds" % maxi(0, ceili(s["storm"]["t"]))}
	var m: int = s["ms"]
	if m == 0 and not task_done("arrival"):
		return {"room": "moon.landing", "text": "NAVIGATOR · replay the arrival burn at the LANDING PAD"}
	if m == 2 and not task_done("outpost"):
		return {"room": "moon.solar", "text": "QUARTERMASTER · pack the outpost payload at the SOLAR RIDGE"}
	if m == 2:
		return {"room": "moon.solar", "text": "QUARTERMASTER · design the outpost power at the SOLAR RIDGE"}
	if m == 3 and not task_done("icescan"):
		return {"room": "moon.mine", "text": "ENGINEER · scan for ice before drilling in the ICE MINE"}
	if m == 5 and not s["sats_chosen"] and not task_done("sunscan"):
		return {"room": "moon.factory", "text": "ACT 3 · SCIENTIST · scan the Sun's light at the MOON FACTORY"}
	if m == 5 and not s["sats_chosen"]:
		return {"room": "moon.factory", "text": "ACT 3 · ENGINEER · design the shield satellites at the MOON FACTORY"}
	if m == 6 and not task_done("l1"):
		return {"room": "moon.port", "text": "NAVIGATOR · hold the shield at the L1 point from the MOON PORT"}
	if m == 6 and not task_done("aperture"):
		return {"room": "moon.port", "text": "ENGINEER · open the shield aperture at the MOON PORT"}
	if m == 6 and not task_done("datahome"):
		return {"room": "moon.lc", "text": "QUARTERMASTER · test the data link at LUNAR CONTROL"}
	if m == 5 and s["sats_chosen"]:
		return {"room": "moon.factory", "hold": true, "text": "ENGINEER + QUARTERMASTER · hold your stations in the MOON FACTORY"}
	var list := [
		{"room": "moon.lc", "text": "ANYONE · check in at LUNAR CONTROL"},
		{"room": "moon.science", "text": "SCIENTIST · find the ice at the SCIENCE LAB"},
		{"room": "moon.solar", "text": "QUARTERMASTER · run power from the SOLAR RIDGE"},
		{"room": "moon.mine", "hold": true, "text": "ENGINEER drills, SCIENTIST holds the lamp in the dark ICE MINE. Cold!"},
		{"room": "moon.fuel", "text": "NAVIGATOR · split the ice into fuel at the FUEL PLANT"},
		{"room": "moon.factory", "text": "ACT 3 · ENGINEER · plan the shield at the MOON FACTORY"},
		{"room": "moon.port", "hold": true, "text": "ALL 4 CREW · launch seats at the MOON PORT"},
		{"room": "", "text": "The shield is up. Read the report, then the crew flies home"},
	]
	return list[clampi(m, 0, list.size() - 1)]


func all_suited() -> bool:
	for r in ROLES:
		if not g.S["suits"].get(r, false):
			return false
	return true


# ---------------------------------------------------------------- holds (several crew on their spots at once)

func hold() -> Dictionary:
	var s := S()
	if s["scene"] != "game":
		return {}
	match s["world"]:
		"earth":
			if s["step"] == 2:
				return {"id": "review", "need": seats("mc", "c_"), "secs": 3.0}
			if s["step"] == 5 and prep_done("e5") and all_suited():
				return {"id": "board", "need": seats("pad", "s_"), "secs": 3.0}
		"moon":
			if not s["storm"].is_empty():
				return {}
			if s["ms"] == 3 and task_done("icescan"):
				return {"id": "mine", "need": {"eng": ["moon.mine", "drill"], "sci": ["moon.mine", "lamp"]}, "secs": 5.0}
			if s["ms"] == 5 and s["sats_chosen"]:
				return {"id": "factory", "need": {"eng": ["moon.factory", "asm"], "qm": ["moon.factory", "feed"]}, "secs": 5.0}
			if s["ms"] == 6 and _launch_ready():
				return {"id": "port", "need": seats("port", "s_"), "secs": 3.0}
	return {}


func _hold_done(id: String) -> void:
	var s := S()
	match id:
		"review":
			set_scene("poll")
		"board":
			travel({"kind": "trip", "from": "earth", "to": "moon", "title": "ACT 2 · WATER ABOVE US", "sub": "The crew flies to the Moon to find fuel beyond Earth", "after": "moon"})
		"mine":
			s["ms"] = 4
			g.say_all([{"who": "eng", "text": "Forty kilograms of ice. Heavy, cold and priceless."}, {"who": "ceres", "text": "Navigator: the Fuel Plant is yours."}])
		"factory":
			s["ms"] = 6
			g.say_all([{"who": "eng", "text": "%d shield satellites, built from Moon metal and glass." % s["sats"]}, {"who": "ceres", "text": "All four of you: take your launch seats at the Moon Port."}])
		"port":
			travel({"kind": "shield", "title": "ACT 3 · THE SHIELD", "sub": "%d satellites fly to the point between the Sun and Earth" % s["sats"], "after": "shield"})


## Host, every frame: hold progress, storm timers and the timed scenes.
func host_tick(delta: float) -> void:
	var s := S()
	if not s["storm"].is_empty() and s["scene"] == "game":
		s["storm"]["t"] -= delta
		_storm_check()
		if not s["storm"].is_empty() and s["storm"]["t"] <= 0.0:
			_storm_fail()
	var h := hold()
	if h.is_empty():
		if not s["hold"].is_empty():
			s["hold"] = {}
			g.commit()
	else:
		var ok := true
		for r in h["need"]:
			if not g.on_spot(r, h["need"][r][0], h["need"][r][1]):
				ok = false
		var p0: float = s["hold"].get("p", 0.0) if s["hold"].get("id", "") == h["id"] else 0.0
		var p := minf(1.0, p0 + delta / h["secs"]) if ok else maxf(0.0, p0 - delta * 0.6)
		s["hold"] = {"id": h["id"], "p": p}
		if p >= 1.0:
			s["hold"] = {}
			_hold_done(h["id"])
			g.commit()
		else:
			_hold_push -= delta
			if _hold_push <= 0.0:
				_hold_push = 0.25
				g.commit()
	_scene_t += delta
	match s["scene"]:
		"poll":
			if _scene_t > 3.2:
				_finish_poll()
		"launch":
			sui.launch_host_tick(delta)
		"travel":
			if _scene_t > 6.0:
				finish_travel()


func _storm_check() -> void:
	var s := S()
	if s["world"] == "moon":
		for r in ROLES:
			if WD.room_at(g.crew[r].position) != "moon.shelter":
				return
		s["storm"] = {}
		s["ms"] = 5
		g.say_all([{"who": "eng", "text": "Everyone made it. That is why the radiation shelter is not optional."}, {"who": "ceres", "text": "Storm passed. The fuel tanks are full. Act 3: The Moon Factory."}])
		g.commit()


func _storm_fail() -> void:
	var s := S()
	s["storm"] = {}
	s["ozone"] = maxi(0, s["ozone"] - 3)
	s["pen"] += 1
	s["ms"] = 5
	g.say_all([{"who": "ceres", "text": "Radiation dose! Not everyone reached the shelter. Ozone work lost: −3%."}, {"who": "ceres", "text": "Storm passed. Act 3: The Moon Factory."}])
	g.commit()


## Where autopilot crew should be when no hold needs them ("" = stay).
func npc_room(_r: String) -> String:
	var s := S()
	if not s["storm"].is_empty() and s["world"] == "moon":
		return "moon.shelter"
	return ""


# ---------------------------------------------------------------- what E does at a console

## {label, role, fn} for the main console of a room (or {} to fall back to the room info).
func station_action(p, room_id: String, sid: String) -> Dictionary:
	if sid != "main" or WD.world_of(room_id) != g.S["world"]:
		return {}
	var k := WD.key_of(room_id)
	var a := action(k)
	if a.is_empty():
		a = flavor(k)
	return a


func _act(id: String, p := {}) -> Callable:
	return func(): g.act(id, p, g.acting_role())


func action(k: String) -> Dictionary:
	var t := role_task(k)
	if not t.is_empty():
		return t
	return _base_action(k)


func _send(t: String) -> Callable:
	return func(): g.act("task", {"k": t}, TASKS[t][0])


const UVB := [{"a": 0.0, "b": 0.3, "c": Color("#68386c"), "label": "UV-C 200–280 nm"}, {"a": 0.3, "b": 0.475, "c": Color("#b55088"), "label": "UV-B 280–315 nm"},
	{"a": 0.475, "b": 0.85, "c": Color("#3a4466"), "label": "UV-A 315–400 nm"}, {"a": 0.85, "b": 1.0, "c": Color("#124e89"), "label": "visible"}]


## Minigame for every role (ported from c7.js). {} when nothing here right now.
func role_task(k: String) -> Dictionary:
	var s := S()
	if not s["storm"].is_empty():
		return {}
	var w: String = s["world"]
	var P := WD.PAL
	if w == "earth":
		var st: int = s["step"]
		if st == 1 and k == "shop" and not task_done("cube"):
			return {"label": "BUILD THE PAYLOAD CUBE", "role": "eng", "fn": func(): mg.play("E1", "eng", _send("cube"))}
		if (st == 1 or st == 2) and k == "shop":
			return {"label": "REBUILD THE ROCKET" if task_done("build") else "BUILD THE ROCKET", "role": "eng", "fn": _workshop}
		if st == 1 and k == "ozone" and not task_done("uvcal"):
			return {"label": "STUDY THE OZONE HOLE", "role": "sci", "fn": func(): mg.play("S1", "sci", _send("uvcal"))}
		if st == 1 and k == "nav" and not task_done("wind"):
			return {"label": "PICK LAUNCH HOUR", "role": "nav", "fn": func(): mg.wind("nav", _send("wind"))}
		if st == 1 and k == "comms" and not task_done("tune"):
			return {"label": "PICK THE INSTRUMENTS", "role": "qm", "fn": func(): mg.play("Q1", "qm", _send("tune"))}
		if st == 5:
			if k == "nav" and not task_done("perigee"):
				return {"label": "REACH ORBIT", "role": "nav", "fn": func(): mg.play("N1", "nav", _send("perigee"))}
			if k == "power" and not task_done("cargo"):
				return {"label": "PACK THE CARGO", "role": "qm", "fn": func(): mg.pack("qm", "PACK THE SHUTTLE", "The shuttle can carry 115 kg. Take everything we need on the Moon, and nothing that breaks the limit.",
					[{"n": "Water", "kg": 30, "req": true}, {"n": "Food", "kg": 25, "req": true}, {"n": "Oxygen tanks", "kg": 30, "req": true}, {"n": "Ice drill", "kg": 20, "req": true}, {"n": "Spare radio", "kg": 10}, {"n": "Tool chest", "kg": 25}, {"n": "Books", "kg": 12}],
					115, _send("cargo"), {"fact": "Every kilogram launched costs fuel. Real missions weigh everything."})}
			if k == "pad" and not task_done("bolts"):
				return {"label": "PRE-FLIGHT CHECK", "role": "eng", "fn": func(): mg.timing("eng", "TORQUE THE BOLTS", "Stop the wrench in the green zone to torque each bolt. Four bolts.", [0.4, 0.55], _send("bolts"), {"hits": 4, "random": true, "label": "TIGHTEN", "fact": "Launch vibration shakes loose anything not torqued right."})}
			if k == "ozone" and not task_done("site"):
				return {"label": "PICK LANDING SITE", "role": "sci", "fn": func(): mg.pick("sci", "PICK THE LANDING SITE", "We need ice for fuel and sunlight for power. Where should the outpost land?", [
					{"label": "Equator plain", "sub": "Easy landing", "ok": false, "why": "Sunny, but far too warm for ice to survive.", "draw": func(c, r): c.draw_rect(r, P["steel"]); c.draw_rect(Rect2(116, 6, 18, 18), P["yellow"])},
					{"label": "South pole crater rim", "sub": "Ice next door", "ok": true, "draw": func(c, r): c.draw_rect(r, P["slate"]); c.draw_circle(Vector2(54, 60), 30, Color("#08090c")); c.draw_rect(Rect2(116, 6, 18, 18), P["yellow"]); c.draw_rect(Rect2(48, 60, 12, 9), P["cyan"])},
					{"label": "Inside a deep crater", "sub": "Ice everywhere", "ok": false, "why": "Lots of ice, but no sunlight at all for solar power.", "draw": func(c, r): c.draw_rect(r, Color("#08090c")); c.draw_rect(Rect2(60, 54, 18, 12), P["cyan"])}],
					_send("site"), {"fact": "NASA's Artemis missions target the lunar south pole for exactly this reason."})}
	elif w == "moon":
		var m: int = s["ms"]
		if k == "landing" and m == 0 and not task_done("arrival"):
			return {"label": "ARRIVAL BURN", "role": "nav", "fn": func(): mg.play("N2", "nav", _send("arrival"))}
		if k == "science" and m == 1:
			return {"label": "FIND THE ICE", "role": "sci", "fn": func(): mg.play("S2", "sci", func(): g.act("scan", {"ok": 1}, "sci"))}
		if k == "mine" and m == 3 and not task_done("icescan"):
			return {"label": "ICE SCAN", "role": "eng", "fn": func(): mg.play("E2", "eng", _send("icescan"))}
		if k == "solar" and m == 2 and not task_done("outpost"):
			return {"label": "PACK OUTPOST PAYLOAD", "role": "qm", "fn": func(): mg.play("Q2", "qm", _send("outpost"))}
		if k == "factory" and m == 5 and not s["sats_chosen"] and not task_done("sunscan"):
			return {"label": "SCAN THE SUN'S LIGHT", "role": "sci", "fn": func(): mg.play("S3", "sci", _send("sunscan"))}
		if k == "solar" and m == 2:
			return {"label": "DESIGN OUTPOST POWER", "role": "qm", "fn": func(): dz.moon(func(x):
				if x["cable"] > 0:
					mg.wires("qm", "WIRE THE POWER CABLE", "Now connect the cable: match each wire to the socket of the same colour.", func(): g.act("mpower", x, "qm"))
				else:
					g.act("mpower", x, "qm"))}
		if k == "factory" and m == 5 and not s["sats_chosen"]:
			return {"label": "DESIGN THE SHIELD", "role": "eng", "fn": func(): dz.shield(func(x): g.act("shield", x, "eng"))}
		if k == "fuel" and m == 4:
			return {"label": "SPLIT ICE INTO FUEL", "role": "nav", "fn": func(): mg.sliders("nav", "ICE INTO ROCKET FUEL", "Electricity splits water (H₂O) into hydrogen and oxygen. Set the gas flows so you collect them in the right ratio.",
				[{"label": "Hydrogen flow", "min": 0, "max": 12, "step": 1, "val": 3}, {"label": "Oxygen flow", "min": 0, "max": 12, "step": 1, "val": 3}],
				func(v): var h: float = v[0]; var o: float = v[1]; var ok: bool = o >= 2 and is_equal_approx(h, 2 * o); var q := maxf(0.0, 1.0 - absf(h / o - 2.0) / 2.0) if o > 0 else 0.0; return {"ok": ok, "meter": q, "read": "Ratio H : O = [b]%s : 1[/b]" % ("%.1f" % (h / o) if o > 0 else "–"), "why": "Water has two hydrogen atoms for every oxygen. Match that."},
				func(): g.act("split", {}, "nav"), "Liquid hydrogen and oxygen powered the Space Shuttle's main engines.")}
		if k == "port" and m == 6 and not task_done("l1"):
			return {"label": "HOLD THE SHIELD AT L1", "role": "nav", "fn": func(): mg.play("N3", "nav", _send("l1"))}
		if k == "port" and m == 6 and not task_done("aperture"):
			return {"label": "OPEN THE APERTURE", "role": "eng", "fn": func(): mg.play("E3", "eng", _send("aperture"))}
		if k == "lc" and m == 6 and not task_done("datahome"):
			return {"label": "SEND DATA HOME", "role": "qm", "fn": func(): mg.play("Q3", "qm", _send("datahome"))}
	return {}


func _base_action(k: String) -> Dictionary:
	var s := S()
	match s["world"]:
		"earth":
			var st: int = s["step"]
			if k == "mc" and st == 0:
				return {"label": "OPEN MISSION BOARD", "fn": sui.mission_board}
			if k == "shop" and (st == 1 or st == 2):
				return {"label": "BUILD THE ROCKET", "role": "eng", "fn": _workshop}
			if k == "mc" and st == 2:
				return {"label": "READINESS REVIEW", "fn": func(): g.ui.toast("All four crew must stand on their own consoles in this room at the same time.", 3.2)}
			if k == "pad" and st == 3:
				return {"label": "START COUNTDOWN", "role": "nav", "fn": _act("launch")}
			if k == "mc" and st == 4:
				return {"label": "HEAR THE RESULTS", "fn": _act("outro")}
			if k == "pad" and st == 5:
				return {"label": "BOARD THE SHUTTLE", "fn": func(): g.ui.toast("All four crew: take your seats here at the same time." if all_suited() else "Suits first: the locker is in Crew Quarters.", 3.0)}
		"moon":
			var m: int = s["ms"]
			if not s["storm"].is_empty():
				return {}
			if k == "lc" and m == 0 and not task_done("arrival"):
				return {"label": "CHECK IN", "fn": func(): g.ui.toast("Navigator first: replay the arrival burn at the Landing Pad.", 3.0)}
			if k == "lc" and m == 0:
				return {"label": "CHECK IN", "fn": _act("checkin")}
			if k == "science" and m == 1:
				return {"label": "SCAN FOR ICE", "role": "sci", "fn": func():
					var ch := [{"label": "Sunlit crater rim", "sub": "Warm sunlight all day", "fn": _act("scan", {"ok": 0})},
						{"label": "Shadowed crater floor", "sub": "Never sees the Sun", "fn": _act("scan", {"ok": 1}), "best": true},
						{"label": "Open lava plain", "sub": "Flat and sunny", "fn": _act("scan", {"ok": 0})}]
					ch.shuffle()
					g.ui.choice("WHERE IS THE ICE?", "Three spots on the orbiter map. Pick the one where water ice can survive. Wrong picks cost ozone.", ch)}
			if k == "solar" and m == 2:
				return {"label": "CONNECT CABLE", "role": "qm", "fn": func(): g.ui.task("RUN A POWER CABLE", "Solar only works up here on the rim. The crater is always dark, so we run a cable to the mine.", "CONNECT", 2.0, _act("cable"))}
			if k == "mine" and m == 3:
				return {"label": "DRILL CONTROLS", "fn": func(): g.ui.toast("Engineer on the drill, Scientist on the lamp, at the same time.", 3.0)}
			if k == "fuel" and m == 4:
				return {"label": "SPLIT ICE INTO FUEL", "role": "nav", "fn": func(): g.ui.task("ICE INTO ROCKET FUEL", "Electricity splits water into hydrogen and oxygen: rocket fuel made on the Moon.", "SPLIT", 2.0, _act("split"))}
			if k == "factory" and m == 5 and not s["sats_chosen"]:
				return {"label": "PLAN THE SHIELD", "role": "eng", "fn": func():
					g.ui.choice("HOW MANY SHIELD SATELLITES?", "More satellites block more UV but take longer to build.", [
						{"label": "2 satellites", "sub": "Fast · about 20% cover", "fn": _act("sats", {"n": 2})},
						{"label": "4 satellites", "sub": "Balanced · about 30% cover", "fn": _act("sats", {"n": 4}), "best": true},
						{"label": "6 satellites", "sub": "Slow · about 40% cover", "fn": _act("sats", {"n": 6})}])}
	return {}


## Things to look at when there is nothing to do in a room (no state changes).
## Engineer's rocket workshop. Review mode (F8): a placeholder whose COMPLETE locks the first
## rocket design that meets every requirement.
func _workshop() -> void:
	if not Minigames.review_mode():
		sui.workshop()
		return
	var d := passing_design()
	g.ui.choice("BUILD THE ROCKET", "Engineer's workshop.", [
		{"label": "Lock a working design", "sub": "%s motor%s" % [d["motor"], "".join(["uv", "cam", "chute", "radio"].filter(func(k): return d[k]).map(func(k): return ", " + k))],
			"best": true, "fn": func(): g.act("design", {"d": d}, "eng")}], "ENGINEER TASK")


## The first rocket design (small motor first, fewest parts first) that passes every check.
static func passing_design() -> Dictionary:
	for motor in ["small", "big"]:
		for mask in 16:
			var d := {"motor": motor, "uv": mask & 1 != 0, "cam": mask & 2 != 0, "chute": mask & 4 != 0, "radio": mask & 8 != 0}
			if calc(d)["all"]:
				return d
	return {"motor": "big", "uv": true, "cam": false, "chute": true, "radio": false}


func flavor(k: String) -> Dictionary:
	var s := S()
	var say := func(lines: Array) -> Callable: return func(): g.ui.say(lines)
	match s["world"]:
		"earth":
			var c := calc(s["design"])
			match k:
				"mc": return {"label": "MISSION BOARD", "fn": sui.mission_board}
				"shop": return {"label": "LOOK AT THE ROCKET", "fn": say.call([{"who": "eng", "text": "Nothing to build yet. Pick a mission at Mission Control first." if s["step"] < 1 else "Built and checked. Mass %d kg." % c["kg"]}])}
				"pad": return {"label": "CHECK THE PAD", "fn": say.call([{"who": "nav", "text": "Before we launch anything, we need a pad and a ground station."}, {"who": "eng", "text": "Rusty, but standing. I can work with that."}])}
				"ozone": return {"label": "READ OZONE METER", "fn": func(): g.ui.info("OZONE METER · %d DU" % Designers.du(s["ozone"]), ("Game: [b]%d DU[/b] (%d%% healed) · Healthy layer: [b]%d DU[/b] · Ozone hole: below %d DU · Real record low over the South Pole: [b]%d DU[/b] (%s).\n\n" % [Designers.du(s["ozone"]), s["ozone"], Designers.NASA["ozone"]["normal"], Designers.NASA["ozone"]["hole"], Designers.NASA["ozone"]["low"], Designers.NASA["ozone"]["low_when"]]) + "We need real numbers, not guesses. How much UV is reaching the ground?" if s["step"] < 4 else ("The rocket proved it: UV is far stronger than it should be at every height." if s["ozone"] < 30 else "The shield satellites are working. The meter is climbing."), "Squeeze all of Earth's ozone to sea-level pressure and the layer is only about 3 mm thick.")}
				"comms": return {"label": "TRY THE RADIO", "fn": func(): g.ui.info("NETWORK: OFFLINE", "Every bunker is alone. Nobody can go outside to fix the towers.\n\n[color=#feae34]QUARTERMASTER:[/color] One day a relay satellite could link every bunker again.")}
				"nav": return {"label": "PLOT THE COURSE", "fn": say.call([{"who": "nav", "text": "Height = motor push ÷ total mass. Our rocket weighs %d kg and reaches %d km." % [c["kg"], c["alt"]]}, {"who": "nav", "text": "That clears the 100 km line." if c["ok"]["alt"] else "We need 100 km. Lighter rocket, or a bigger motor."}])}
				"power": return {"label": "CHECK SUPPLIES", "fn": say.call([{"who": "qm", "text": "Budget: %d credits. The rocket design costs %d." % [BUDGET, c["cr"]]}, {"who": "qm", "text": "Inside budget. Keep it that way." if c["ok"]["budget"] else "We are over. Something has to come off."}])}
				"crew": return {"label": "TALK TO THE CREW", "fn": say.call([{"who": "qm", "text": "How long was I out?"}, {"who": "ceres", "text": "Long enough. You four are the only ones who can still work."}, {"who": "nav", "text": "There is an old spaceport a few kilometers away."}, {"who": "eng", "text": "Rusty, but standing. I can work with that."}])}
				"med": return {"label": "GET CHECKED", "fn": func():
					g.heal(g.camera.target)
					g.ui.say([{"who": "ceres", "text": "UV exposure cleared. Keep surface trips short, or wear a suit."}])}
				"airlock": return {"label": "LOOK THROUGH PERISCOPE", "fn": func(): g.ui.info("UV INDEX: EXTREME", "A gamma-ray burst destroyed the ozone layer. Deadly UV now covers the surface.")}
				"canopy": return {"label": "REST IN THE SHADE", "fn": func(): g.ui.toast("A shady spot on the way to the pad. Keep surface trips short.")}
				"hydro": return {"label": "CHECK THE CROPS", "fn": say.call([{"who": "sci", "text": "Fresh food, grown underground under LED lights."}])}
		"moon":
			var m: int = s["ms"]
			match k:
				"lc": return {"label": "CHECK STATUS", "fn": say.call([{"who": "ceres", "text": "Ozone meter: %d%%." % s["ozone"]}])}
				"landing": return {"label": "INSPECT THE LANDER", "fn": say.call([{"who": "eng", "text": "The lander that brought us. One-sixth gravity made the touchdown gentle."}])}
				"tele": return {"label": "LOOK THROUGH TELESCOPE", "fn": func(): g.ui.info("TELESCOPE", "Storm Watch is keeping an eye on the Sun.", "Mirrors left by Apollo show the Moon drifting away by about 3.8 cm a year.")}
				"science": return {"label": "USE THE MICROSCOPE", "fn": func(): g.ui.info("SCIENCE LAB", "Ice grains from the crater, frozen for millions of years." if m >= 2 else "Samples waiting. First, where is the ice?", "Some south-pole craters never see sunlight.")}
				"solar": return {"label": "CHECK THE PANELS", "fn": say.call([{"who": "qm", "text": "Full sunlight up here on the rim. Power is positive."}])}
				"mine": return {"label": "LOOK AROUND", "fn": say.call([{"who": "eng", "text": "No power down here yet. We need a cable from the Solar Ridge." if m < 3 else "The drill is quiet. We have the ice."}])}
				"fuel": return {"label": "CHECK FUEL TANKS", "fn": say.call([{"who": "nav", "text": "Tanks full. Launching from here takes far less fuel than from Earth." if m >= 5 else "Empty tanks. We need ice first."}])}
				"shelter": return {"label": "ENTER SHELTER", "fn": func(): g.ui.info("RADIATION SHELTER", "Water walls soak up radiation during solar storms.", "Apollo astronauts left 96 bags of their own waste on the Moon.")}
				"factory": return {"label": "INSPECT THE FACTORY", "fn": say.call([{"who": "eng", "text": "The factory comes online in Act 3, once we have fuel." if m < 5 else "The line is quiet. The satellites are built."}])}
				"port": return {"label": "INSPECT THE PORT", "fn": func(): g.ui.info("MOON PORT", "From here every launch needs a fraction of the fuel it would from Earth.", "You weigh only one-sixth as much on the Moon.")}
				"teleop": return {"label": "CHECK THE CONSOLES", "fn": say.call([{"who": "ceres", "text": "Remote-control consoles. One day they could drive robots on other worlds."}])}
				"purifier": return {"label": "CHECK THE FILTERS", "fn": say.call([{"who": "sci", "text": "Filters and a UV-C lamp recycle every drop, like on the space station."}])}
	return {}


# ---------------------------------------------------------------- effects (host only)

func do_effect(id: String, p: Dictionary, r: String) -> void:
	var s := S()
	match id:
		"shield":
			if s["world"] == "moon" and s["ms"] == 5 and not s["sats_chosen"]:
				var sh := {"n": clampi(int(p.get("n", 4)), 1, 6), "h": clampi(int(p.get("h", 0)), 0, 6), "big": 1 if int(p.get("big", 0)) > 0 else 0}
				sh["h"] = mini(sh["h"], sh["n"])
				if not Designers.shield_calc(sh)["ok"]:
					return
				s["shield"] = sh
				s["sats"] = sh["n"]
				s["sats_chosen"] = true
				g.say_all([{"who": "eng", "text": "%d satellites, %d hardened%s. Quartermaster, feed me metal at the factory. Hold your station." % [sh["n"], sh["h"], ", large panels" if sh["big"] else ""]}])
		"mpower":
			if s["world"] == "moon" and s["ms"] == 2:
				_moon_power(p)
		"rcont":
			if not s["report"].is_empty() and s["report"]["id"] == p.get("id"):
				var key: String = s["report"]["key"]
				s["report"] = {}
				if key == "shield":
					_fly_home()
		"rretry":
			if not s["report"].is_empty() and s["report"]["id"] == p.get("id"):
				var R: Dictionary = s["report"]
				s["report"] = {}
				_retry(R)
		"task":
			var t: String = p.get("k", "")
			if TASKS.has(t) and not task_done(t):
				var T: Array = TASKS[t]
				if T[1] == s["world"] and int(s[T[2]]) == T[3]:
					s["tasks"][t] = true
					g.say_all([{"who": T[0], "text": T[4]}])
					_after_task()
		"pick":
			if s["step"] == 0:
				s["step"] = 1
				g.say_all([{"who": "ceres", "text": "Mission 1.1: a sounding rocket. Engineer, the Workshop is yours."}])
		"design":
			if s["world"] == "earth" and (s["step"] == 1 or s["step"] == 2) and p.has("d"):
				var d: Dictionary = p["d"]
				s["design"] = {"motor": "big" if d.get("motor") == "big" else "small", "uv": bool(d.get("uv")), "cam": bool(d.get("cam")), "chute": bool(d.get("chute")), "radio": bool(d.get("radio"))}
				s["tasks"]["build"] = true
				g.say_all([{"who": "eng", "text": "Rocket design locked."}])
				_after_task()
		"launch":
			if s["step"] == 3:
				s["event"] = ""
				s["result"] = {}
				set_scene("launch")
				return
		"evt":
			if s["scene"] == "launch" and s["event"] == "" and (p.get("k") == "safe" or p.get("k") == "keep"):
				s["event"] = p["k"]
		"report":
			if s["scene"] == "report":
				if p.get("c") == "redesign":
					s["step"] = 1
					s["tasks"]["build"] = false
				else:
					s["step"] = 4
					s["ozone"] = maxi(s["ozone"], 10)
				set_scene("game")
				return
		"outro":
			if s["step"] == 4:
				s["step"] = 5
				g.say_all([{"who": "sci", "text": "Real numbers at last: UV is far stronger than it should be, at every height."},
					{"who": "eng", "text": "Lifting heavy satellites against Earth's gravity costs too much fuel."},
					{"who": "ceres", "text": "Then don't build it here. Build it where leaving is easy."},
					{"who": "nav", "text": "The Moon. All four of us: suit up in Crew Quarters, then to the Launch Pad."}])
		"checkin":
			if s["ms"] == 0:
				s["ms"] = 1
				g.say_all([{"who": "ceres", "text": "Welcome to the lunar south pole. One-sixth gravity, no air, no magnetic field."}, {"who": "sci", "text": "Near the pole there are craters the Sun never touches. If there is ice, it is there."}])
		"scan":
			if s["ms"] == 1:
				if int(p.get("ok", 0)):
					s["ms"] = 2
					g.say_all([{"who": "sci", "text": "Neutron readings spike: water ice in the shadowed crater!"}, {"who": "qm", "text": "Then I need to run power down there. Solar won't reach it."}])
				else:
					s["ozone"] = maxi(0, s["ozone"] - 1)
					s["pen"] += 1
					g.say_all([{"who": "sci", "text": "Wrong spot. Sunlight would have boiled any ice away. Orbiter time wasted: −1% ozone."}])
		"cable":
			if s["ms"] == 2:
				s["ms"] = 3
				g.say_all([{"who": "qm", "text": "Power is flowing. Engineer on the drill, Scientist on the lamp. It is dark and freezing down there."}])
		"split":
			if s["ms"] == 4 and s["storm"].is_empty():
				s["storm"] = {"kind": "solar", "t": 25.0}
				g.say_all([{"who": "ceres", "text": "Warning! Solar particle storm incoming!"}, {"who": "ceres", "text": "All four of you into the Radiation Shelter. Now!"}])
		"sats":
			var n := int(p.get("n", 0))
			if s["ms"] == 5 and n in [2, 4, 6]:
				s["sats"] = n
				s["sats_chosen"] = true
				g.say_all([{"who": "eng", "text": "%d satellites. Quartermaster, feed me metal at the factory. Hold your station." % n}])
		"skip":
			if s["scene"] == "travel":
				finish_travel()
			return
		"freeroam":
			if s["scene"] == "ending":
				s["world"] = "earth"
				s["step"] = 6
				s["suits"] = {}
				set_scene("game")
				return
		"again":
			if s["scene"] == "ending":
				var keep_time: float = s["time"]
				g.S = g.fresh_state()
				g.S["time"] = keep_time
				g.commit()
				return
		_:
			return
	g.commit()


func _moon_power(p: Dictionary) -> void:
	var s := S()
	var mp := {"site": "floor" if p.get("site") == "floor" else "rim", "solar": int(p.get("solar", 0)), "cable": int(p.get("cable", 0)), "rtg": int(p.get("rtg", 0)), "bat": int(p.get("bat", 0))}
	var c := Designers.moon_calc(mp)
	if not c["ok"]:
		return
	s["mpower"] = mp
	s["ms"] = 3
	var ok: bool = c["survives"]
	if not ok:
		s["pen"] += 1
		s["ozone"] = maxi(0, s["ozone"] - 1)
	var parts := []
	for kv in [["solar", " solar"], ["rtg", " RTG"], ["bat", " battery"]]:
		if mp[kv[0]] > 0:
			parts.append(str(mp[kv[0]]) + kv[1])
	if mp["cable"] > 0:
		parts.append("cable")
	var N: Dictionary = Designers.NASA
	post_report({"key": "mpower", "name": "OUTPOST POWER", "stars": (3 if c["cr"] <= Designers.MPOW["budget"] - 30 else 2) if ok else 1, "retry": "mpower", "penalty": 0 if ok else 1,
		"chose": "%s: %s (%d cr, %d kg)" % ["Outpost on the rim" if mp["site"] == "rim" else "Outpost on the crater floor", ", ".join(parts), c["cr"], c["kg"]],
		"result": "%d power units at the ice. A micrometeorite then %s: %s" % [c["at_ice"], "cut the cable" if c["via_cable"] > 0 else "hit the outpost", "[color=#63c74d]drilling kept going ✓[/color]" if ok else "[color=#f6757a]power dropped to %d units, drilling slowed (−1%% ozone) ![/color]" % (c["at_ice"] - c["via_cable"])],
		"why": "Your power did not depend on a single cable, so the hit changed nothing." if c["via_cable"] == 0 else ("The battery covered the drill while the cable was repaired." if mp["bat"] > 0 else "Everything ran through one cable with no backup. A battery would have covered the gap."),
		"real": "NASA's Artemis III targets the lunar south pole; Curiosity and Perseverance run on an MMRTG nuclear battery.",
		"data": "LRO's LOLA maps show the Shackleton crater rim in sunlight about [b]%s%%[/b] of the time, while LRO's Diviner measured permanently shadowed crater floors near [b]%d K[/b] (about −236 °C). A real MMRTG makes about [b]%d W[/b] and weighs %d kg. [color=#8b9bb4](%s)[/color]" % [str(N["moon"]["rim"]), N["moon"]["cold"], N["rtg"]["w"], N["rtg"]["kg"], N["moon"]["src"]]})
	g.say_all([{"who": "qm", "text": "Power is flowing. Engineer on the drill, Scientist on the lamp. It is dark and freezing down there."}])


## Store a mission report for every screen (stars also count toward the ending).
func post_report(R: Dictionary) -> void:
	R["id"] = Time.get_ticks_msec() + randi() % 1000
	g.S["report"] = R
	g.S["stars"][R["key"]] = maxi(int(g.S["stars"].get(R["key"], 0)), int(R["stars"]))


## TRY ANOTHER DESIGN: rewind to the designer and undo what the last design did.
func _retry(R: Dictionary) -> void:
	var s := S()
	s["ozone"] = clampi(s["ozone"] - int(R.get("gain", 0)) + int(R.get("penalty", 0)), 0, 100)
	match R["retry"]:
		"mpower":
			s["ms"] = 2
			s["mpower"] = {}
			g.say_all([{"who": "ceres", "text": "Back to the drawing board. Quartermaster: redesign the outpost power at the Solar Ridge."}])
		"shield":
			s["world"] = "moon"
			s["ms"] = 5
			s["sats_chosen"] = false
			s["tasks"]["l1"] = false
			s["shield"] = {}
			s["time"] -= TRIP_DAYS["shield"] * 1440
			g.say_all([{"who": "ceres", "text": "Simulation reset. Engineer: redesign the shield at the Moon Factory."}])

## Act 3: the shield launches when the Navigator, Engineer and Quartermaster jobs are done.
func _launch_ready() -> bool:
	return task_done("l1") and task_done("aperture") and task_done("datahome")

## A role task was finished (the workshop counts as one): move on when Act 1 prep is done.
func _after_task() -> void:
	var s := S()
	if s["world"] == "earth" and s["step"] == 1 and prep_done("e1"):
		s["step"] = 2
		g.say_all([{"who": "ceres", "text": "Launch prep complete. Readiness review: all four of you, stand on your consoles in Mission Control."}])
	elif s["world"] == "earth" and s["step"] == 5 and prep_done("e5") and not all_suited():
		g.say_all([{"who": "ceres", "text": "Trip prep complete. Everyone: spacesuits from the locker in Crew Quarters, then board at the Launch Pad."}])
	elif s["world"] == "moon" and s["ms"] == 6 and _launch_ready():
		g.say_all([{"who": "ceres", "text": "All four: take your launch seats at the Moon Port."}])


func on_suit(_r: String) -> void:
	if g.S["world"] == "earth" and g.S["step"] == 5 and all_suited():
		g.say_all([{"who": "ceres", "text": "All four suits sealed. Now board the shuttle at the Launch Pad."}])


func set_scene(sc: String) -> void:
	g.S["scene"] = sc
	_scene_t = 0.0
	g.commit()


func _finish_poll() -> void:
	var s := S()
	var votes: Array = poll_votes()
	if votes.all(func(v): return v[1]):
		s["step"] = 3
		g.say_all([{"who": "ceres", "text": "All four say GO. Navigator: start the countdown at the Launch Pad. Mind the UV out there."}])
	else:
		var b: Array = votes.filter(func(v): return not v[1])[0]
		s["step"] = 1
		s["tasks"]["build"] = false
		g.say_all([{"who": b[0], "text": "NO-GO. " + b[2]}, {"who": "ceres", "text": "Engineer: back to the Workshop. Then all four of you run the review again."}])
	set_scene("game")


## [[role, go?, reason], ...] for the readiness review.
func poll_votes() -> Array:
	var c := calc(S()["design"])
	return [["eng", true, "Mass is fine for the pad."], ["sci", c["ok"]["uv"], "No UV sensor on board."],
		["nav", c["ok"]["alt"], "Only %d km. We need 100." % c["alt"]],
		["qm", c["ok"]["rec"] and c["ok"]["budget"], "No parachute or radio: the data never comes back." if c["ok"]["budget"] else "Over budget by %d credits." % (c["cr"] - BUDGET)]]


func build_result() -> Dictionary:
	var s := S()
	var c := calc(s["design"])
	var safe: bool = s["event"] != "keep"
	var mot: String = PARTS[s["design"]["motor"]]["name"].to_lower()
	var why := ["Your %s pushed %d kg up to %d km." % [mot, c["kg"], c["alt"]],
		"Safe mode protected the UV sensor: only a few readings were lost." if safe else "The UV storm scrambled half the readings. Safe mode would have saved them.",
		"The parachute brought the sensor home." if s["design"]["chute"] else "The radio sent the readings down during the flight."]
	if s["design"]["cam"]:
		why.append("The camera added weight but no ozone data.")
	var score := maxi(0, (((880 if c["cr"] <= 130 else 820) if safe else 610)) - s["pen"] * 40)
	return {"success": safe, "data": 85 if safe else 45, "score": score, "why": why, "kg": c["kg"], "alt": c["alt"], "cr": c["cr"]}


func travel(cut: Dictionary) -> void:
	var d: int = TRIP_DAYS.get(cut.get("kind", ""), 0)
	cut["days"] = d
	g.S["time"] += d * 1440
	g.S["cut"] = cut
	set_scene("travel")


func finish_travel() -> void:
	var s := S()
	if s["scene"] != "travel" or s["cut"].is_empty():
		return
	var a: String = s["cut"].get("after", "")
	s["cut"] = {}
	match a:
		"moon":
			s["world"] = "moon"
			s["ms"] = 0
			s["suits"] = {}
			s["scene"] = "game"
			g.say_all([{"who": "ceres", "text": "Touchdown at the lunar south pole. Navigator: log the arrival burn at the Landing Pad. Then anyone checks in at Lunar Control."}, {"who": "qm", "text": "Suits stowed at the Landing Pad. Inside the outpost we work in uniform again."}])
		"shield":
			_shield_result()
		"home":
			_land_on_earth()
	_scene_t = 0.0
	g.commit()


## After the shield report: all four fly back from the Moon to Earth.
func _fly_home() -> void:
	g.say_all([{"who": "ceres", "text": "The shield holds. Our work up here is done."}, {"who": "nav", "text": "Course plotted for Earth. Three days home."}])
	travel({"kind": "home", "from": "moon", "to": "earth", "title": "HOMECOMING", "sub": "The crew flies back to Earth under a healing sky", "after": "home"})


## The capsule lands next to Bunker 4: the shield keeps working while the ozone heals → happy ending.
func _land_on_earth() -> void:
	var s := S()
	s["ozone"] = mini(100, s["ozone"] + 35)
	s["world"] = "earth"
	s["step"] = 6
	s["suits"] = {}
	s["scene"] = "ending"


func _shield_result() -> void:
	var s := S()
	var sh: Dictionary = s["shield"] if not s["shield"].is_empty() else {"n": s["sats"], "h": s["sats"], "big": 1}
	var c := Designers.shield_calc(sh)
	var ok: bool = c["after"] >= Designers.SHIELD["need"]
	var gain := roundi(c["after"] * 0.42)
	s["ozone"] = mini(100, s["ozone"] + gain)
	s["ms"] = 7
	s["scene"] = "game"
	var lost_txt := ("%d unhardened satellite%s failed." % [c["lost"], "s" if c["lost"] > 1 else ""]) if c["lost"] > 0 else "Every satellite survived."
	g.say_all([{"who": "ceres", "text": "Solar storm hit the shield! %s Coverage %d%%." % [lost_txt, c["after"]]}])
	var N: Dictionary = Designers.NASA
	post_report({"key": "shield", "name": "SHIELD SATELLITES", "gain": gain, "retry": "shield",
		"stars": 1 if not ok else (3 if c["lost"] == 0 else (2 if c["cost"] <= Designers.SHIELD["budget"] - 30 else 1)),
		"chose": "%d satellites, %d hardened, %s panels (%d cr)" % [sh["n"], sh["h"], "large" if sh["big"] else "small", c["cost"]],
		"result": "Coverage %d%% → %d%% after the storm %s · ozone +%d%%" % [c["cov"], c["after"], "[color=#63c74d]✓ shield holds[/color]" if ok else "[color=#f6757a]✗ below the 60% the bunkers need[/color]", gain],
		"why": ("Unhardened electronics failed in the radiation: %d of %d unprotected satellites lost." % [c["lost"], sh["n"] - sh["h"]]) if c["lost"] > 0 else "Hardening protected the electronics from the solar storm. Fewer satellites, but tougher ones.",
		"real": "NASA's Solar Dynamics Observatory watches the Sun; spacecraft beyond Earth use radiation-hardened parts.",
		"data": "The %s was %s. [color=#8b9bb4](%s)[/color]" % [N["storm"]["name"], N["storm"]["text"], N["storm"]["src"]]})


# ---------------------------------------------------------------- screens follow the shared scene

func on_state(old_scene: String, _old_world: String) -> void:
	var sc: String = g.S["scene"]
	if sc != old_scene:
		sui.show_scene(sc)
	elif sc == "launch":
		sui.launch_state()


## For the mission panel: [{role ("" = anyone), what, room}]
func work_list() -> Array:
	var out := []
	var h := hold()
	for r in h.get("need", {}):
		out.append({"role": r, "what": "stand on your spot" + (" (done)" if g.on_spot(r, h["need"][r][0], h["need"][r][1]) else ""), "room": h["need"][r][0]})
	var w: String = g.S["world"]
	for id in WD.rooms():
		if WD.world_of(id) != w or g.is_locked(id):
			continue
		var a := action(WD.key_of(id))
		if not a.is_empty() and not String(a["label"]).begins_with("BOARD") and not String(a["label"]).begins_with("READINESS") and a["label"] != "DRILL CONTROLS":
			out.append({"role": a.get("role", ""), "what": a["label"], "room": id})
	if w == "earth" and g.S["step"] == 5:
		for r in ROLES:
			if not g.S["suits"].get(r, false):
				out.append({"role": r, "what": "PUT ON SPACESUIT", "room": "earth.crew"})
	return out
