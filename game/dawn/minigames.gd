extends RefCounted
## Role minigames: every station task is a small game tied to real science. Owner: Sufi (gameplay).
## Ported from the HTML demo (c6.js). Each one opens a panel; on a win it calls on_win (which asks
## the host to record the task). Nothing here changes the shared state directly.
##
##   timing  stop a moving marker inside a band        sliders  set dials until the readout is right
##   fuel    guess a hidden fuel load with test burns  orbit    launch at perigee / in the launch window
##   wind    pick a launch hour                        scan     neutron scan for ice
##   wires   match cable colours                        wipe     brush dust off solar panels
##   pack    fit cargo under a mass limit               pick     choose the right picture card

const WD := preload("res://game/dawn/world_data.gd")
const RoleSprites := preload("res://game/player/role_sprites.gd")
const P := WD.PAL

var g


## Something to draw on, redrawn every frame. fn(canvas) does the drawing; input(canvas, event) is optional.
class Canvas extends Control:
	var fn: Callable
	var on_input: Callable
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)

	func _gui_input(e: InputEvent) -> void:
		if on_input.is_valid():
			on_input.call(self, e)


class Game extends RefCounted:
	var g
	var box: VBoxContainer
	var foot: HBoxContainer
	var msg: RichTextLabel
	var done := false

	func add(n: Node) -> Node:
		box.add_child(n)
		box.move_child(n, msg.get_index())     # keep the message line and buttons at the bottom
		return n

	func win(on_win: Callable, fact := "") -> void:
		if done:
			return
		done = true
		msg.text = "[b][color=#63c74d]DONE![/color][/b]" + ("  [color=#fee761]★ %s[/color]" % fact if fact != "" else "")
		for c in foot.get_children():
			c.queue_free()
		var b: Button = g.ui.button(foot, "CONTINUE ▸▸", func():
			g.ui.close_panel()
			on_win.call())
		b.grab_focus.call_deferred()

	func fail(text: String) -> void:
		msg.text = "[color=#f6757a]%s[/color]" % text

	func alive() -> bool:
		return is_instance_valid(box) and box.is_inside_tree()


func _open(role: String, title: String, text: String) -> Game:
	var M := Game.new()
	M.g = g
	M.box = g.ui.panel(Color("#262b44"), RoleSprites.TAGS.get(role, P["amber"]), 860, 50)
	g.ui.rich(M.box, "[color=#%s][b]%s TASK[/b][/color]" % [RoleSprites.TAGS[role].to_html(false), RoleSprites.NAMES[role]], 14)
	g.ui.rich(M.box, "[b][color=#feae34]%s[/color][/b]" % title, 22)
	g.ui.rich(M.box, text, 17)
	M.msg = g.ui.rich(M.box, "", 16)
	M.foot = g.ui.row(M.box)
	g.ui.button(M.foot, "LATER", g.ui.close_panel, false)
	return M


func _canvas(M: Game, w: float, h: float, fn: Callable) -> Canvas:
	var c := Canvas.new()
	c.custom_minimum_size = Vector2(w, h)
	c.fn = fn
	M.add(c)
	return c


func _foot_button(M: Game, text: String, fn: Callable) -> Button:
	var b: Button = g.ui.button(M.foot, text, fn)
	M.foot.move_child(b, 0)
	b.grab_focus.call_deferred()
	return b


