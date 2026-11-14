extends RefCounted
## Mission designers (shield satellites, Moon outpost power, Mars greenhouse power), the NASA numbers
## that decide pass or fail, and the mission report shown after every mission.
## Owner: Sufi (gameplay). Same rules as the HTML demo (web/demo, c11.js). Sources: docs/SOURCES.md.

const RoleSprites := preload("res://game/player/role_sprites.gd")

## Real NASA values used by the game. Dino: check these against the sources before submitting.
const NASA := {
	"ozone": {"normal": 300, "hole": 220, "low": 92, "low_when": "October 2006, over the South Pole", "src": "NASA Ozone Watch / NASA Earth Observatory"},
	"storm": {"name": "Gannon storm, 10 May 2024", "text": "the first G5 geomagnetic storm in over 20 years. NASA's ICESat-2 dropped into safe mode, the CIRBE CubeSat came down early, and thousands of satellites had to adjust their orbits", "src": "NASA Science"},
	"moon": {"rim": 85.5, "cold": 37, "src": "LRO (LOLA illumination study; Diviner temperatures)"},
	"mars": {"tau": 10.8, "tau_normal": 0.5, "wh_before": 645, "wh_after": 22, "src": "NASA JPL Opportunity status reports, June 2018"},
	"rtg": {"w": 110, "kg": 45, "src": "NASA MMRTG fact sheet"},
}
const SHIELD := {"budget": 300, "sat": 40, "hard": 15, "panel": 10, "per": 15, "need": 60}
const MPOW := {"budget": 150, "mass": 120, "need": 3, "solar": {"cr": 30, "kg": 20, "u": 3}, "cable": {"cr": 25, "kg": 40}, "rtg": {"cr": 90, "kg": 45, "u": 2}, "bat": {"cr": 20, "kg": 25, "u": 2}}
const GPOW := {"budget": 200, "days": 3, "solar": {"cr": 20, "clear": 1.0, "storm": 0.05}, "bat": {"cr": 25, "u": 3}, "rtg": {"cr": 100, "u": 1}, "ins": {"cr": 15}, "heater": 2, "lights": 1}

var g          ## dawn.gd


## Game ozone % → Dobson Units: 0% = the real record low, 100% = a healthy layer.
static func du(ozone: float) -> int:
	return roundi(NASA["ozone"]["low"] + (NASA["ozone"]["normal"] - NASA["ozone"]["low"]) * ozone / 100.0)


# ---------------------------------------------------------------- rules (pure, tested)

static func shield_calc(s: Dictionary) -> Dictionary:
	var n: int = s["n"]
	var h: int = mini(s["h"], n)
	var big: bool = s["big"] > 0
	var cost: int = n * SHIELD["sat"] + h * SHIELD["hard"] + (n * SHIELD["panel"] if big else 0)
	var f := 1.0 if big else 0.8
	var cov := mini(90, roundi(n * SHIELD["per"] * f))
	var lost := ceili((n - h) / 2.0)
	var after := mini(90, roundi((n - lost) * SHIELD["per"] * f))
	var hint := ""
	if cost > SHIELD["budget"]:
		hint = "Over budget by %d credits." % (cost - SHIELD["budget"])
	elif cov < SHIELD["need"]:
		hint = "Coverage at %d%%. We need %d to protect the bunkers." % [cov, SHIELD["need"]]
	elif h < n:
		hint = "Space weather forecast shows a storm. Unshielded electronics may not survive. Hardened satellites cost more but keep working."
	else:
		hint = "Coverage %d%%, every satellite hardened. That shield should hold." % cov
	return {"cost": cost, "cov": cov, "lost": lost, "after": after, "ok": cost <= SHIELD["budget"] and cov >= SHIELD["need"] and n > 0, "hint": hint,
		"gauges": [["COST", "%d / %d cr" % [cost, SHIELD["budget"]], cost <= SHIELD["budget"]], ["COVERAGE", "%d%%" % cov, cov >= SHIELD["need"]], ["HARDENED", "%d of %d" % [h, n], h >= n]]}


