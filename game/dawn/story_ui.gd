extends Control
## Full-screen story moments, drawn like the HTML demo (same 320x180 pixel art, scaled 4x):
## intro, wake-up, workshop, readiness review, launch, report, travel and the ending.
## Owner: Sufi (art/animation). Rules live in story.gd; nothing here changes the state except
## through g.act().

const WD := preload("res://game/dawn/world_data.gd")
const RoleSprites := preload("res://game/player/role_sprites.gd")
const Pixel := preload("res://game/dawn/pixel.gd")
const C := DawnTheme.C
const ROLES := ["eng", "sci", "nav", "qm"]

const INTRO := [
	{"k": "sun", "title": "1 · OUR SUN", "text": "This is Earth. Sunlight keeps everything alive. But sunlight also carries ultraviolet light, [color=#2ce8f5]UV[/color], which burns skin and damages plants."},
	{"k": "ozone", "title": "2 · THE OZONE LAYER", "text": "High above us, [color=#2ce8f5]15 to 35 km up[/color], a thin layer of ozone gas soaks up most of that UV. It is Earth's sunscreen: [color=#2ce8f5]the ozone layer[/color]."},
	{"k": "grb", "title": "3 · THE BURST", "text": "Then a dying star far away exploded in a [color=#2ce8f5]gamma-ray burst[/color]. Its blast tore the ozone layer apart.", "note": "Scientists think a burst like this may have hit Earth 440 million years ago."},
	{"k": "surface", "title": "4 · UNDERGROUND", "text": "Now deadly UV pours down on the surface. People fled into [color=#2ce8f5]underground bunkers[/color], cut off from each other."},
	{"k": "heal", "title": "5 · TIME TO HEAL", "text": "Good news: the ozone layer can [color=#2ce8f5]heal itself[/color]. Sunlight slowly makes new ozone. But it takes time, and people have to survive until it does.", "note": "The real ozone hole is healing too, since the world banned the chemicals harming it in 1987."},
	{"k": "plan", "title": "6 · PROJECT DAWN", "text": "Your mission: [color=#2ce8f5]help the ozone layer heal[/color] and keep everyone alive until it does. How? Nobody knows yet. First, find out how bad the damage is."},
	{"k": "crew", "title": "7 · YOUR CREW", "text": "You are the crew of Bunker 4. Four roles, one team, and every job matters. CERES, the bunker's AI, will guide you."},
]
const PEOPLE_COLORS := ["sky", "pink", "amber", "green", "orange", "sand", "red"]

var story
var g
var _screen: Control
var _pc: Pixel
var _labels := []             ## [text, x, y, color] drawn on top of the intro art
var _i := 0
var _t0 := 0.0
var _launch := {}
var _design := {}
var _votes := []
var _wk := {}                 ## wake-up scene state
var _intro_box: PanelContainer
var _intro_text: RichTextLabel
var _intro_t := 0.0
var _report_shown = null       ## id of the mission report open on this screen


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if g.S["scene"] == "launch" and not _launch.is_empty():
		_launch_tick(delta)
	if not _wk.is_empty():
		_wake_tick(delta)
	_watch_report()
	if _intro_text and _intro_text.visible_ratio < 1.0:
		_intro_t += delta
		_intro_text.visible_characters = int(_intro_t / 0.024 * 2)


## Show the shared mission report when the host posts one; close it when someone else continues.
func _watch_report() -> void:
	var R: Dictionary = g.S.get("report", {})
	if R.is_empty():
		if _report_shown != null and g.ui.panel_open():
			g.ui.close_panel()
		_report_shown = null
		return
	if R["id"] == _report_shown or g.ui.dialogue_open() or g.ui.panel_open() or _screen != null or g.S["scene"] != "game":
		return
	_report_shown = R["id"]
	var rid = R["id"]
	story.dz.report(R, func(): g.act("rretry", {"id": rid}, g.acting_role()), func(): g.act("rcont", {"id": rid}, g.acting_role()))


# ---------------------------------------------------------------- screen helpers

func _open(painter: Callable) -> Control:
	_close()
	_screen = Control.new()
	_screen.size = Vector2(1280, 720)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_screen)
	var back := ColorRect.new()
	back.color = C["ink"]
	back.size = Vector2(1280, 720)
	_screen.add_child(back)
	_pc = Pixel.new()
	_pc.painter = painter
	_screen.add_child(_pc)
	g.set_frozen(true)
	g.ui.raise_overlays()
	return _screen


func _close() -> void:
	_wk = {}
	_intro_text = null
	if _screen:
		_screen.queue_free()
		_screen = null
		_pc = null
		g.set_frozen(false)


func _box(parent: Node, pos: Vector2, w: float, border := Color("#feae34"), h := 0.0) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", DawnTheme.box(Color(0.094, 0.078, 0.145, 0.93), border, 4, Color(0, 0, 0, 0), 0, Vector4(20, 12, 20, 12)))
	p.position = pos
	p.custom_minimum_size = Vector2(w, h)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	return v


func _banner(parent: Node, t: String, sub: String, small := false) -> VBoxContainer:
	var v := _box(parent, Vector2(24, 20), 1232)
	var h := Label.new()
	h.text = t
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", DawnTheme.title_font())
	h.add_theme_font_size_override("font_size", 28 if small else 44)
	h.add_theme_color_override("font_color", C["yellow"])
	h.add_theme_color_override("font_shadow_color", Color("#f77622"))
	h.add_theme_constant_override("shadow_offset_x", 4)
	h.add_theme_constant_override("shadow_offset_y", 4)
	v.add_child(h)
	if sub != "":
		var s := Label.new()
		s.text = sub
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.add_theme_font_size_override("font_size", 24)
		s.add_theme_color_override("font_color", C["sand"])
		v.add_child(s)
	return v


# ---------------------------------------------------------------- intro (this screen only), ported from c8.js

func intro() -> void:
	_i = 0
	_open(_paint_intro)
	_intro_box = PanelContainer.new()
	_intro_box.add_theme_stylebox_override("panel", DawnTheme.box(Color(0.094, 0.078, 0.145, 0.93), C["amber"], 4, Color(0, 0, 0, 0), 0, Vector4(20, 12, 20, 12)))
	_intro_box.position = Vector2(24, 524)
	_intro_box.size = Vector2(1232, 184)
	_intro_box.custom_minimum_size = Vector2(1232, 184)
	_screen.add_child(_intro_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_intro_box.add_child(v)
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 6)
	for i in INTRO.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(24, 8)
		dots.add_child(d)
	v.add_child(dots)
	var h := Label.new()
	h.add_theme_font_override("font", DawnTheme.title_font())
	h.add_theme_font_size_override("font_size", 16)
	h.add_theme_color_override("font_color", C["yellow"])
	v.add_child(h)
	_intro_text = RichTextLabel.new()
	_intro_text.bbcode_enabled = true
	_intro_text.scroll_active = false
	_intro_text.custom_minimum_size = Vector2(1180, 58)
	_intro_text.add_theme_font_size_override("normal_font_size", 23)
	v.add_child(_intro_text)
	var foot := HBoxContainer.new()
	var note := Label.new()
	note.add_theme_font_size_override("font_size", 17)
	note.add_theme_color_override("font_color", C["grey"])
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(note)
	var skip := Button.new()
	skip.text = "SKIP INTRO"
	skip.theme_type_variation = "GhostButton"
	skip.pressed.connect(_request_skip_intro)
	foot.add_child(skip)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(14, 0)
	foot.add_child(sp)
	var nb := Button.new()
	nb.pressed.connect(_intro_next)
	foot.add_child(nb)
	v.add_child(foot)
	_intro_box.set_meta("parts", {"dots": dots, "h": h, "note": note, "next": nb})
	_intro_show()
	nb.grab_focus.call_deferred()


