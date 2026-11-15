extends "res://game/dawn/minigames/mini_game.gd"
## ACT 1 · ENGINEER · Build the UV payload cube. Drag each missing part onto the hole with the
## same shape on the flat CubeSat net. Earth Workshop, before the rocket designer.
## Picture: assets/minigames/cubesat_net.jpg (CSA "CubeSat paper model"). Until it is uploaded
## the net and the parts are drawn as simple pixel shapes.

const F := 350.0 / 1065.0       # picture px -> hole size on screen
const KK := 150.0 / 110.0       # hole px -> picture px
const NX := 8.0
const NY := 4.0
const NOX := 60.0
const NOY := 75.0
const TS := 1.5                 # tray parts are drawn 1.5x bigger, easy to grab
const NET_W := 1119.0           # size of the CSA picture in px
const NET_H := 1452.0
const INFO := {
	"panel": ["Solar panel", "Turns sunlight into electricity. A cube needs power the moment it leaves the rocket."],
	"board": ["Computer board and ports", "The cube's brain: the computer and the plugs engineers use to test it before launch."],
	"lens": ["Camera lens", "Lets the cube take pictures."],
	"sensor": ["Sensor window", "The window for the UV sensor: the reason this cube flies on the sounding rocket."],
	"battery": ["Battery cells", "Store electricity so the cube still works in Earth's shadow."],
	"port": ["Connector deck", "Where the radio and the cable connector sit."],
	"logo": ["Agency badge", "Every cube carries its owner's mark."]}
## [type, x0, y0, x1, y1] in the CSA picture (before the NOX/NOY offset)
const PARTS := [["panel", 375, 133, 560, 232], ["panel", 375, 236, 560, 332], ["board", 368, 372, 545, 478], ["panel", 375, 481, 560, 583],
	["panel", 625, 385, 810, 480], ["lens", 650, 516, 694, 560], ["sensor", 745, 508, 807, 566], ["panel", 375, 635, 560, 728],
	["panel", 375, 732, 560, 832], ["battery", 418, 935, 517, 1022], ["port", 441, 1053, 492, 1092], ["logo", 158, 380, 272, 480]]
## faces of the net in picture px, for the drawn net (no picture yet)
const FACES := [[390, 45, 725, 385], [50, 385, 390, 725], [390, 385, 725, 725], [725, 385, 1060, 725], [390, 725, 725, 1060], [390, 1060, 725, 1400]]
const COLS := {"panel": Color("#124e89"), "board": Color("#3e8948"), "lens": Color("#262b44"), "sensor": Color("#2ce8f5"),
	"battery": Color("#feae34"), "port": Color("#8b9bb4"), "logo": Color("#e43b44")}

var holes: Array = []
var pieces: Array = []
var held = null                 # {p, ox, oy}
var miss := 0
var placed := 0


func _init() -> void:
	title = "BUILD THE UV PAYLOAD CUBE"
	goal = "This flat net folds into the 10 cm cube that rides on the rocket. Some parts are missing. Drag each part from the tray to the hole with the same shape. Wrong drops fly back."


func setup() -> void:
	holes.clear()
	pieces.clear()
	held = null
	miss = 0
	placed = 0
	for pt in PARTS:
		holes.append({"t": pt[0], "x": NX + (pt[1] - NOX) * F, "y": NY + (pt[2] - NOY) * F, "w": (pt[3] - pt[1]) * F, "h": (pt[4] - pt[2]) * F,
			"done": false, "flash": 0.0, "sx": (pt[1] - NOX) * KK, "sy": (pt[2] - NOY) * KK, "sw": (pt[3] - pt[1]) * KK, "sh": (pt[4] - pt[2]) * KK})
	var order := range(holes.size())
	order.shuffle()
	var x := 302.0
	var y := 34.0
	var row_h := 0.0
	for i in order:
		var h: Dictionary = holes[i]
		var w: float = h["w"] * TS
		var hh: float = h["h"] * TS
		if x + w > 628:
			x = 302.0
			y += row_h + 10
			row_h = 0.0
		pieces.append({"t": h["t"], "src": h, "w": w, "h": hh, "x": x, "y": y, "hx": x, "hy": y, "lock": false})
		x += w + 10
		row_h = maxf(row_h, hh)
	say("Pick up a part to see what it does.")


func _hit(p: Dictionary, q: Vector2) -> bool:
	return q.x >= p["x"] - 4 and q.x <= p["x"] + p["w"] + 4 and q.y >= p["y"] - 4 and q.y <= p["y"] + p["h"] + 4


func press(q: Vector2) -> void:
	for i in range(pieces.size() - 1, -1, -1):
		var p: Dictionary = pieces[i]
		if not p["lock"] and _hit(p, q):
			held = {"p": p, "ox": q.x - p["x"], "oy": q.y - p["y"]}
			pieces.remove_at(i)
			pieces.append(p)          # draw on top
			say("%s: %s" % INFO[p["t"]])
			return


func drag(q: Vector2) -> void:
	if held:
		held["p"]["x"] = q.x - held["ox"]
		held["p"]["y"] = q.y - held["oy"]