static func moon_calc(s: Dictionary) -> Dictionary:
	var cr: int = s["solar"] * MPOW["solar"]["cr"] + s["cable"] * MPOW["cable"]["cr"] + s["rtg"] * MPOW["rtg"]["cr"] + s["bat"] * MPOW["bat"]["cr"]
	var kg: int = s["solar"] * MPOW["solar"]["kg"] + s["cable"] * MPOW["cable"]["kg"] + s["rtg"] * MPOW["rtg"]["kg"] + s["bat"] * MPOW["bat"]["kg"]
	var floor_site: bool = s["site"] == "floor"
	# Solar arrays always stand on the sunlit rim; their power reaches the ice only through the cable.
	# The RTG stands with the outpost: on the floor it is next to the ice, on the rim it needs the cable too.
	var solar_at_ice: int = s["solar"] * MPOW["solar"]["u"] if s["cable"] > 0 else 0
	var rtg_at_ice: int = s["rtg"] * MPOW["rtg"]["u"] if (floor_site or s["cable"] > 0) else 0
	var at_ice := solar_at_ice + rtg_at_ice
	var via_cable := (solar_at_ice + (0 if floor_site else rtg_at_ice)) if s["cable"] > 0 else 0
	var survives: bool = via_cable == 0 or s["bat"] > 0
	var hint := ""
	if s["solar"] > 0 and s["cable"] == 0:
		hint = "Solar arrays only work on the sunlit rim (lit about %s%% of the time). The ice is 2 km away in the dark: without a cable their power never reaches it." % NASA["moon"]["rim"]
	elif not floor_site and s["rtg"] > 0 and s["cable"] == 0:
		hint = "The RTG is up on the rim with the outpost. Without a cable its power stays there."
	elif at_ice < MPOW["need"]:
		hint = "Only %d power units reach the ice. The drill and heater need %d." % [at_ice, MPOW["need"]]
	elif cr > MPOW["budget"]:
		hint = "Over budget by %d credits.%s" % [cr - MPOW["budget"], " Plutonium is rare and expensive." if s["rtg"] > 1 else ""]
	elif kg > MPOW["mass"]:
		hint = "%d kg over the lander limit." % (kg - MPOW["mass"])
	elif not survives:
		hint = "It works. But everything depends on one cable. A battery would cover us if it breaks."
	else:
		hint = "Power design holds. Lock it in."
	return {"cr": cr, "kg": kg, "at_ice": at_ice, "via_cable": via_cable, "survives": survives, "ok": at_ice >= MPOW["need"] and cr <= MPOW["budget"] and kg <= MPOW["mass"], "hint": hint,
		"gauges": [["POWER AT ICE", "%d / %d" % [at_ice, MPOW["need"]], at_ice >= MPOW["need"]], ["COST", "%d / %d cr" % [cr, MPOW["budget"]], cr <= MPOW["budget"]], ["MASS", "%d / %d kg" % [kg, MPOW["mass"]], kg <= MPOW["mass"]]]}