func _intro_show() -> void:
	var s: Dictionary = INTRO[_i]
	var parts: Dictionary = _intro_box.get_meta("parts")
	for j in INTRO.size():
		parts["dots"].get_child(j).color = C["amber"] if j <= _i else C["slate"]
	parts["h"].text = s["title"]
	parts["note"].text = s.get("note", "")
	parts["next"].text = "WAKE UP  ▸▸" if _i == INTRO.size() - 1 else "NEXT  ▸▸"
	_intro_text.text = s["text"]
	_intro_text.visible_characters = 0
	_intro_t = 0.0
	_t0 = _pc.t
	match s["k"]:
		"sun": _labels = [["SUN", 30, 72, "yellow"], ["EARTH", 236, 100, "white"], ["visible light", 140, 34, "yellow"], ["UV light", 140, 62, "pink"]]
		"ozone": _labels = [["OZONE LAYER · 15–35 km", 250, 30, "cyan"], ["UV blocked", 70, 14, "pink"], ["light gets through", 220, 10, "yellow"], ["GROUND", 160, 86, "white"]]
		"grb":
			_labels = [["DYING STAR", 52, 30, "white"], ["OZONE LAYER", 232, 22, "rose"]]
		"surface": _labels = [["BUNKER", 45, 62, "yellow"]]
		"heal": _labels = [["SUN", 24, 94, "yellow"], ["new ozone forms…", 170, 14, "cyan"], ["EARTH", 160, 104, "white"]]
		"plan": _labels = [["OZONE NOW", 62, 96, "rose"], ["GOAL: HEALED", 258, 96, "green"], ["HOW?", 160, 16, "yellow"]]
		"crew":
			_labels = []
			var d := ["builds", "studies", "steers", "supplies"]
			for i in 4:
				_labels.append([RoleSprites.NAMES[ROLES[i]], 50 + i * 74, 80, RoleSprites.TAGS[ROLES[i]]])
				_labels.append([d[i], 50 + i * 74, 90, "light"])


func _intro_next() -> void:
	if _intro_text.visible_ratio < 1.0:
		_intro_text.visible_characters = -1
		return
	_i += 1
	if _i >= INTRO.size():
		_intro_done()
	else:
		_intro_show()

func _request_skip_intro() -> void:
	g.act("skip_intro", {}, g.acting_role())
	
func skip_intro_for_all() -> void:
	if _intro_box != null:
		_intro_done()
		
func _intro_done() -> void:
	_intro_box = null
	_close()
	if g.S["scene"] != "game":
		show_scene(g.S["scene"])
	elif g.S["world"] == "earth" and g.S["step"] == 0:
		wake()


func _paint_intro(pc: Pixel, t: float, _dt: float) -> void:
	var s: Dictionary = INTRO[_i]
	var e := t - _t0
	pc.R(0, 0, 320, 180, "ink")
	pc.stars2(t)
	match s["k"]:
		"sun":
			pc.disc(24, 54, 34, "amber")
			pc.disc(24, 54, 26, "yellow")
			pc.planet("earth", 198, 18, 76)
			for i in 6:
				var ph := fmod(e * 60 + i * 30, 150.0)
				pc.R(62 + ph, 40 + (i % 3) * 3, 10, 1, "yellow")
				pc.R(62 + fmod(e * 48 + i * 40, 140.0), 66 + (i % 2) * 3, 8, 1, "pink")
		"ozone":
			pc.disc(160, 300, 230, Color("#16304d"))
			pc.disc(160, 300, 224, Color("#1c3a5c"))
			pc.disc(160, 300, 210, Color("#2a5d8a"))
			pc.R(0, 96, 320, 84, "dgreen")
			for x in range(0, 320, 9):
				pc.R(x, 92 + (x % 4), 5, 4, "forest")
			pc.draw_arc(Vector2(160, 300), 262, PI * 1.08, PI * 1.92, 96, Color(0.17, 0.91, 0.96, .55 + .25 * sin(t * 3)), 5.0)
			for i in 5:
				var yy := fmod(e * 55 + i * 24, 70.0)
				var x := 40 + i * 14
				if yy < 26:
					pc.R(x, yy, 1, 6, "pink")
				else:
					pc.px(x - 1, 30, "white")
					pc.px(x + 1, 30, "white")
			for i in 5:
				pc.R(200 + i * 14, fmod(e * 55 + i * 30, 92.0), 1, 6, "yellow")
		"grb":
			var fl := minf(1.0, e / 1.2)
			pc.disc(40, 40, 3 + round(fl * 5), "white")
			if e < 2.4 and int(t * 10) % 2:
				pc.disc(40, 40, 10, "magenta")
			if e > .6:
				pc.draw_line(Vector2(44, 44), Vector2(230, 66), Color(1, 0, 0.27, maxf(0.0, .9 - (e - .6) / 3)), 3.0)
			pc.planet("earth", 196, 30, 72)
			var gap := clampf((e - 1) / 2.2, 0.0, 1.0)
			for a in 24:
				var broken := Pixel.hash2(a, 5) < gap
				if broken and int(t * 8 + a) % 3 != 0:
					continue
				pc.draw_arc(Vector2(232, 66), 46, a / 24.0 * TAU, (a + .8) / 24.0 * TAU, 4, pc.col("red" if broken else "rose"), 3.0)
			if e > 1 and e < 1.4:
				pc.R(0, 0, 320, 180, Color(1, 1, 1, .35))
		"surface":
			pc.dusk_sky(t, -50)
			pc.crack(t, -50)
			pc.landscape(t, -40)
			for i in 14:
				pc.R(fmod(i * 23 + e * 30, 320.0), fmod(e * 70 + i * 37, 100.0), 1, 7, "pink")
			for i in 7:
				var x := 200 + i * 18 - e * (14 + (i % 3) * 4)
				if x < 46:
					continue
				pc.person_color(pc.col(PEOPLE_COLORS[i]), x, 78, "left", int(t * 8) + i)
			if int(t * 2) % 2:
				pc.R(40, 90, 10, 2, "amber")
		"heal":
			pc.disc(14, 60, 30, "amber")
			pc.disc(14, 60, 24, "yellow")
			pc.planet("earth", 118, 22, 84)
			var kk := minf(1.0, e / 5.0)
			for a in 28:
				var healed := Pixel.hash2(a, 9) < kk * .9 + .08
				if not healed and int(t * 6 + a) % 3 != 0:
					continue
				pc.draw_arc(Vector2(160, 64), 50, a / 28.0 * TAU, (a + .8) / 28.0 * TAU, 4, pc.col("cyan" if healed else "red"), 3.0)
			for i in 5:
				pc.R(46 + fmod(e * 40 + i * 26, 90.0), 52 + (i % 3) * 4, 6, 1, "yellow")
		"plan":
			var pulse := int(t * 2) % 2
			pc.planet("earth", 40, 34, 48)
			for a in 20:
				if Pixel.hash2(a, 3) < .55 and int(t * 5 + a) % 2:
					continue
				pc.draw_arc(Vector2(64, 58), 30, a / 20.0 * TAU, (a + .7) / 20.0 * TAU, 4, pc.col("red" if Pixel.hash2(a, 3) < .55 else "rose"), 2.0)
			pc.planet("earth", 234, 34, 48)
			pc.draw_arc(Vector2(258, 58), 30, 0, TAU, 64, pc.col("cyan"), 2.0)
			for x in range(104, 218, 6):
				if ((x - 104) / 6 + int(e * 6)) % 3 == 0:
					pc.R(x, 57, 3, 2, "steel")
			pc.text("?", 140, 50 + pulse, "yellow", 22)
			pc.text("?", 160, 64 - pulse, "yellow", 22)
			pc.text("?", 180, 50 + pulse, "yellow", 22)
			pc.R(70, 108, 180, 6, "ink")
			pc.R(71, 109, round(178 * .08), 4, "red")
			pc.text("8%", 74, 122, "white", 6, false)
			pc.text("100%", 232, 122, "white", 6, false)
		"crew":
			pc.bunker_bg(t)
			pc.R(0, 0, 320, 180, Color(0.094, 0.078, 0.145, .55))
			for i in 4:
				pc.person(ROLES[i], 26 + i * 74, 14 + ((int(t * 2) + i) % 2), "down", 0, 3)
			pc.ceres(296, 20, 9, t)
	for l in _labels:
		pc.text(l[0], l[1], l[2], l[3], 5)


