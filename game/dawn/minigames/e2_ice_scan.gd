extends "res://game/dawn/minigames/mini_game.gd"
## ACT 2 · ENGINEER · Ice scan. The scanner lens shows TEMPERATURE (Diviner) on top and NEUTRONS
## (LEND) below. Ice needs both: very cold AND few neutrons. 3 drills. Moon Ice Mine, before the drill hold.
## Real: cold traps stay below ~120 K, Cabeus crater ~37 K (LCROSS / LRO); few neutrons = hydrogen.
## Game: the map and values per cell are generated (swap for LRO Diviner / LEND maps later).
## Photos: assets/minigames/diviner.jpg and lend.jpg.

const CW := 80
const CH := 45
const TSTOPS := [[30, [122, 69, 224]], [90, [58, 166, 255]], [120, [127, 224, 224]], [170, [255, 212, 92]], [250, [255, 93, 115]]]
const NSTOPS := [[0.55, [138, 79, 214]], [0.8, [154, 140, 207]], [0.9, [107, 118, 148]], [1.0, [200, 208, 230]]]

var cells: Array = []
var drills := 3
var terr: ImageTexture
var tl: ImageTexture
var nl: ImageTexture


func _init() -> void:
	title = "ICE SCAN"
	goal = "Move the scanner over the Moon's south pole. TOP half = temperature (Diviner), BOTTOM half = neutron count (LEND). Ice needs BOTH: very cold AND few neutrons. Click to drill (3 drills)."


func setup() -> void:
	drills = 3
	var cr := [[22, 14, 9, 1, 1], [52, 30, 10, 1, 0], [62, 10, 7, 1, 1], [30, 34, 7, 0, 0], [8, 36, 5, 0, 0]]
	cr.shuffle()
	cells = []
	for y in CH:
		for x in CW:
			var elev := 0.5 + 0.15 * sin(x * 0.3 + y * 0.2) + 0.1 * randf()
			var temp := randf_range(190, 250)
			var neu := randf_range(0.9, 1.0)
			var shade := 0
			for c in cr:
				var d := Vector2(x - c[0], y - c[1]).length()
				if d < c[2]:
					elev -= 0.35 * (1 - d / c[2])
					if c[3] and d < c[2] * 0.85:
						temp = randf_range(30, 90)
						shade = 1
						if c[4]:
							neu = randf_range(0.55, 0.72) + 0.15 * (d / c[2])
					elif not c[3]:
						temp = randf_range(170, 230)
				if absf(d - c[2]) < 1:
					elev += 0.25
			cells.append({"elev": elev, "temp": temp, "neu": neu, "shade": shade})
	for y in range(38, 44):
		for x in range(66, 76):
			var q: Dictionary = cells[y * CW + x]
			q["neu"] = randf_range(0.7, 0.78)       # warm hydrated rock: few neutrons but not ice
			q["temp"] = randf_range(200, 240)
	terr = _layer(func(q): var v: float = (20 + q["elev"] * 22) if q["shade"] else (70 + q["elev"] * 120); return Color8(int(v), int(v), int(minf(255, v * 1.04))))
	tl = _layer(func(q): return _stops(TSTOPS, q["temp"]))
	nl = _layer(func(q): return _stops(NSTOPS, q["neu"]))
	say("Move the scanner. Read both halves before you drill.")


func _layer(fn: Callable) -> ImageTexture:
	var img := Image.create(CW, CH, false, Image.FORMAT_RGB8)
	for i in cells.size():
		img.set_pixel(i % CW, i / CW, fn.call(cells[i]))
	img.resize(CW * 8, CH * 8, Image.INTERPOLATE_NEAREST)     # blocky cells stay sharp
	return ImageTexture.create_from_image(img)


func _stops(st: Array, v: float) -> Color:
	if v <= st[0][0]:
		return Color8(st[0][1][0], st[0][1][1], st[0][1][2])
	for i in range(1, st.size()):
		if v <= st[i][0]:
			var f: float = (v - st[i - 1][0]) / (st[i][0] - st[i - 1][0])
			var a: Array = st[i - 1][1]
			var b: Array = st[i][1]
			return Color8(int(lerpf(a[0], b[0], f)), int(lerpf(a[1], b[1], f)), int(lerpf(a[2], b[2], f)))
	var l: Array = st[st.size() - 1][1]
	return Color8(l[0], l[1], l[2])