static func mars_calc(s: Dictionary) -> Dictionary:
	var cr: int = s["solar"] * GPOW["solar"]["cr"] + s["bat"] * GPOW["bat"]["cr"] + s["rtg"] * GPOW["rtg"]["cr"] + s["ins"] * GPOW["ins"]["cr"]
	var need: int = GPOW["heater"] - (1 if s["ins"] > 0 else 0) + GPOW["lights"]
	var clear: float = s["solar"] * GPOW["solar"]["clear"] + s["rtg"] * GPOW["rtg"]["u"]
	var store: float = s["bat"] * GPOW["bat"]["u"]
	var days := 0
	for d in GPOW["days"]:
		var prod: float = s["solar"] * GPOW["solar"]["storm"] + s["rtg"] * GPOW["rtg"]["u"]
		var deficit := maxf(0.0, need - prod)
		if deficit <= store + 1e-9:
			store -= deficit
			days += 1
		else:
			break
	var hint := ""
	if cr > GPOW["budget"]:
		hint = "Over budget by %d credits." % (cr - GPOW["budget"])
	elif clear < need:
		hint = "On a clear day we make %s units. The greenhouse needs %d." % [str(snappedf(clear, 0.01)), need]
	elif s["rtg"] == 0 and s["bat"] == 0:
		hint = "All solar. A dust storm blocks most sunlight: Opportunity dropped from %d to %d watt-hours a day in 2018." % [NASA["mars"]["wh_before"], NASA["mars"]["wh_after"]]
	elif days < GPOW["days"]:
		hint = "In a %d-day storm this lasts about %d day%s. Think about what still works when the sky goes dark." % [GPOW["days"], days, "" if days == 1 else "s"]
	else:
		hint = "This design keeps the heaters on through a 3-day storm. Lock it in."
	return {"cr": cr, "need": need, "clear": clear, "days": days, "ok": cr <= GPOW["budget"] and clear >= need, "hint": hint,
		"gauges": [["COST", "%d / %d cr" % [cr, GPOW["budget"]], cr <= GPOW["budget"]], ["CLEAR DAY", "%s / %d units" % [str(snappedf(clear, 0.01)), need], clear >= need], ["STORM DAYS", "%d / %d" % [days, GPOW["days"]], days >= GPOW["days"]]]}


# ---------------------------------------------------------------- designer panel

## rows: [{key, label, sub, min, max}] steppers or [{type:"choice", key, label, options:[{v,label,sub}]}]
func panel(role: String, title: String, text: String, state: Dictionary, rows: Array, compute: Callable, btn: String, on_lock: Callable) -> void:
	var box: VBoxContainer = g.ui.panel(Color("#262b44"), RoleSprites.TAGS[role], 900, 30)
	g.ui.title(box, "%s · MISSION DESIGNER" % RoleSprites.NAMES[role], RoleSprites.TAGS[role], 11)
	g.ui.title(box, title)
	g.ui.rich(box, text, 17)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	box.add_child(body)
	var gauges := HBoxContainer.new()
	gauges.add_theme_constant_override("separation", 30)
	box.add_child(gauges)
	var ceres: RichTextLabel = g.ui.rich(box, "", 17)
	var foot: HBoxContainer = g.ui.row(box)
	var lock: Button = g.ui.button(foot, btn + "  ▸▸", func():
		var r: Dictionary = compute.call(state)
		if r["ok"]:
			g.ui.close_panel()
			on_lock.call(state.duplicate()))
	g.ui.button(foot, "LATER", g.ui.close_panel, false)
	var draw := func(draw_self: Callable) -> void:
		for c in body.get_children():
			c.queue_free()
		for rw in rows:
			if rw.get("type", "") == "choice":
				g.ui.title(body, rw["label"], Color("#8b9bb4"), 10)
				var seg: HBoxContainer = g.ui.row(body)
				for op in rw["options"]:
					var b := Button.new()
					b.theme_type_variation = "" if state[rw["key"]] == op["v"] else "GhostButton"
					b.text = op["label"] + "\n" + op.get("sub", "")
					b.add_theme_font_override("font", DawnTheme.body_font())
					b.add_theme_font_size_override("font_size", 18)
					b.custom_minimum_size = Vector2(410, 64)
					b.pressed.connect(func():
						state[rw["key"]] = op["v"]
						draw_self.call(draw_self))
					seg.add_child(b)
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			var lab := RichTextLabel.new()
			lab.bbcode_enabled = true
			lab.fit_content = true
			lab.scroll_active = false
			lab.custom_minimum_size = Vector2(620, 0)
			lab.add_theme_font_size_override("normal_font_size", 19)
			lab.text = "%s\n[color=#8b9bb4][font_size=15]%s[/font_size][/color]" % [rw["label"], rw.get("sub", "")]
			row.add_child(lab)
			var key: String = rw["key"]
			var minus: Button = g.ui.button(row, "−", func():
				state[key] = maxi(rw.get("min", 0), state[key] - 1)
				draw_self.call(draw_self), false)
			minus.custom_minimum_size = Vector2(46, 40)
			var n := Label.new()
			n.text = ("YES" if state[key] > 0 else "NO") if rw["max"] == 1 else str(state[key])
			n.custom_minimum_size = Vector2(60, 0)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			n.add_theme_font_override("font", DawnTheme.title_font())
			n.add_theme_font_size_override("font_size", 14)
			n.add_theme_color_override("font_color", Color("#fee761"))
			row.add_child(n)
			var plus: Button = g.ui.button(row, "+", func():
				state[key] = mini(rw["max"], state[key] + 1)
				draw_self.call(draw_self), false)
			plus.custom_minimum_size = Vector2(46, 40)
			body.add_child(row)
		var r: Dictionary = compute.call(state)
		for c in gauges.get_children():
			c.queue_free()
		for gg in r["gauges"]:
			var col := VBoxContainer.new()
			col.custom_minimum_size = Vector2(220, 0)
			g.ui.title(col, gg[0], Color("#c0cbdc"), 10)
			var v := Label.new()
			v.text = gg[1]
			v.add_theme_font_size_override("font_size", 24)
			v.add_theme_color_override("font_color", Color("#63c74d") if gg[2] == true else (Color("#f6757a") if gg[2] == false else Color.WHITE))
			col.add_child(v)
			gauges.add_child(col)
		ceres.text = "[color=#2ce8f5][b]CERES[/b][/color]  " + r["hint"]
		lock.disabled = not r["ok"]
	draw.call(draw)
	lock.grab_focus.call_deferred()