# ---------------------------------------------------------------- wake-up (this screen only), ported from c5.js

const WOBJ := {0: {"ax": 127, "ay": 114, "bx": 112, "by": 48, "bw": 30, "bh": 42, "label": "SILENCE ALARM"},
	1: {"ax": 163, "ay": 114, "bx": 152, "by": 10, "bw": 22, "bh": 70, "label": "LOOK OUTSIDE"},
	2: {"ax": 214, "ay": 114, "bx": 186, "by": 32, "bw": 56, "bh": 42, "label": "READ THE MAP"},
	4: {"ax": 281, "ay": 114, "bx": 256, "by": 28, "bw": 50, "bh": 70, "label": "OPEN HANGAR DOOR"}}
const WTXT := ["Turn off the alarm", "Look outside through the periscope", "Check the bunker map", "Wake the crew", "Open the hangar door"]


func wake() -> void:
	var me: String = g.camera.target.role if is_instance_valid(g.camera.target) else "eng"
	var others := ROLES.filter(func(r): return r != me)
	_open(_paint_wake)
	_wk = {"phase": "black", "step": 0, "alarm": false, "alarm_t": 0.0, "wake_t": 0.0, "caps_open": false, "door_p": 0.0, "door_opening": false,
		"fade": 0.0, "fading": false, "view": "", "term_on": false, "me": me,
		"pl": {"x": 20.0, "y": 112.0, "d": "right", "m": false, "tx": null, "sp": 58.0},
		"ce": {"x": 232.0, "y": 138.0, "dir": -1, "screen_on": false, "follow": false, "tx": null, "m": false},
		"others": others.map(func(r): return {"r": r, "vis": false, "x": 0.0, "y": 0.0, "d": "right", "tx": null, "m": false})}
	var start := VBoxContainer.new()
	start.position = Vector2(390, 260)
	start.custom_minimum_size = Vector2(500, 0)
	start.add_theme_constant_override("separation", 20)
	start.alignment = BoxContainer.ALIGNMENT_CENTER
	var b := Button.new()
	b.text = "CLICK OR PRESS ANY KEY\nTO WAKE UP"
	b.theme_type_variation = "GhostButton"
	b.custom_minimum_size = Vector2(500, 90)
	b.pressed.connect(_wake_start)
	start.add_child(b)
	var hint := Label.new()
	hint.text = "Something is beeping."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", C["grey"])
	start.add_child(hint)
	_screen.add_child(start)
	_wk["start"] = start
	var ob := Label.new()
	ob.position = Vector2(16, 12)
	ob.add_theme_font_size_override("font_size", 20)
	ob.add_theme_color_override("font_color", C["white"])
	var obp := PanelContainer.new()
	obp.add_theme_stylebox_override("panel", DawnTheme.box(Color(0.094, 0.078, 0.145, 0.88), C["amber"], 4, Color(0, 0, 0, 0), 0, Vector4(12, 6, 12, 6)))
	obp.position = Vector2(16, 12)
	obp.add_child(ob)
	obp.visible = false
	_screen.add_child(obp)
	_wk["obj"] = obp
	_wk["obj_l"] = ob
	var pr := Button.new()
	pr.visible = false
	pr.position = Vector2(500, 420)
	pr.pressed.connect(_wake_interact)
	_screen.add_child(pr)
	_wk["prompt"] = pr
	_screen.gui_input.connect(_wake_click)
	b.grab_focus.call_deferred()


func _wake_start() -> void:
	if _wk.is_empty() or _wk["phase"] != "black":
		return
	g.act("wake_start", {}, g.acting_role())


func start_wake_for_all() -> void:
	if _wk.is_empty() or _wk["phase"] != "black":
		return
	_wk["start"].queue_free()
	_wk["phase"] = "wake"
	_wk["alarm"] = true


func _wake_click(e: InputEvent) -> void:
	if _wk.is_empty() or not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if _wk["phase"] == "black":
		_wake_start()
		return
	if _wk["phase"] != "play" or g.ui.dialogue_open():
		return
	var p: Vector2 = e.position / 4.0
	var o = WOBJ.get(_wk["step"])
	var pl: Dictionary = _wk["pl"]
	if o and p.x >= o["bx"] - 4 and p.x <= o["bx"] + o["bw"] + 4 and p.y >= o["by"] - 4 and p.y <= o["by"] + o["bh"] + 4:
		pl["tx"] = float(o["ax"])
		pl["ty"] = float(o["ay"])
		pl["arrive"] = _wake_interact
		return
	pl["tx"] = clampf(p.x, 10, 310)
	pl["ty"] = clampf(p.y, 108, 166)
	pl["arrive"] = Callable()


func _input(e: InputEvent) -> void:
	if _wk.is_empty() or not (e is InputEventKey and e.pressed and not e.echo):
		return
	if _wk["phase"] == "black":
		_wake_start()
		get_viewport().set_input_as_handled()
	elif e.physical_keycode == KEY_E and _wk["phase"] == "play" and not g.ui.dialogue_open():
		_wake_interact()
		get_viewport().set_input_as_handled()
	elif (e.physical_keycode == KEY_SPACE or e.physical_keycode == KEY_E) and g.ui.dialogue_open():
		g.ui.advance()
		get_viewport().set_input_as_handled()


func _move(e: Dictionary, delta: float) -> void:
	if e.get("tx") == null:
		e["m"] = false
		return
	var v := Vector2(e["tx"] - e["x"], e["ty"] - e["y"])
	var d := v.length()
	var s: float = e.get("sp", 46.0) * delta
	if d <= s + .3:
		e["x"] = e["tx"]
		e["y"] = e["ty"]
		e["tx"] = null
		e["m"] = false
		var f: Callable = e.get("arrive", Callable())
		e["arrive"] = Callable()
		if f.is_valid():
			f.call()
		return
	e["x"] += v.x / d * s
	e["y"] += v.y / d * s
	e["m"] = true
	if absf(v.x) > .5:
		e["dir"] = 1 if v.x > 0 else -1
		e["d"] = "right" if v.x > 0 else "left"


func _walk(e: Dictionary, x: float, y: float, sp: float) -> Signal:
	var done := Wait.new()
	e["tx"] = x
	e["ty"] = y
	e["sp"] = sp
	e["arrive"] = func(): done.fire()
	return done.done


class Wait extends RefCounted:
	signal done
	func fire() -> void:
		done.emit()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _say(lines: Array) -> void:
	var w := Wait.new()
	g.ui.say(lines, func(): w.fire())
	await w.done