# 1) TIMING ------------------------------------------------------------------
## bands: [{a, b, c (Color), label}], target: [a, b] in 0..1
func timing(role: String, title: String, text: String, target: Array, on_win: Callable, opts := {}) -> void:
	var M := _open(role, title, text)
	var bands: Array = opts.get("bands", [])
	var hits: int = opts.get("hits", 3)
	var st := {"x": 0.0, "dir": 1.0, "h": 0, "tg": target.duplicate()}
	var W := 800.0
	_canvas(M, W, 70, func(c: Canvas):
		var dt := c.get_process_delta_time()
		if not M.done:
			st["x"] += st["dir"] * (0.55 + st["h"] * 0.3) * dt
			if st["x"] > 1.0:
				st["x"] = 1.0
				st["dir"] = -1.0
			if st["x"] < 0.0:
				st["x"] = 0.0
				st["dir"] = 1.0
		c.draw_rect(Rect2(0, 0, W, 70), P["ink"])
		if bands.is_empty():
			c.draw_rect(Rect2(0, 14, W, 42), P["slate"])
		for b in bands:
			c.draw_rect(Rect2(b["a"] * W, 14, (b["b"] - b["a"]) * W, 42), b["c"])
		var tg: Array = st["tg"]
		c.draw_rect(Rect2(tg[0] * W, 6, (tg[1] - tg[0]) * W, 58), Color(P["green"], 0.5))
		c.draw_rect(Rect2(st["x"] * (W - 6), 0, 6, 70), P["white"])
		for i in hits:
			c.draw_rect(Rect2(8 + i * 22, 60, 16, 6), P["yellow"] if i < st["h"] else P["steel"]))
	if not bands.is_empty():
		var legend := "   ".join(bands.map(func(b): return "[color=#%s]■[/color] %s" % [b["c"].to_html(false), b["label"]]))
		M.add(_rt(legend, 14))
	var stop: Button
	stop = _foot_button(M, opts.get("label", "STOP"), func():
		var tg: Array = st["tg"]
		if st["x"] >= tg[0] and st["x"] <= tg[1]:
			st["h"] += 1
			M.msg.text = "Hit %d of %d" % [st["h"], hits]
			if opts.get("random", false):
				var a := 0.08 + randf() * (0.92 - 0.12 - 0.08)
				st["tg"] = [a, a + 0.12]
			if st["h"] >= hits:
				stop.disabled = true
				M.win(on_win, opts.get("fact", ""))
		else:
			st["h"] = maxi(0, st["h"] - 1)
			M.fail("Missed. Watch the band and try again."))


func _rt(bb: String, size := 16) -> RichTextLabel:
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.scroll_active = false
	t.add_theme_font_size_override("normal_font_size", size)
	t.text = bb
	return t


# 2) SLIDERS -----------------------------------------------------------------
## sliders: [{label, min, max, step, val, unit}], evaluate(vals) -> {ok, meter, read, why}
func sliders(role: String, title: String, text: String, sl: Array, evaluate: Callable, on_win: Callable, fact := "", btn := "LOCK IN") -> void:
	var M := _open(role, title, text)
	var vals := sl.map(func(s): return float(s["val"]))
	var read := _rt("", 18)
	var meter := ProgressBar.new()
	meter.custom_minimum_size = Vector2(0, 14)
	meter.show_percentage = false
	meter.max_value = 1.0
	var upd := func():
		var r: Dictionary = evaluate.call(vals)
		read.text = r["read"]
		meter.value = r.get("meter", 0.0)
		meter.modulate = P["green"] if r["ok"] else P["amber"]
	var first: HSlider
	for i in sl.size():
		var s: Dictionary = sl[i]
		var row := HBoxContainer.new()
		var lab := Label.new()
		lab.text = s["label"]
		lab.custom_minimum_size = Vector2(220, 0)
		var hs := HSlider.new()
		hs.min_value = s["min"]
		hs.max_value = s["max"]
		hs.step = s["step"]
		hs.value = s["val"]
		hs.custom_minimum_size = Vector2(420, 24)
		var out := Label.new()
		out.custom_minimum_size = Vector2(140, 0)
		var unit: String = s.get("unit", "")
		out.text = str(s["val"]) + unit
		hs.value_changed.connect(func(v):
			vals[i] = v
			out.text = (str(int(v)) if is_equal_approx(fmod(v, 1.0), 0.0) else "%.1f" % v) + unit
			upd.call())
		row.add_child(lab)
		row.add_child(hs)
		row.add_child(out)
		M.add(row)
		if first == null:
			first = hs
	M.add(read)
	M.add(meter)
	upd.call()
	var lock: Button
	lock = _foot_button(M, btn, func():
		var r: Dictionary = evaluate.call(vals)
		if r["ok"]:
			lock.disabled = true
			M.win(on_win, fact)
		else:
			M.fail(r.get("why", "Not yet.")))
	first.grab_focus.call_deferred()