func shield(on_lock: Callable) -> void:
	var st := {"n": 4, "h": 0, "big": 0}
	panel("eng", "DESIGN THE SHIELD", "Shade the hole in the ozone layer from the L1 point. Each satellite covers %d%% (80%% of that with small panels). You need [color=#2ce8f5]%d%% coverage after a solar storm[/color]." % [SHIELD["per"], SHIELD["need"]], st,
		[{"key": "n", "label": "Shield satellites", "sub": "%d cr each · +%d%% coverage" % [SHIELD["sat"], SHIELD["per"]], "min": 1, "max": 6},
		{"key": "h", "label": "Radiation hardening", "sub": "+%d cr per satellite · survives the storm" % SHIELD["hard"], "min": 0, "max": 6},
		{"key": "big", "label": "Large solar panels", "sub": "+%d cr per satellite · full strength" % SHIELD["panel"], "min": 0, "max": 1}],
		func(x): x["h"] = mini(x["h"], x["n"]); return shield_calc(x), "BUILD THE SHIELD", on_lock)


func moon(on_lock: Callable) -> void:
	var st := {"site": "rim", "solar": 1, "cable": 0, "rtg": 0, "bat": 0}
	panel("qm", "POWER THE ICE OUTPOST", "The ice sits in a crater floor that never sees sunlight. The rim is sunlit about %s%% of the time. Get [color=#2ce8f5]%d power units to the ice[/color] (drill 2 + heater 1)." % [NASA["moon"]["rim"], MPOW["need"]], st,
		[{"type": "choice", "key": "site", "label": "WHERE DOES THE OUTPOST (AND ITS RTG) STAND?", "options": [{"v": "rim", "label": "Crater rim", "sub": "Near-constant sunlight · ice 2 km away"}, {"v": "floor", "label": "Crater floor", "sub": "Ice right there · always dark and freezing"}]},
		{"key": "solar", "label": "Solar array", "sub": "%d cr · %d kg · %d units · always on the sunlit rim" % [MPOW["solar"]["cr"], MPOW["solar"]["kg"], MPOW["solar"]["u"]], "min": 0, "max": 3},
		{"key": "cable", "label": "Cable rim → floor", "sub": "%d cr · %d kg · carries rim power down" % [MPOW["cable"]["cr"], MPOW["cable"]["kg"]], "min": 0, "max": 1},
		{"key": "rtg", "label": "RTG (nuclear battery)", "sub": "%d cr · %d kg · %d units, works in the dark" % [MPOW["rtg"]["cr"], MPOW["rtg"]["kg"], MPOW["rtg"]["u"]], "min": 0, "max": 2},
		{"key": "bat", "label": "Battery pack", "sub": "%d cr · %d kg · stores %d units" % [MPOW["bat"]["cr"], MPOW["bat"]["kg"], MPOW["bat"]["u"]], "min": 0, "max": 2}],
		moon_calc, "BUILD THE POWER SYSTEM", on_lock)