func _wake_tick(delta: float) -> void:
	var W8 := _wk
	if W8["phase"] == "black":
		return
	if W8["alarm"]:
		W8["alarm_t"] -= delta
	if W8["phase"] == "wake":
		W8["wake_t"] += delta
		if W8["wake_t"] >= 2.4:
			W8["phase"] = "play"
			W8["obj"].visible = true

	W8["obj_l"].text = "▸ " + (WTXT[W8["step"]] if W8["step"] < WTXT.size() else "")
	var p: Dictionary = W8["pl"]

# Automatically walk to objectives that have a defined target.
	if W8["phase"] == "play" and not g.ui.dialogue_open():
		var target = WOBJ.get(W8["step"])
		if target != null:
			p["tx"] = float(target["ax"])
			p["ty"] = float(target["ay"])
			p["sp"] = 58.0
			p["arrive"] = Callable()
		else:
			p["tx"] = null
			p["m"] = false

	if W8["phase"] == "play" or p.get("tx") != null:
		_move(p, delta)

	_move(W8["ce"], delta)
	for crew_member in W8["others"]:
		_move(crew_member, delta)

	var ce: Dictionary = W8["ce"]
	if ce["follow"] and W8["phase"] == "play":
		var fx: float = p["x"] + (20 if p["d"] == "left" else -20)
		var fy: float = p["y"] + 2
		if Vector2(fx - ce["x"], fy - ce["y"]).length() > 7:
			ce["tx"] = clampf(fx, 10, 310)
			ce["ty"] = clampf(fy, 108, 166)
			ce["sp"] = 46.0

	if W8["door_opening"] and W8["door_p"] < 1:
		W8["door_p"] = minf(1.0, W8["door_p"] + delta / 1.6)
	if W8["fading"] and W8["fade"] < 1:
		W8["fade"] = minf(1.0, W8["fade"] + delta / 1.5)

	var ob = WOBJ.get(W8["step"])
	var near: bool = (
		ob != null
		and W8["phase"] == "play"
		and W8["view"] == ""
		and absf(p["x"] - ob["ax"]) <= 16
		and absf(p["y"] - ob["ay"]) <= 26
	)
	var pr: Button = W8["prompt"]
	pr.visible = near
	if near:
		pr.text = ob["label"] + "   [E]"
		pr.position = Vector2(clampf(ob["ax"] * 4 - 140, 20, 960), 330)


func _wake_interact() -> void:
	var W8 := _wk
	if W8.is_empty():
		return

	var o = WOBJ.get(W8["step"])
	if o == null or W8["phase"] != "play" or g.ui.dialogue_open():
		return

	var p: Dictionary = W8["pl"]
	if not (absf(p["x"] - o["ax"]) <= 16 and absf(p["y"] - o["ay"]) <= 26):
		return

	W8["prompt"].visible = false
	g.request_wake_step(int(W8["step"]))
	
func _run_wake_step(step: int) -> void:
	if _wk.is_empty():
		return
	if _wk["phase"] != "play" or _wk["step"] != step:
		return
	if g.ui.dialogue_open():
		return

	match step:
		0:
			_w_alarm()
		1:
			_w_view("peri", "UV INDEX: EXTREME",
				[{"who": "ceres", "text": "A gamma-ray burst destroyed the ozone layer. Deadly UV now covers the surface."}],
				2)
		2:
			_w_view("net", "NETWORK: OFFLINE",
				[{"who": "ceres", "text": "Every bunker is alone. Nobody can go outside to fix the towers."}],
				3)
		4:
			_w_door()


func _w_alarm() -> void:
	var W8 := _wk
	W8["phase"] = "cut"
	W8["alarm"] = false
	W8["term_on"] = true
	await _wait(.9)
	W8["ce"]["screen_on"] = true
	await _wait(.7)
	await _walk(W8["ce"], clampf(W8["pl"]["x"] + 22, 20, 300), W8["pl"]["y"] + 1, 55)
	W8["ce"]["dir"] = -1
	await _say([{"who": "ceres", "text": "Alarm off. Good morning. I am CERES, your mission AI."}, {"who": "ceres", "text": "Bunker 4 power is stable. You are the first one up."}, {"who": "ceres", "text": "Look outside. Use the periscope."}])
	W8["step"] = 1
	W8["ce"]["follow"] = true
	W8["phase"] = "play"


func _w_view(view: String, note: String, lines: Array, next_step: int) -> void:
	var W8 := _wk
	W8["phase"] = "cut"
	W8["view"] = view
	W8["note"] = note
	await _wait(.7)
	await _say(lines)
	W8["view"] = ""
	W8["step"] = next_step
	if next_step == 3:
		_w_crew()
	else:
		W8["phase"] = "play"


func _w_crew() -> void:
	var W8 := _wk
	W8["phase"] = "cut"
	await _wait(.5)
	W8["caps_open"] = true
	var sx := [43, 69, 95]
	var tx := [[64, 126], [90, 128], [116, 126]]
	for i in W8["others"].size():
		var o: Dictionary = W8["others"][i]
		o["vis"] = true
		o["x"] = float(sx[i])
		o["y"] = 108.0
	await _wait(.7)
	for i in W8["others"].size():
		_walk(W8["others"][i], tx[i][0], tx[i][1], 40)
	await _wait(1.4)
	var nm := func(r: String) -> String: return r if r != W8["me"] else "ceres"
	await _say([{"who": nm.call("qm"), "text": "How long was I out?"}, {"who": "ceres", "text": "Long enough. You four are the only ones who can still work."},
		{"who": nm.call("nav"), "text": "But we are not stuck. There is an old spaceport a few kilometers away."},
		{"who": nm.call("eng"), "text": "Rusty, but standing. I can work with that."},
		{"who": "ceres", "text": "Then decide: build a shield in space, and help every bunker hold on."},
		{"who": "ceres", "text": "It will take all four of you. Most jobs need a specific role, and some need two or all four of you at once."}])
	W8["step"] = 4
	W8["phase"] = "play"


func _w_door() -> void:
	var W8 := _wk
	W8["phase"] = "cut"
	W8["door_opening"] = true
	await _wait(2.0)
	await _say([{"who": "ceres", "text": "Project Dawn begins now. First question: how bad is the sky, really? Meet me in Mission Control."}])
	W8["fading"] = true
	await _wait(1.7)
	_close()


func _paint_wake(pc: Pixel, t: float, _dt: float) -> void:
	var W8 := _wk
	if W8.is_empty():
		return
	if W8["phase"] == "black":
		pc.R(0, 0, 320, 180, Color.BLACK)
		if int(t * 2) % 2:
			pc.R(152, 50, 16, 16, "red")
		return
	if W8["view"] == "peri":
		pc.peri(t)
		pc.text(W8.get("note", ""), 160, 158, "red", 9)
		return
	if W8["view"] == "net":
		pc.net(t, false)
		pc.text(W8.get("note", ""), 160, 16, "red", 9)
		return
	_wake_room(pc, t)
	var ents := [{"k": "me", "y": W8["pl"]["y"]}, {"k": "ce", "y": W8["ce"]["y"]}]
	for o in W8["others"]:
		if o["vis"]:
			ents.append({"k": o, "y": o["y"]})
	ents.sort_custom(func(a, b): return a["y"] < b["y"])
	for e in ents:
		if e["k"] is String and e["k"] == "me":
			var p: Dictionary = W8["pl"]
			pc.person(W8["me"], p["x"] - 10.5, p["y"] - 29, p["d"], int(t * 8) + 1 if p["m"] else 0, 1.5)
		elif e["k"] is String and e["k"] == "ce":
			_cbot(pc, W8["ce"], t)
		else:
			var o2: Dictionary = e["k"]
			pc.person(o2["r"], o2["x"] - 10.5, o2["y"] - 29, o2["d"], int(t * 8) + 1 if o2["m"] else 0, 1.5)
	if W8["alarm"]:
		pc.R(0, 0, 320, 180, Color(1, 0.12, 0.08, .16 if int(t * 1.2) % 2 == 0 else .05))
	if W8["phase"] == "wake":
		var pts := [[0.0, 0.0], [.6, .2], [1.0, .04], [1.5, .55], [1.8, .4], [2.4, 1.0]]
		var tt: float = W8["wake_t"]
		var o := 1.0
		for i in range(1, pts.size()):
			if tt <= pts[i][0]:
				var a: Array = pts[i - 1]
				var b: Array = pts[i]
				o = a[1] + (b[1] - a[1]) * (tt - a[0]) / (b[0] - a[0])
				break
		var h := (1 - o) * 90
		pc.R(0, 0, 320, h, Color.BLACK)
		pc.R(0, 180 - h, 320, h, Color.BLACK)
	if W8["fade"] > 0:
		pc.R(0, 0, 320, 180, Color(0.965, 0.776, 0.42, W8["fade"]))