# 3) FUEL BURN -----------------------------------------------------------------
func fuel(role: String, title: String, text: String, need: int, on_win: Callable, fact := "") -> void:
	var M := _open(role, title, text)
	var st := {"lo": 100, "hi": 700}
	var row := HBoxContainer.new()
	var lab := Label.new()
	lab.text = "Fuel load"
	lab.custom_minimum_size = Vector2(160, 0)
	var hs := HSlider.new()
	hs.min_value = 100
	hs.max_value = 700
	hs.step = 10
	hs.value = 250
	hs.custom_minimum_size = Vector2(460, 24)
	var out := Label.new()
	out.text = "250 kg"
	row.add_child(lab)
	row.add_child(hs)
	row.add_child(out)
	M.add(row)
	var rng := _rt("", 18)
	M.add(rng)
	var upd := func():
		out.text = "%d kg" % int(hs.value)
		rng.text = "Known range: [b]%d–%d kg[/b]" % [st["lo"], st["hi"]]
	hs.value_changed.connect(func(_v): upd.call())
	upd.call()
	var test: Button
	test = _foot_button(M, "TEST BURN", func():
		var f := int(hs.value)
		if f < need:
			st["lo"] = maxi(st["lo"], f)
			upd.call()
			M.fail("Ran dry %d km short of orbit. Need more." % (roundi((1.0 - float(f) / need) * 120) + 8))
		elif f > need * 1.3:
			st["hi"] = mini(st["hi"], f)
			upd.call()
			M.fail("So heavy with fuel it barely lifts off. Need less.")
		else:
			test.disabled = true
			M.win(on_win, ("Within 10% of the need: efficient trajectory! " if f <= need * 1.1 else "Made orbit, with spare fuel. ") + fact))
	hs.grab_focus.call_deferred()


# 4) ORBIT ---------------------------------------------------------------------
## mode "perigee": launch when the Moon is closest · mode "phase": launch when Earth is ~75° behind Mars
func orbit(role: String, title: String, text: String, mode: String, on_win: Callable, fact := "") -> void:
	var M := _open(role, title, text)
	var st := {"th": randf() * TAU, "te": randf() * TAU, "tm": randf() * TAU, "ok": false, "km": 0}
	var read := _rt("", 18)
	var S := 4.0                        # canvas pixels per demo pixel
	_canvas(M, 200 * S, 110 * S, func(c: Canvas):
		var dt := c.get_process_delta_time()
		c.draw_rect(Rect2(0, 0, 800, 440), P["ink"])
		for i in 40:
			c.draw_rect(Rect2(fposmod(i * 77.7, 800), fposmod(i * 41.3, 440), 3, 3), P["steel"])
		if mode == "perigee":
			var a := 66.0
			var e := 0.55
			var b := a * sqrt(1.0 - e * e)
			var cy := 55.0
			var fx := 100.0 - a * e
			for k in 64:
				var tt := k / 64.0 * TAU
				c.draw_rect(Rect2((100 + a * cos(tt)) * S, (cy + b * sin(tt)) * S, 3, 3), P["slate"])
			var x := 100 + a * cos(st["th"])
			var y := cy + b * sin(st["th"])
			var r := Vector2(x - fx, y - cy).length()
			var rmin := a * (1 - e)
			var rmax := a * (1 + e)
			st["th"] += dt * (0.45 + 1.5 * (rmin * rmin) / (r * r))
			c.draw_circle(Vector2(fx, cy) * S, 8 * S, P["blue"])
			c.draw_circle(Vector2(x, y) * S, 4 * S, P["light"])
			c.draw_rect(Rect2((100 - a - 2) * S, (cy - 12) * S, 10 * S, 24 * S), Color(P["green"], 0.3))
			st["km"] = int(round((363300 + (405500 - 363300) * ((r - rmin) / (rmax - rmin))) / 100.0) * 100)
			st["ok"] = st["km"] < 368000
			read.text = "Earth–Moon distance: [b][color=%s]%s km[/color][/b] %s" % ["#63c74d" if st["ok"] else "#ffffff", _thousands(st["km"]), "· CLOSEST: GO!" if st["ok"] else ""]
		else:
			var sx := 100.0
			var sy := 55.0
			st["te"] += dt * 1.6
			st["tm"] += dt * 0.85
			c.draw_circle(Vector2(sx, sy) * S, 7 * S, P["yellow"])
			for rr in [26.0, 46.0]:
				c.draw_arc(Vector2(sx, sy) * S, rr * S, 0, TAU, 64, P["slate"], 2.0)
			var ep := Vector2(sx + 26 * cos(st["te"]), sy + 26 * sin(st["te"]))
			var mp := Vector2(sx + 46 * cos(st["tm"]), sy + 46 * sin(st["tm"]))
			c.draw_circle(ep * S, 4 * S, P["blue"])
			c.draw_circle(mp * S, 4 * S, P["rust"])
			var ph := fmod(rad_to_deg(st["te"] - st["tm"]), 360.0)
			if ph > 180:
				ph -= 360
			if ph < -180:
				ph += 360
			st["ok"] = absf(ph + 75.0) < 12.0
			if st["ok"]:
				c.draw_line(mp * S, Vector2(sx, sy) * S, P["green"], 3.0)
				c.draw_line(Vector2(sx, sy) * S, ep * S, P["green"], 3.0)
			read.text = "[b][color=#63c74d]LAUNCH WINDOW OPEN[/color][/b] · Earth will be waiting when we arrive" if st["ok"] else "Earth is %d° %s Mars · window closed" % [absi(roundi(ph)), "behind" if ph < 0 else "ahead of"])
	M.add(read)
	var go: Button
	go = _foot_button(M, "LAUNCH NOW", func():
		if st["ok"]:
			go.disabled = true
			M.win(on_win, fact)
		else:
			M.fail(("The Moon is %s km away. Wait until it swings closer." % _thousands(st["km"])) if mode == "perigee" else "The planets are not lined up. Wait for the window."))