func _cell(x: float, y: float) -> Dictionary:
	return cells[clampi(floori(y / 8), 0, CH - 1) * CW + clampi(floori(x / 8), 0, CW - 1)]


func press(q: Vector2) -> void:
	if drills <= 0:
		return
	var lens := _lens_center()
	var c := _cell(lens.x, lens.y)
	drills -= 1
	var used := 3 - drills
	var tk := roundi(c["temp"])
	var np := roundi(c["neu"] * 100)
	if c["temp"] < 120 and c["neu"] < 0.8:
		finish(3 if used == 1 else (2 if used == 2 else 1),
			"Ice! %d K and %d%% neutrons. Cold alone could be dry rock. Few neutrons alone could be warm hydrated rock. Two instruments agreeing make it ice." % [tk, np],
			"LRO Diviner mapped the coldest places on the Moon and LEND counted neutrons. LCROSS then hit Cabeus crater (~37 K) and found water.")
		return
	elif c["temp"] < 120:
		say("Cold (%d K) but neutrons are high (%d%%): no hydrogen, so no ice. %d drills left." % [tk, np, drills], "bad")
	elif c["neu"] < 0.8:
		say("Few neutrons (%d%%) but it's %d K. Ice would boil away in sunlight. %d drills left." % [np, tk, drills], "bad")
	else:
		say("Warm and dry (%d K, %d%% neutrons). %d drills left." % [tk, np, drills], "bad")
	if drills <= 0:
		finish(0, "Out of drills. Look for places where BOTH halves agree: blue on top and purple on the bottom.",
			"LRO Diviner + LEND together pointed to water ice in permanently shadowed craters.")


func _lens_center() -> Vector2:
	var m := mouse if mouse.x > -500 else Vector2(W / 2, H / 2)
	return Vector2(clampf(m.x, 100, W - 100), clampf(m.y, 72, H - 72))


func paint() -> void:
	if terr == null:
		return
	draw_texture_rect(terr, Rect2(0, 0, W, H), false)
	var m := _lens_center()
	var lw := 200.0
	var lh := 144.0
	var lx := m.x - 100
	var ly := m.y - 72
	var half := m.y - ly
	draw_texture_rect_region(tl, Rect2(lx, ly, lw, half), Rect2(lx, ly, lw, half))
	draw_texture_rect_region(nl, Rect2(lx, m.y, lw, lh - half), Rect2(lx, m.y, lw, lh - half))
	RR(lx - 2, ly - 2, lw + 4, lh + 4, null, P["b"], 3)
	line(lx, m.y, lx + lw, m.y, Color(1, 1, 1, 0.85), 1.5)
	line(m.x - 8, m.y, m.x + 8, m.y, P["w"], 2)
	line(m.x, m.y - 8, m.x, m.y + 8, P["w"], 2)
	pic("diviner", lx + 6, ly + 6, 38, 28)
	T("Diviner: TEMPERATURE", lx + 50, ly + 8, P["w"], 0, 11)
	T("blue = cold", lx + 50, ly + 22, Color("#cfe8ff"), 0, 10)
	pic("lend", lx + 6, ly + lh - 34, 38, 28)
	T("LEND: NEUTRONS", lx + 50, ly + lh - 32, P["w"], 0, 11)
	T("purple = few neutrons", lx + 50, ly + lh - 18, Color("#e6dcff"), 0, 10)
	var c := _cell(m.x, m.y)
	RR(8, 8, 176, 50, Color("#181425", 0.92), P["b"], 2)
	T("TEMP  %d K" % roundi(c["temp"]), 16, 14, P["b"] if c["temp"] < 120 else P["r"], 0, 15)
	T("NEUTRONS  %d%%" % roundi(c["neu"] * 100), 16, 34, Color("#b55088") if c["neu"] < 0.8 else P["lg"], 0, 15)
	T("DRILLS %d" % drills, W - 12, 10, P["y"], 2, 16)
	T("click to drill", W - 12, 30, P["lg"], 2, 11)