## The wake-up robot = CERES (same drawing as the dialogue portrait, see pixel.gd cbot()).
func _cbot(pc: Pixel, e: Dictionary, t: float) -> void:
	pc.cbot(roundf(e["x"]), roundf(e["y"]), e["dir"] > 0, e["m"] and int(t * 8) % 2 == 1, e["screen_on"])


func _wake_room(pc: Pixel, t: float) -> void:
	var W8 := _wk
	var bl := int(t * 2.4) % 2 == 0
	var flash: bool = W8["alarm"] and int(t * 1.2) % 2 == 0
	var R2 := func(c, x, y, w, h): pc.R(x, y, w, h, Color(c) if c is String else c)
	R2.call("#122822", 0, 0, 320, 96)
	for x in range(30, 320, 32):
		R2.call("#0d1d19", x, 14, 1, 82)
	R2.call("#1e3a31", 0, 10, 320, 4); R2.call("#2d5446", 0, 10, 320, 1)
	R2.call("#0b1512", 0, 96, 320, 84); R2.call("#244a3d", 0, 96, 320, 2); R2.call("#12251f", 0, 124, 320, 1); R2.call("#12251f", 0, 152, 320, 1)
	for lx in [60, 160, 260]:
		R2.call("#5a1010", lx - 5, 14, 10, 4)
		if W8["alarm"]:
			R2.call("#ff5a4a" if flash else "#8a2a22", lx - 4, 15, 8, 2)
			pc.draw_colored_polygon(PackedVector2Array([Vector2(lx - 4, 18), Vector2(lx + 4, 18), Vector2(lx + 30, 96), Vector2(lx - 30, 96)]), Color(1, 0.24, 0.16, .13 if flash else .05))
	var occ := [null]
	for o in W8["others"]:
		occ.append(RoleSprites.TAGS[o["r"]])
	for i in 4:
		var x0 := 6 + 26 * i
		var open: bool = i == 0 or W8["caps_open"]
		if open:
			R2.call("#3a4b58", x0 - 5, 42, 5, 40)
		R2.call("#2b3a45", x0, 38, 22, 58)
		R2.call("#0a1a1a" if open else "#0f2a2a", x0 + 3, 42, 16, 40)
		if not open:
			R2.call("#d9a77c", x0 + 8, 52, 6, 6)
			R2.call(occ[i] if occ[i] else "#8a5a2b", x0 + 6, 58, 10, 16)
			R2.call(Color(0.17, 0.48, 0.42, .45), x0 + 4, 43, 4, 38)
		R2.call("#1b2830", x0 - 1, 92, 24, 4)
		R2.call("#39ff8a" if open else ("#f2a43a" if bl else "#6b4a1a"), x0 + 8, 39, 6, 2)
	R2.call("#3a4552", 112, 48, 30, 42); R2.call("#06100e", 115, 51, 24, 28)
	if W8["alarm"]:
		R2.call("#ff3b30" if flash else "#4a0f0f", 115, 51, 24, 28)
		if flash:
			R2.call("#ffffff", 125, 56, 4, 12)
			R2.call("#ffffff", 125, 72, 4, 4)
	elif W8["term_on"]:
		R2.call("#06241b", 115, 51, 24, 28)
		for r in [[121, 58, 2, 4], [131, 58, 2, 4], [120, 68, 2, 2], [132, 68, 2, 2], [122, 70, 10, 2]]:
			R2.call("#f5e66a", r[0], r[1], r[2], r[3])
	R2.call("#1b2830", 115, 81, 24, 6); R2.call("#ff3b30" if W8["alarm"] else "#39ff8a", 123, 82, 8, 4)
	R2.call("#566474", 160, 12, 6, 44); R2.call("#8a96a8", 161, 12, 1, 44); R2.call("#3a4552", 156, 56, 14, 6); R2.call("#2b3a45", 154, 62, 18, 16)
	R2.call("#0f2a2a", 160, 66, 6, 6); R2.call("#3a4552", 152, 66, 2, 8)
	if W8["step"] == 1 and bl:
		R2.call("#b36bff", 162, 68, 2, 2)
	R2.call("#3a4552", 186, 32, 56, 42); R2.call("#0f1830", 188, 34, 52, 38)
	for r in [[194, 44, 12, 8], [214, 42, 14, 6], [206, 56, 18, 8], [226, 52, 8, 6]]:
		R2.call("#2f6b4a", r[0], r[1], r[2], r[3])
	R2.call("#9aa3b3", 200, 40, 3, 3); R2.call("#9aa3b3", 220, 58, 3, 3); R2.call("#00ff41" if bl else "#0b5a1a", 214, 48, 3, 3)
	R2.call("#1b1e27", 256, 28, 50, 70)
	var dp: float = W8["door_p"]
	if dp > 0:
		for b in [["#4b1f7e", 30, 14], ["#b0458f", 44, 12], ["#e08a3c", 56, 14], ["#f2b45a", 70, 10]]:
			R2.call(b[0], 258, b[1], 46, b[2])
		R2.call("#6b3b2a", 258, 80, 46, 16); R2.call("#8a8f99", 276, 52, 6, 28)
		pc.draw_colored_polygon(PackedVector2Array([Vector2(258, 96), Vector2(304, 96), Vector2(340, 180), Vector2(222, 180)]), Color(0.965, 0.776, 0.42, 0.2 * dp))
	var pw := 22 * (1 - dp)
	if pw > 0:
		R2.call("#2c313d", 258, 30, pw, 66)
		R2.call("#343a48", 304 - pw, 30, pw, 66)
	for i in 12:
		R2.call("#14141c" if i % 2 else "#f2c14e", 258 + i * 4, 30, 4, 3)
	if dp == 0:
		R2.call("#1a1d25", 280, 30, 2, 66)
		R2.call("#39ff8a" if W8["step"] == 4 else "#ff3b30", 277, 60, 4, 6)
	R2.call("#1b2830", 222, 139, 24, 4); R2.call("#39ff8a" if W8["ce"]["screen_on"] else "#6b4a1a", 232, 139, 4, 1)
	var o = WOBJ.get(W8["step"])
	if o and W8["phase"] == "play":
		pc.draw_rect(Rect2(o["bx"] - 1.5, o["by"] - 1.5, o["bw"] + 3, o["bh"] + 3), Color(0, 1, .25, .55 + .4 * sin(t * 5)), false, 1.0)
		var ay: float = o["by"] + o["bh"] + 4 + round(sin(t * 6) * 1.5)
		pc.draw_colored_polygon(PackedVector2Array([Vector2(o["ax"] - 4, ay + 5), Vector2(o["ax"] + 4, ay + 5), Vector2(o["ax"], ay)]), Color("#00ff41"))