static func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


# 5) WIND ----------------------------------------------------------------------
func wind(role: String, on_win: Callable) -> void:
	var M := _open(role, "PICK THE LAUNCH WINDOW", "Rockets scrub launches in strong wind. Pick an hour in daylight (06–18) with wind under 20 km/h and no UV storm forecast.")
	var hrs := []
	var good := 0
	for i in 12:
		var h := i * 2
		var w := 8 + randi() % 40
		var storm := randf() < 0.25
		hrs.append({"h": h, "w": w, "storm": storm})
		if h >= 6 and h <= 18 and w < 20 and not storm:
			good += 1
	if good == 0:
		var k := 3 + randi() % 5
		hrs[k]["w"] = 12
		hrs[k]["storm"] = false
	var grid := GridContainer.new()
	grid.columns = 6
	M.add(grid)
	for s in hrs:
		var b := Button.new()
		b.text = "%02d:00\n%d km/h%s%s" % [s["h"], s["w"], "\nUV STORM" if s["storm"] else "", "\nnight" if s["h"] < 6 or s["h"] > 18 else ""]
		b.custom_minimum_size = Vector2(130, 78)
		b.pressed.connect(func():
			if s["h"] >= 6 and s["h"] <= 18 and s["w"] < 20 and not s["storm"]:
				b.modulate = P["green"]
				for x in grid.get_children():
					x.disabled = true
				M.win(on_win, "Real launches are scrubbed for high winds all the time.")
			else:
				b.modulate = P["rose"]
				M.fail("A UV storm would fry the sensor." if s["storm"] else ("We need daylight to recover the rocket." if s["h"] < 6 or s["h"] > 18 else "%d km/h is too windy." % s["w"])))
		grid.add_child(b)
	grid.get_child(0).grab_focus.call_deferred()


# 6) NEUTRON SCAN --------------------------------------------------------------
func scan(role: String, on_win: Callable, on_fail: Callable) -> void:
	var M := _open(role, "NEUTRON SCAN", "Hydrogen soaks up neutrons, so the ice is where the count is LOWEST. You have 6 scans. Shadowed cells are darker.")
	var ice := Vector2i(randi() % 2, 1 + randi() % 3)
	var st := {"left": 6}
	var cnt := _rt("Scans left: [b]6[/b]", 18)
	M.add(cnt)
	var grid := GridContainer.new()
	grid.columns = 6
	M.add(grid)
	for y in 4:
		for x in 6:
			var b := Button.new()
			b.custom_minimum_size = Vector2(120, 50)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("#14161c") if x < 2 else (Color("#2a2d35") if x < 4 else Color("#3a3626"))
			b.add_theme_stylebox_override("normal", sb)
			b.pressed.connect(func():
				if b.has_meta("done") or st["left"] <= 0:
					return
				b.set_meta("done", true)
				st["left"] -= 1
				var d := Vector2(x - ice.x, y - ice.y).length()
				if d == 0:
					b.text = "ICE"
					b.modulate = P["cyan"]
					for z in grid.get_children():
						z.disabled = true
					M.win(on_win, "NASA's LRO and LCROSS found water ice in shadowed south-pole craters.")
					return
				b.text = str(roundi(100 - 55 * exp(-d * d / 2.2) + randf() * 4))
				cnt.text = "Scans left: [b]%d[/b]" % st["left"]
				if st["left"] <= 0:
					for z in grid.get_children():
						z.disabled = true
					M.fail("Out of scans. The orbiter time is used up.")
					for c in M.foot.get_children():
						c.queue_free()
					g.ui.button(M.foot, "OK", func():
						g.ui.close_panel()
						on_fail.call()))
			grid.add_child(b)
	grid.get_child(0).grab_focus.call_deferred()