func mars(on_lock: Callable) -> void:
	var st := {"solar": 3, "bat": 0, "rtg": 0, "ins": 0}
	panel("qm", "POWER THE GREENHOUSE", "Heaters need %d units a day and grow lights %d. CERES forecasts dust. Design the power [color=#2ce8f5]before the storm hits[/color]: it may last %d days." % [GPOW["heater"], GPOW["lights"], GPOW["days"]], st,
		[{"key": "solar", "label": "Solar panel", "sub": "%d cr · 1 unit in clear sky, %s in a storm" % [GPOW["solar"]["cr"], str(GPOW["solar"]["storm"])], "min": 0, "max": 6},
		{"key": "bat", "label": "Battery", "sub": "%d cr · stores %d units" % [GPOW["bat"]["cr"], GPOW["bat"]["u"]], "min": 0, "max": 4},
		{"key": "rtg", "label": "RTG (MMRTG-style)", "sub": "%d cr · 1 unit day and night, storm or not" % GPOW["rtg"]["cr"], "min": 0, "max": 1},
		{"key": "ins", "label": "Insulation", "sub": "%d cr · heaters need 1 unit less" % GPOW["ins"]["cr"], "min": 0, "max": 1}],
		mars_calc, "BUILD THE POWER SYSTEM", on_lock)


# ---------------------------------------------------------------- mission report (same for every mission)

static func stars_text(n: int) -> String:
	return "[color=#fee761]%s[/color][color=#3a4466]%s[/color]" % ["★".repeat(n), "★".repeat(3 - n)]


func report(R: Dictionary, on_retry: Callable, on_continue: Callable) -> void:
	var box: VBoxContainer = g.ui.panel(Color("#262b44"), Color("#feae34"), 980, 30)
	g.ui.rich(box, "[b][color=#fee761]MISSION REPORT · %s[/color][/b]      [font_size=30]%s[/font_size]" % [R["name"], stars_text(R["stars"])], 20)
	var bb := ""
	for kv in [["YOU CHOSE", R["chose"]], ["RESULT", R["result"]], ["WHY", R["why"]], ["REAL MISSION", "🚀 " + R["real"]]]:
		bb += "[color=#feae34][font_size=13]%s[/font_size][/color]\n%s\n" % kv
	g.ui.rich(box, bb, 18)
	var nasa := PanelContainer.new()
	nasa.add_theme_stylebox_override("panel", DawnTheme.box(Color(0.07, 0.31, 0.54, 0.35), Color("#0099db"), 3, Color(0, 0, 0, 0), 0, Vector4(14, 10, 14, 10)))
	var nb := VBoxContainer.new()
	nasa.add_child(nb)
	g.ui.rich(nb, "[color=#2ce8f5][b]📡 NASA DATA[/b][/color]\n" + R["data"], 17)
	box.add_child(nasa)
	g.ui.rich(box, "[color=#8b9bb4]★ it works · ★★ inside budget with a margin · ★★★ survives the event with no losses[/color]", 14)
	var row: HBoxContainer = g.ui.row(box)
	if R.get("retry", "") != "":
		g.ui.button(row, "◂ TRY ANOTHER DESIGN", func():
			g.ui.close_panel()
			on_retry.call(), false)
	g.ui.button(row, "CONTINUE  ▸▸", func():
		g.ui.close_panel()
		on_continue.call()).grab_focus.call_deferred()