# ---------------------------------------------------------------- scene switching

func show_scene(sc: String) -> void:
	if g.ui.panel_open():
		g.ui.close_panel()
	match sc:
		"game": _close()
		"poll": _poll()
		"launch": _launch_start()
		"report": _report()
		"travel": _travel()
		"ending": _ending()


# ---------------------------------------------------------------- mission board

func mission_board() -> void:
	var s: Dictionary = g.S
	var box: VBoxContainer = g.ui.panel(Color("#262b44"), C["amber"], 860)
	g.ui.title(box, "MISSION BOARD · ACT 1")
	var r: HBoxContainer = g.ui.row(box)
	var done: bool = s["step"] >= 4 or s["world"] != "earth"
	var c1 := _card(r, "1.1 SOUNDING\nROCKET", "✓ Done · UV measured" if done else "Measure UV on the way up", func(pc, t, _d): pc.rocket_icon(0, 0, false), false)
	c1.pressed.connect(func():
		g.ui.close_panel()
		if s["step"] == 0:
			g.act("pick", {}, g.acting_role()))
	_card(r, "ACT 2\n???", "Unlocked" if done else "Classified until 1.1", func(pc, t, _d): pc.planet("moon", 8, 4, 32) if done else pc.text("?", 24, 26, "slate", 14), true)
	_card(r, "ACTS 3–5\n???", "Later" if done else "Classified", func(pc, t, _d): pc.text("?", 24, 26, "slate", 14), true)
	g.ui.button(box, "CLOSE", g.ui.close_panel, false)
	c1.grab_focus.call_deferred()


func _card(row: Node, t: String, sub: String, art: Callable, locked: bool) -> Button:
	var b := Button.new()
	b.theme_type_variation = "GhostButton"
	b.custom_minimum_size = Vector2(250, 260)
	b.disabled = locked
	row.add_child(b)
	var v := VBoxContainer.new()
	v.position = Vector2(12, 12)
	v.custom_minimum_size = Vector2(226, 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var pic := Pixel.new()
	pic.custom_minimum_size = Vector2(192, 160)
	pic.size = Vector2(192, 160)
	pic.painter = art
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(192, 160)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(pic)
	v.add_child(holder)
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", DawnTheme.title_font())
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", C["slate"] if locked else C["yellow"])
	v.add_child(l)
	var s := Label.new()
	s.text = sub
	s.add_theme_font_size_override("font_size", 18)
	s.add_theme_color_override("font_color", C["grey"] if locked else C["sand"])
	v.add_child(s)
	return b


# ---------------------------------------------------------------- workshop (Engineer)

func workshop() -> void:
	_design = g.S["design"].duplicate()
	var me: String = g.camera.target.role if is_instance_valid(g.camera.target) else "eng"
	_open(func(pc, t, _d):
		pc.workshop_bg(t)
		pc.rocket(160, 132, _design, t)
		pc.person(me, 20, 60 + (int(t * 2) % 2), "down", 0, 4))
	var hb := PanelContainer.new()
	hb.add_theme_stylebox_override("panel", DawnTheme.box(Color(0.094, 0.078, 0.145, 0.92), C["cyan"], 4, Color(0, 0, 0, 0), 0, Vector4(12, 8, 12, 8)))
	hb.position = Vector2(24, 16)
	hb.custom_minimum_size = Vector2(760, 0)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 12)
	var who := Label.new()
	who.text = " CERES "
	who.add_theme_font_override("font", DawnTheme.title_font())
	who.add_theme_font_size_override("font_size", 12)
	who.add_theme_color_override("font_color", C["ink"])
	var whobg := PanelContainer.new()
	whobg.add_theme_stylebox_override("panel", DawnTheme.box(C["cyan"], Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, Vector4(6, 4, 6, 4)))
	whobg.add_child(who)
	hrow.add_child(whobg)
	var say := Label.new()
	say.add_theme_font_size_override("font_size", 22)
	say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	say.custom_minimum_size = Vector2(620, 0)
	hrow.add_child(say)
	hb.add_child(hrow)
	_screen.add_child(hb)
	var gs := _box(_screen, Vector2(880, 16), 376, C["slate"])
	var gauges := {}
	for k in [["mass", "MASS"], ["cost", "COST"], ["alt", "HEIGHT"]]:
		var l := Label.new()
		l.add_theme_font_override("font", DawnTheme.title_font())
		l.add_theme_font_size_override("font_size", 11)
		gs.add_child(l)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 14)
		bar.show_percentage = false
		bar.max_value = 1.0
		gs.add_child(bar)
		gauges[k[0]] = [l, bar, k[1]]
	var reqs := Label.new()
	reqs.add_theme_font_size_override("font_size", 18)
	gs.add_child(reqs)
	var tray := HBoxContainer.new()
	tray.position = Vector2(24, 600)
	tray.add_theme_constant_override("separation", 10)
	_screen.add_child(tray)
	var buttons := {}
	for k in ["small", "big", "uv", "cam", "chute", "radio"]:
		var b := Button.new()
		b.theme_type_variation = "GhostButton"
		b.custom_minimum_size = Vector2(132, 92)
		b.add_theme_font_override("font", DawnTheme.body_font())
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(func():
			if k == "small" or k == "big":
				_design["motor"] = k
			else:
				_design[k] = not _design.get(k, false)
			_refresh_shop(say, gauges, reqs, buttons))
		tray.add_child(b)
		buttons[k] = b
	var lock := Button.new()
	lock.text = "LOCK DESIGN ▸▸"
	lock.custom_minimum_size = Vector2(196, 64)
	lock.pressed.connect(func():
		g.act("design", {"d": _design}, "eng")
		_close())
	tray.add_child(lock)
	var later := Button.new()
	later.text = "LATER"
	later.theme_type_variation = "GhostButton"
	later.custom_minimum_size = Vector2(0, 64)
	later.pressed.connect(_close)
	tray.add_child(later)
	_refresh_shop(say, gauges, reqs, buttons)
	buttons["uv"].grab_focus.call_deferred()


func _refresh_shop(say: Label, gauges: Dictionary, reqs: Label, buttons: Dictionary) -> void:
	var c: Dictionary = story.calc(_design)
	var ok: Dictionary = c["ok"]
	say.text = c["hint"]
	var vals := {"mass": [c["kg"], 260.0, " kg", true], "cost": [c["cr"], float(story.BUDGET), " / %d" % story.BUDGET, ok["budget"]], "alt": [c["alt"], 150.0, " / 100 km", ok["alt"]]}
	for k in gauges:
		var v: Array = vals[k]
		gauges[k][0].text = "%s   %d%s" % [gauges[k][2], v[0], v[2]]
		gauges[k][1].value = minf(1.0, v[0] / v[1])
		gauges[k][1].modulate = C["green"] if v[3] else Color("#e43b44")
	var mark := func(b: bool) -> String: return "✓" if b else "✗"
	reqs.text = "%s UV   %s 100km   %s DATA   %s COST" % [mark.call(ok["uv"]), mark.call(ok["alt"]), mark.call(ok["rec"]), mark.call(ok["budget"])]
	for k in buttons:
		var on: bool = (_design.get("motor") == k) if (k == "small" or k == "big") else _design.get(k, false)
		var pt: Dictionary = story.PARTS[k]
		buttons[k].text = "%s%s\n%d kg · %d cr" % ["✓ " if on else "", pt["name"], pt["kg"], pt["cr"]]
		var col: Color = C["amber"] if on else C["sand"]
		for ck in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			buttons[k].add_theme_color_override(ck, col)
		buttons[k].add_theme_stylebox_override("normal", DawnTheme.box(Color(0.24, 0.15, 0.19, 0.95) if on else C["navy"], C["amber"] if on else C["steel"], 3))