# 7) WIRES ---------------------------------------------------------------------
func wires(role: String, title: String, text: String, on_win: Callable) -> void:
	var M := _open(role, title, text)
	var cols := [P["red"], P["yellow"], P["sky"], P["pink"]]
	var right := [0, 1, 2, 3]
	right.shuffle()
	var st := {"sel": -1, "done": []}
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var lcol := VBoxContainer.new()
	var rcol := VBoxContainer.new()
	var c := Canvas.new()
	c.custom_minimum_size = Vector2(320, 4 * 56)
	c.fn = func(cv: Canvas):
		for i in st["done"]:
			var j: int = right.find(i)
			cv.draw_line(Vector2(0, 28 + i * 56), Vector2(320, 28 + j * 56), cols[i], 8.0)
	row.add_child(lcol)
	row.add_child(c)
	row.add_child(rcol)
	M.add(row)
	var paint := func(b: Button, col: Color):
		for st_name in ["normal", "hover", "pressed", "focus", "disabled"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = col if st_name != "disabled" else col.darkened(0.6)
			sb.border_color = P["white"] if st_name in ["hover", "focus"] else P["ink"]
			sb.set_border_width_all(3)
			b.add_theme_stylebox_override(st_name, sb)
	var lb := []
	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = Vector2(90, 50)
		paint.call(b, cols[i])
		b.pressed.connect(func():
			if i in st["done"]:
				return
			st["sel"] = i
			M.msg.text = "Now pick the matching socket on the right.")
		lcol.add_child(b)
		lb.append(b)
	for j in 4:
		var ci: int = right[j]
		var b2 := Button.new()
		b2.custom_minimum_size = Vector2(90, 50)
		paint.call(b2, cols[ci])
		b2.pressed.connect(func():
			if st["sel"] < 0:
				return
			if st["sel"] == ci:
				st["done"].append(ci)
				lb[ci].disabled = true
				b2.disabled = true
				st["sel"] = -1
				M.msg.text = ""
				if st["done"].size() == 4:
					M.win(on_win, "Real spacecraft wiring is colour-coded and checked twice.")
			else:
				st["sel"] = -1
				M.fail("Wrong socket. Match the colours."))
		rcol.add_child(b2)
	lb[0].grab_focus.call_deferred()


# 8) WIPE ----------------------------------------------------------------------
func wipe(role: String, on_win: Callable) -> void:
	var M := _open(role, "CLEAN THE PANELS", "Drag across the panels (or press BRUSH) to sweep the dust off. Dusty panels make far less power.")
	var dust := []
	for i in 9 * 20:
		dust.append(1.0)
	var read := _rt("", 18)
	var S := 4.0
	var pct := func() -> int:
		var sum := 0.0
		for v in dust:
			sum += v
		return roundi(100 - sum / dust.size() * 100)
	var check := func():
		var p: int = pct.call()
		read.text = "Clean: [b]%d%%[/b]" % p
		if p >= 95:
			M.win(on_win, "Wind gusts cleaned Spirit and Opportunity's panels and kept them alive for years.")
	var c := _canvas(M, 160 * S, 72 * S, func(cv: Canvas):
		cv.draw_rect(Rect2(0, 0, 640, 288), P["ink"])
		for x in range(0, 160, 20):
			cv.draw_rect(Rect2((x + 1) * S, S, 18 * S, 70 * S), Color("#124e89"))
			cv.draw_rect(Rect2((x + 1) * S, S, 18 * S, S), Color("#2c6fb0"))
		for i in dust.size():
			if dust[i] > 0:
				cv.draw_rect(Rect2((i % 20) * 8 * S, (i / 20) * 8 * S, 8 * S, 8 * S), Color(P["rust"], 0.35 + 0.6 * dust[i])))
	c.mouse_default_cursor_shape = Control.CURSOR_CROSS
	c.on_input = func(cv: Canvas, e: InputEvent):
		var drag = (e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT)) or (e is InputEventMouseButton and e.pressed)
		if drag:
			var pos: Vector2 = e.position / S
			for i in dust.size():
				if Vector2((i % 20) * 8 + 4, (i / 20) * 8 + 4).distance_to(pos) < 10:
					dust[i] = maxf(0.0, dust[i] - 0.5)
			check.call()
	M.add(read)
	check.call()
	_foot_button(M, "BRUSH", func():
		var i := dust.find_custom(func(v): return v > 0)
		if i < 0:
			return
		var row: int = i / 20
		for k in range(row * 20, row * 20 + 20):
			dust[k] = maxf(0.0, dust[k] - 0.5)
		check.call())