func release(_q: Vector2) -> void:
	if held == null:
		return
	var p: Dictionary = held["p"]
	held = null
	var c := Vector2(p["x"] + p["w"] / 2.0, p["y"] + p["h"] / 2.0)
	var best = null
	var bd := 1e9
	for s in holes:
		if s["done"] or s["t"] != p["t"]:
			continue
		var d := c.distance_to(Vector2(s["x"] + s["w"] / 2.0, s["y"] + s["h"] / 2.0))
		if d < bd:
			bd = d
			best = s
	if best and bd < 26:
		best["done"] = true
		p["lock"] = true
		placed += 1
		if placed == holes.size():
			finish(3 if miss == 0 else (2 if miss <= 2 else 1),
				"All 12 parts placed with %d wrong drops. Every part has its own place: power, data, sensing, communication." % miss,
				"A 1U CubeSat is a 10 cm cube of about 1 kg; NASA's PhoneSat flew a smartphone as its brain.")
		else:
			say("%s locked in. %d to go." % [INFO[p["t"]][0], holes.size() - placed], "ok")
	else:
		miss += 1
		for s in holes:
			if not s["done"] and c.x > s["x"] - 6 and c.x < s["x"] + s["w"] + 6 and c.y > s["y"] - 6 and c.y < s["y"] + s["h"] + 6:
				s["flash"] = 0.6
		say("%s doesn't fit there: wrong shape. Back to the tray." % INFO[p["t"]][0], "bad")


func tick(dt: float) -> void:
	for s in holes:
		s["flash"] = maxf(0.0, s["flash"] - dt)
	for p in pieces:
		if not p["lock"] and (held == null or held["p"] != p):
			p["x"] += (p["hx"] - p["x"]) * minf(1.0, dt * 12)
			p["y"] += (p["hy"] - p["y"]) * minf(1.0, dt * 12)


func paint() -> void:
	R(0, 0, W, H, P["nv"])
	var net := _pic("cubesat_net")
	var nw := NET_W * F / KK
	var nh := NET_H * F / KK
	RR(NX - 3, NY - 1, nw + 6, H - 6, P["w"])
	if net:
		draw_texture_rect(net, Rect2(NX, NY, nw, nh), false)
	else:
		for f in FACES:
			RR(NX + f[0] * F / KK, NY + f[1] * F / KK, (f[2] - f[0]) * F / KK, (f[3] - f[1]) * F / KK, Color("#f2f4f8"), P["gy"], 2)
		T("CSA NET PICTURE COMING SOON", NX + nw / 2, NY + nh - 14, P["gy"], 1, 9)
	for s in holes:
		if s["done"]:
			_part(s["t"], s["x"], s["y"], s["w"], s["h"], s, net)
			RR(s["x"], s["y"], s["w"], s["h"], null, P["g"], 2)
			continue
		var col: Color = P["r"] if s["flash"] > 0 else P["pk"]
		_shape(s, P["w"])
		_dashed_box(s["x"], s["y"], s["w"], s["h"], col)
		if s["flash"] > 0:
			_shape(s, Color(P["r"], 0.4))
	RR(292, 6, 342, 348, Color("#181425", 0.9), P["sl"], 2)
	T("PARTS TRAY: drag to the matching hole", 463, 14, P["lg"], 1, 12)
	for p in pieces:
		if p["lock"]:
			continue
		if held and held["p"] == p:
			R(p["x"] + 4, p["y"] + 6, p["w"], p["h"], Color(0, 0, 0, 0.5))
		RR(p["x"] - 2, p["y"] - 2, p["w"] + 4, p["h"] + 4, P["w"])
		_part(p["t"], p["x"], p["y"], p["w"], p["h"], p["src"], net)
	T("PLACED %d/12   WRONG %d" % [placed, miss], 463, 334, P["y"], 1, 13)


## One part: the cut-out from the CSA picture, or a pixel drawing until the picture is uploaded.
func _part(tp: String, x: float, y: float, w: float, h: float, src: Dictionary, net: Texture2D) -> void:
	if net:
		draw_texture_rect_region(net, Rect2(x, y, w, h), Rect2(src["sx"], src["sy"], src["sw"], src["sh"]))
		return
	var c: Color = COLS[tp]
	match tp:
		"lens", "logo":
			disc(x + w / 2, y + h / 2, minf(w, h) / 2, c)
			disc(x + w / 2, y + h / 2, minf(w, h) / 4, P["lg"] if tp == "lens" else P["w"])
		"battery":
			R(x, y, w, h, Color("#3a4466"))
			for i in 4:
				for j in 2:
					R(x + 3 + i * (w - 6) / 4.0, y + 3 + j * (h - 6) / 2.0, (w - 6) / 4.0 - 2, (h - 6) / 2.0 - 2, c)
		"panel":
			R(x, y, w, h, c)
			var gx := x + 4
			while gx < x + w:
				line(gx, y, gx, y + h, Color("#0099db"), 1)
				gx += 6
			line(x, y + h / 2, x + w, y + h / 2, Color("#0099db"), 1)
		"board":
			R(x, y, w, h, c)
			R(x + w * 0.1, y + h * 0.15, w * 0.3, h * 0.2, P["k"])
			R(x + w * 0.55, y + h * 0.15, w * 0.15, h * 0.3, P["lg"])
			R(x + w * 0.1, y + h * 0.6, w * 0.8, h * 0.25, Color("#124e89"))
		_:
			R(x, y, w, h, c)
			RR(x + w * 0.2, y + h * 0.2, w * 0.6, h * 0.6, null, P["k"], 2)


func _shape(s: Dictionary, col: Color) -> void:
	if s["t"] == "lens" or s["t"] == "logo":
		disc(s["x"] + s["w"] / 2, s["y"] + s["h"] / 2, minf(s["w"], s["h"]) / 2, col)
	else:
		R(s["x"], s["y"], s["w"], s["h"], col)


func _dashed_box(x: float, y: float, w: float, h: float, col: Color) -> void:
	dline(x, y, x + w, y, col, 2, 4)
	dline(x + w, y, x + w, y + h, col, 2, 4)
	dline(x + w, y + h, x, y + h, col, 2, 4)
	dline(x, y + h, x, y, col, 2, 4)