# ---------------------------------------------------------------- readiness review

func _poll() -> void:
	_votes = story.poll_votes()
	_t0 = 0.0
	var st0 := {"t": -1.0}
	_open(func(pc, t, _d):
		if st0["t"] < 0:
			st0["t"] = t
		var now = t - st0["t"]
		pc.bunker_bg(t, "poll")
		for i in _votes.size():
			var r: String = _votes[i][0]
			var x := 40 + i * 68
			var bob := (int(t * 2) + i) % 2
			pc.person(r, x, 88 + bob, "down", 0, 3)
			if now > .5 + i * .5:
				var y := 84
				var ok: bool = _votes[i][1]
				pc.R(x + 12, y, 24, 12, "ink")
				pc.R(x + 13, y + 1, 22, 10, "green" if ok else "red")
				if ok:
					for ab in [[9, 6], [10, 7], [11, 8], [12, 7], [13, 6], [14, 5], [15, 4], [16, 3]]:
						pc.R(x + ab[0] + 10, y + ab[1], 2, 1, "white")
				else:
					for k in 6:
						pc.px(x + 21 + k, y + 3 + k, "white")
						pc.px(x + 26 - k, y + 3 + k, "white")
		pc.text("READINESS REVIEW", 160, 164, "yellow", 8))


# ---------------------------------------------------------------- launch (ported from c5.js)

func _launch_start() -> void:
	_launch = {"t": 0.0, "alt": 0.0, "paused": false, "ev": false, "done": false, "top": false, "smoke": [], "apogee": story.calc(g.S["design"])["alt"]}
	_open(_paint_launch)


func launch_state() -> void:
	if _launch.get("paused", false) and g.S["event"] != "":
		_launch["paused"] = false
		_launch["ev"] = true
		g.ui.close_panel()


func launch_host_tick(_delta: float) -> void:
	pass


func _launch_tick(delta: float) -> void:
	var L := _launch
	if L["paused"]:
		if g.S["event"] != "":
			launch_state()
		return
	L["t"] += delta
	var T: float = L["t"] - 3.0
	var ap: float = L["apogee"]
	if T < 0.0:
		L["alt"] = 0.0
	elif T < 6.0:
		L["alt"] = ap * (1.0 - pow(1.0 - T / 6.0, 2))
	elif T < 9.0:
		L["alt"] = ap
		L["top"] = true
	elif not L["done"]:
		L["done"] = true
		if g.is_host():
			g.S["result"] = story.build_result()
			story.set_scene("report")
	var cam := minf(L["alt"] * 3.2, 420.0)
	var ry := maxf(70.0, 132 - cam * 1.2)
	if T >= 0.0 and T < 6.5:
		for n in 2:
			L["smoke"].append({"x": 160 + (randf() - .5) * 4, "y": ry + 10, "vx": (randf() - .5) * 14, "vy": (10 if ry > 72 else 70) + randf() * 20, "a": 0.0})
	for s in L["smoke"]:
		s["x"] += s["vx"] * delta
		s["y"] += s["vy"] * delta
		s["a"] += delta
	L["smoke"] = L["smoke"].filter(func(s): return s["a"] < 1.6)
	if L["alt"] >= 60.0 and not L["ev"] and not L["paused"]:
		if g.S["event"] != "":
			L["ev"] = true
		else:
			L["paused"] = true
			g.ui.choice("A RADIATION BURST HITS AT 60 KM", "Anyone on the crew can call it. The first answer counts.", [
				{"label": "Safe mode", "sub": "Pause the sensor, lose a few readings", "fn": func(): g.act("evt", {"k": "safe"}, g.acting_role())},
				{"label": "Keep measuring", "sub": "Risk the sensor for more data", "fn": func(): g.act("evt", {"k": "keep"}, g.acting_role())}], "UV STORM")


func _paint_launch(pc: Pixel, t: float, _d: float) -> void:
	var L := _launch
	if L.is_empty():
		return
	var cam := minf(L["alt"] * 3.2, 420.0)
	var ry := maxf(70.0, 132 - cam * 1.2)
	pc.R(0, 0, 320, 180, "ink")
	pc.stars(t, 180, 0)
	pc.dusk_sky(t, cam, 140)
	if cam < 140:
		pc.crack(t, cam)
	pc.landscape(t, cam)
	for s in L["smoke"]:
		pc.disc(s["x"], s["y"], minf(6, 2 + s["a"] * 4), "light" if s["a"] < .5 else ("grey" if s["a"] < 1 else "steel"))
	pc.rocket(160, ry, g.S["design"], t, not L["top"] and L["t"] > 3.0)
	if L["paused"]:
		for i in 20:
			if Pixel.hash2(i, int(t * 8)) > .6:
				pc.R(int(Pixel.hash2(i, 2) * 320), int(Pixel.hash2(i, 4) * 180), 2, 1, "magenta")
	var lt: float = L["t"]
	if lt < 3.0:
		pc.text(str(3 - int(lt)), 160, 70, "yellow", 30)
	elif L["top"]:
		pc.text("APOGEE %d KM" % int(L["apogee"]), 160, 24, "yellow", 9)
	else:
		pc.text("ALT %03d KM" % int(L["alt"]), 160, 24, "yellow", 9)


# ---------------------------------------------------------------- report

func _report() -> void:
	var r: Dictionary = g.S["result"]
	_open(func(pc, t, _d):
		pc.bunker_bg(t)
		pc.R(0, 0, 320, 180, Color(0.094, 0.078, 0.145, .62)))
	var ok: bool = r.get("success", false)
	var L := _box(_screen, Vector2(32, 32), 700, C["amber"])
	var st := Label.new()
	st.text = "MISSION SUCCESS" if ok else "PARTIAL SUCCESS"
	st.add_theme_font_override("font", DawnTheme.title_font())
	st.add_theme_font_size_override("font_size", 30)
	st.add_theme_color_override("font_color", Color("#63c74d") if ok else C["amber"])
	L.add_child(st)
	var c1: Dictionary = story.calc(g.S["design"])
	var stars := (3 if c1["cr"] <= story.BUDGET - 20 else 2) if ok else 1
	if g.is_host():
		g.S["stars"]["rocket"] = maxi(int(g.S["stars"].get("rocket", 0)), stars)
	g.ui.rich(L, "SCORE %d / 1000      [font_size=30]%s[/font_size]" % [r.get("score", 0), story.Designers.stars_text(stars)], 16)
	g.ui.rich(L, "✓ UV sensor    ✓ %d km    %s Data %d%%    ✓ %d cr" % [r.get("alt", 0), "✓" if ok else "!", r.get("data", 0), r.get("cr", 0)], 18)
	var bb := "[color=#2ce8f5][b]CERES[/b][/color]\n" + ("First real numbers: UV is far stronger than it should be at every height." if ok else "We have numbers, but half of them are noise. Still, the sky is clearly damaged.")
	for w in r.get("why", []):
		bb += "\n[color=#c0cbdc]  • " + w + "[/color]"
	g.ui.rich(L, bb, 18)
	var N: Dictionary = story.Designers.NASA["ozone"]
	g.ui.rich(L, "[color=#2ce8f5][b]📡 NASA DATA[/b][/color]\nA healthy ozone layer is about [b]%d DU[/b]; below %d DU counts as an ozone hole. The lowest ever over the South Pole was [b]%d DU[/b] (%s). In the game the ozone is [b]%d DU[/b]. The ozone layer sits 15–35 km up, so your sensor had to climb past 35 km: it reached [b]%d km[/b]. [color=#8b9bb4](%s)[/color]" % [N["normal"], N["hole"], N["low"], N["low_when"], story.Designers.du(g.S["ozone"]), r.get("alt", 0), N["src"]], 15)
	var row: HBoxContainer = g.ui.row(L)
	g.ui.button(row, "◂ TRY ANOTHER DESIGN", func(): g.act("report", {"c": "redesign"}, g.acting_role()), false)
	g.ui.button(row, "CONTINUE ▸▸", func(): g.act("report", {"c": "continue"}, g.acting_role())).grab_focus.call_deferred()
	var Rr := _box(_screen, Vector2(760, 32), 488, C["cyan"])
	var art := Pixel.new()
	art.painter = func(pc, t, _d): pc.rocket_icon(0, 0, false)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(192, 160)
	holder.add_child(art)
	Rr.add_child(holder)
	g.ui.title(Rr, "NASA SOUNDING\nROCKET PROGRAM", C["yellow"], 13)
	g.ui.rich(Rr, "Real rockets that fly straight up and fall back, giving scientists a few minutes above the air.", 18)
	g.ui.rich(Rr, "[color=#63c74d]NEW: ACT 2 · ???\nNEW: OPTIONAL B · UV CANOPY[/color]", 16)