# 9) PACK ----------------------------------------------------------------------
## items: [{n, kg, req}]
func pack(role: String, title: String, text: String, items: Array, cap: int, on_win: Callable, opts := {}) -> void:
	var M := _open(role, title, text)
	var min_kg: int = opts.get("min", 0)
	var sel := {}
	var read := _rt("", 18)
	var check := func() -> Dictionary:
		var kg := 0
		var miss := []
		for i in items.size():
			if sel.get(i, false):
				kg += items[i]["kg"]
			elif items[i].get("req", false):
				miss.append(items[i]["n"])
		if not miss.is_empty():
			return {"ok": false, "kg": kg, "why": "Missing: " + ", ".join(miss)}
		if kg > cap:
			return {"ok": false, "kg": kg, "why": "%d kg over the limit." % (kg - cap)}
		if kg < min_kg:
			return {"ok": false, "kg": kg, "why": "Cargo must be at least %d kg to be worth the launch." % min_kg}
		return {"ok": true, "kg": kg}
	var upd := func():
		var r: Dictionary = check.call()
		read.text = "Mass: [b][color=%s]%d / %d kg[/color][/b]%s" % ["#f6757a" if r["kg"] > cap else "#ffffff", r["kg"], cap, (" · at least %d kg" % min_kg) if min_kg > 0 else ""]
	var grid := GridContainer.new()
	grid.columns = 2
	M.add(grid)
	var first: CheckBox
	for i in items.size():
		var it: Dictionary = items[i]
		var cb := CheckBox.new()
		cb.text = "%s · %d kg%s" % [it["n"], it["kg"], "  (needed)" if it.get("req", false) else ""]
		cb.add_theme_font_size_override("font_size", 17)
		cb.toggled.connect(func(on):
			sel[i] = on
			upd.call())
		grid.add_child(cb)
		if first == null:
			first = cb
	M.add(read)
	upd.call()
	var lock: Button
	lock = _foot_button(M, "SEAL CARGO", func():
		var r: Dictionary = check.call()
		if r["ok"]:
			lock.disabled = true
			M.win(on_win, opts.get("fact", ""))
		else:
			M.fail(r["why"]))
	first.grab_focus.call_deferred()


# 10) PICK ---------------------------------------------------------------------
## cards: [{label, sub, draw (fn(canvas, rect)), ok, why}]
func pick(role: String, title: String, text: String, cards: Array, on_win: Callable, opts := {}) -> void:
	var M := _open(role, title, text)
	var multi: int = opts.get("multi", 1)
	var st := {"got": 0}
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	M.add(row)
	var first: Button
	for cd in cards:
		var col := VBoxContainer.new()
		var pic := Canvas.new()
		pic.custom_minimum_size = Vector2(144, 96)
		var draw_fn: Callable = cd["draw"]
		pic.fn = func(cv: Canvas): draw_fn.call(cv, Rect2(0, 0, 144, 96))
		var b := Button.new()
		b.text = cd["label"] + ("\n" + cd["sub"] if cd.get("sub", "") != "" else "")
		b.custom_minimum_size = Vector2(144, 50)
		b.pressed.connect(func():
			if cd.get("ok", false):
				b.disabled = true
				b.modulate = P["green"]
				st["got"] += 1
				if st["got"] >= multi:
					for c2 in row.get_children():
						c2.get_child(1).disabled = true
					M.win(on_win, opts.get("fact", ""))
			else:
				M.fail(cd.get("why", "Not that one.")))
		col.add_child(pic)
		col.add_child(b)
		row.add_child(col)
		if first == null:
			first = b
	first.grab_focus.call_deferred()