# ---------------------------------------------------------------- travel (ported from c5.js)

func _travel() -> void:
	var c: Dictionary = g.S["cut"]
	var st0 := {"t": -1.0}
	_open(func(pc, t, _d):
		if st0["t"] < 0:
			st0["t"] = t
		var k := minf(1.0, (t - st0["t"]) / 6.0)
		pc.R(0, 0, 320, 180, "ink")
		pc.stars2(t)
		if c.get("kind", "") == "shield":
			pc.disc(18, 112, 26, "amber")
			pc.disc(18, 112, 20, "yellow")
			pc.planet("earth", 208, 66, 92)
			var n: int = g.S["sats"]
			for i in n:
				if k < .15 + float(i) / n * .6:
					continue
				var x := 128
				var y := 112 + (i - (n - 1) / 2.0) * 13
				pc.R(x - 2, y - 2, 5, 4, "light")
				pc.R(x - 8, y - 1, 6, 2, "sky")
				pc.R(x + 3, y - 1, 6, 2, "sky")
			if k > .8:
				pc.draw_colored_polygon(PackedVector2Array([Vector2(130, 112 - n * 7), Vector2(254, 72), Vector2(254, 152), Vector2(130, 112 + n * 7)]), Color(0.17, 0.91, 0.96, .12))
			pc.ring(254, 112, 49, "cyan" if k > .8 else "rose", 64, 2)
			return
		pc.planet(c.get("from", "earth"), 12, 92, 72)
		pc.planet(c.get("to", "moon"), 228, 22, 72)
		var bz := func(a: float, b: float, cc: float, u: float) -> float: return (1 - u) * (1 - u) * a + 2 * (1 - u) * u * b + u * u * cc
		for i in 24:
			var u := k * i / 24.0
			pc.px(round(bz.call(70, 170, 236, u)), round(bz.call(118, 150, 64, u)), "steel")
		var x2: float = bz.call(70, 170, 236, k)
		var y2: float = bz.call(118, 150, 64, k)
		if c.get("kind", "") == "robots":
			pc.R(x2 - 3, y2 - 3, 7, 6, "light")
			pc.R(x2 - 2, y2 - 2, 5, 2, "cyan")
		else:
			pc.R(x2 - 1, y2 - 4, 3, 8, "light")
			pc.R(x2 - 1, y2 - 5, 3, 1, "red")
		if int(t * 12) % 2:
			pc.R(x2 - 1, y2 + 4, 3, 2, "orange"))
	var v := _banner(_screen, c.get("title", ""), c.get("sub", ""), true)
	if c.get("days", 0) > 0:
		var d := Label.new()
		d.text = "+%d DAYS LATER · %s" % [c["days"], WD.clock_text(g.S["time"])]
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.add_theme_font_override("font", DawnTheme.title_font())
		d.add_theme_font_size_override("font_size", 12)
		d.add_theme_color_override("font_color", C["cyan"])
		v.add_child(d)
	var sk := Button.new()
	sk.text = "SKIP"
	sk.theme_type_variation = "GhostButton"
	sk.position = Vector2(1150, 650)
	sk.pressed.connect(func(): g.act("skip", {}, g.acting_role()))
	_screen.add_child(sk)


# ---------------------------------------------------------------- ending (ported from c5.js)

func _ending() -> void:
	var s: Dictionary = g.S
	var n: int = s["opt"].size()
	var tier := "GOLDEN DAWN" if n >= 4 else ("RISING DAWN" if n >= 2 else "QUIET DAWN")
	var st0 := {"t": -1.0}
	_open(func(pc, t, dt):
		if st0["t"] < 0:
			st0["t"] = t
		var e = t - st0["t"]
		pc.dusk_sky(t, -30)
		pc.stars(t)
		pc.landscape(t, 0, true)
		pc.dust(t, dt)
		for i in 4:
			var tx := 74 + i * 24
			var x := minf(tx, 40 + e * 14 - i * 12)
			if x < 40:
				continue
			var mv := x < tx
			pc.person(ROLES[i], x, 120, "right" if mv else "down", int(t * 8) + 1 if mv else 0))
	g.ui.say([{"who": "ceres", "text": "The last shield satellites are in place. The ozone meter reads %d%% and climbing." % s["ozone"]},
		{"who": "narrator", "text": "The four scientists step outside without suits and watch a real sunrise: a dawn."}], func(): _end_stats(tier))


func _end_stats(tier: String) -> void:
	if _screen == null or g.S["scene"] != "ending":
		return
	var s: Dictionary = g.S
	var n: int = s["opt"].size()
	_banner(_screen, tier, "The shield is complete. The sky is healing. The bunker doors are open.")
	var v := _box(_screen, Vector2(240, 548), 800, C["slate"])
	var names := " · ".join(s["opt"].map(func(k): return story.OPTNAME[k]))
	var total := 0
	for k in s.get("stars", {}):
		total += int(s["stars"][k])
	g.ui.rich(v, "[center][color=#fee761][b]OZONE %d%%[/b][/color]\nOptional missions done: %d of 6 · Mistakes: %d\n[color=#8b9bb4]%s\nMission time: %s · Posters found: %d/21 · Mission stars: %d/12\n0–1 Quiet Dawn · 2–3 Rising Dawn · 4+ Golden Dawn[/color][/center]" % [
		s["ozone"], n, s["pen"], names if names != "" else "None: they change the ending", _dur(s["time"]), g.found.size(), total], 18)
	var r: HBoxContainer = g.ui.row(v)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	g.ui.button(r, "WALK BUNKER 4 ▸▸", func(): g.act("freeroam", {}, g.acting_role())).grab_focus.call_deferred()
	if g.is_host():
		g.ui.button(r, "PLAY AGAIN", func(): g.act("again", {}, g.acting_role()), false)


static func _dur(m: float) -> String:
	var tt := int(m - 360)
	return "%d days %d hours" % [tt / 1440, (tt % 1440) / 60]
