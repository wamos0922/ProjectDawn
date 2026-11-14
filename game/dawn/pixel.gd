extends Control
## A 320x180 pixel canvas scaled up 4x (1280x720), with the drawing helpers and backgrounds of the
## HTML demo (c1.js) so the full-screen animations look the same. Owner: Sufi (art code).
##
##   var pc := Pixel.new(); pc.painter = func(pc, t, dt): pc.dusk_sky(t); pc.landscape(t); ...
## Coordinates are demo pixels (0..320, 0..180). Everything is redrawn every frame.

const WD := preload("res://game/dawn/world_data.gd")
const RoleSprites := preload("res://game/player/role_sprites.gd")
const W := 320
const H := 180
const P := {
	"ink": Color("#181425"), "navy": Color("#262b44"), "slate": Color("#3a4466"), "steel": Color("#5a6988"), "grey": Color("#8b9bb4"),
	"light": Color("#c0cbdc"), "white": Color("#ffffff"), "red": Color("#e43b44"), "dred": Color("#a22633"), "magenta": Color("#ff0044"),
	"orange": Color("#f77622"), "amber": Color("#feae34"), "yellow": Color("#fee761"), "green": Color("#63c74d"), "dgreen": Color("#3e8948"),
	"forest": Color("#265c42"), "teal": Color("#193c3e"), "blue": Color("#124e89"), "sky": Color("#0099db"), "cyan": Color("#2ce8f5"),
	"plum": Color("#68386c"), "pink": Color("#b55088"), "rose": Color("#f6757a"), "skin": Color("#e8b796"), "tan": Color("#c28569"),
	"brown": Color("#733e39"), "dbrown": Color("#3e2731"), "sand": Color("#ead4aa"), "peach": Color("#e4a672"), "clay": Color("#b86f50"),
	"rust": Color("#be4a2f"), "burnt": Color("#d77643"),
}
const SKY := ["ink", "navy", "plum", "pink", "rose", "peach", "amber"]

static var STARS := []
static var STARS2 := []
static var MTN_FAR := []
static var MTN_NEAR := []
static var CRACK := []
static var DUST := []
static var STORM := []

var painter: Callable          ## func(pc, t, dt)
var t := 0.0
var dt := 0.0


static func _init_tables() -> void:
	if not STARS.is_empty():
		return
	var r := RandomNumberGenerator.new()
	r.seed = 42
	for i in 60:
		STARS.append({"x": r.randi() % W, "y": r.randi() % 90, "p": r.randf() * 6})
	for i in 90:
		STARS2.append({"x": r.randi() % W, "y": r.randi() % H, "p": r.randf() * 6})
	for x in W:
		MTN_FAR.append(int(108 + 8 * sin(x * .035) + 5 * sin(x * .11 + 1) + 3 * sin(x * .27)))
		MTN_NEAR.append(int(126 + 6 * sin(x * .05 + 2) + 4 * sin(x * .19) + 2 * sin(x * .5)))
	var y := 34
	for x in range(0, W + 1, 8):
		CRACK.append(Vector2i(x, y))
		y = clampi(y + r.randi() % 9 - 4, 22, 48)
	for i in 28:
		DUST.append({"x": r.randf() * W, "y": 100 + r.randf() * 80, "v": 4 + r.randf() * 8})
	for i in 70:
		STORM.append({"x": r.randf() * W, "y": r.randf() * H, "v": 30 + r.randf() * 50})


func _ready() -> void:
	_init_tables()
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	t += delta
	dt = delta
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(4, 4))
	if painter.is_valid():
		painter.call(self, t, dt)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- helpers (same names as the demo)

static func col(c) -> Color:
	return P[c] if c is String and P.has(c) else (Color(c) if c is String else c)


func R(x: float, y: float, w: float, h: float, c) -> void:
	draw_rect(Rect2(floorf(x), floorf(y), floorf(w), floorf(h)), col(c))


func px(x: float, y: float, c) -> void:
	draw_rect(Rect2(floorf(x), floorf(y), 1, 1), col(c))


func disc(cx: float, cy: float, r: float, c) -> void:
	var cc := col(c)
	var ri := int(r)
	for y in range(-ri, ri + 1):
		var w := int(floor(sqrt(r * r - y * y + r * 0.8)))
		draw_rect(Rect2(floorf(cx - w), floorf(cy + y), w * 2 + 1, 1), cc)


func ring(cx: float, cy: float, r: float, c, n := 64, step := 1) -> void:
	var cc := col(c)
	for a in range(0, n, step):
		var tt := a / float(n) * TAU
		draw_rect(Rect2(round(cx + cos(tt) * r), round(cy + sin(tt) * r), 1, 1), cc)


func line(x0: float, y0: float, x1: float, y1: float, c) -> void:
	var cc := col(c)
	var a := Vector2i(int(x0), int(y0))
	var b := Vector2i(int(x1), int(y1))
	var dx := absi(b.x - a.x)
	var sx := 1 if a.x < b.x else -1
	var dy := -absi(b.y - a.y)
	var sy := 1 if a.y < b.y else -1
	var e := dx + dy
	for i in 2000:
		draw_rect(Rect2(a.x, a.y, 1, 1), cc)
		if a == b:
			break
		var e2 := 2 * e
		if e2 >= dy:
			e += dy
			a.x += sx
		if e2 <= dx:
			e += dx
			a.y += sy


static func hash2(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return (h & 1023) / 1023.0


func text(s: String, x: float, y: float, c, size := 8, center := true, font_kind := "title") -> void:
	var f: Font = DawnTheme.title_font() if font_kind == "title" else DawnTheme.body_font()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var fs := size * 4 / 2
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(x * 4 - (w / 2.0 if center else 0.0), y * 4)
	draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color.BLACK)
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col(c))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(4, 4))


# ---------------------------------------------------------------- backgrounds (ported from c1.js)

func dusk_sky(_t: float, y_off := 0.0, h := 140.0) -> void:
	var bh := h / SKY.size()
	for i in SKY.size():
		var y0 := floorf(i * bh + y_off)
		R(0, y0, W, ceilf(bh) + 1, SKY[i])
		if i < SKY.size() - 1:
			var yd := int(floor((i + 1) * bh + y_off)) - 2
			for x in range(0, W, 2):
				px(x + (yd & 1), yd, SKY[i + 1])
			for x in range(1, W, 4):
				px(x, yd - 1, SKY[i + 1])


func stars(tt: float, limit_y := 90.0, y_off := 0.0) -> void:
	for s in STARS:
		if s["y"] + y_off > limit_y:
			continue
		var v := sin(tt * 2 + s["p"])
		if v > .3:
			px(s["x"], s["y"] + y_off, "white" if v > .85 else "grey")


func stars2(tt: float) -> void:
	for s in STARS2:
		var v := sin(tt * 2 + s["p"])
		if v > .25:
			px(s["x"], s["y"], "white" if v > .8 else "grey")


func crack(tt: float, y_off := 0.0) -> void:
	var c := "cyan" if sin(tt * 6) > 0 else "rose"
	for i in CRACK.size() - 1:
		if (i + int(tt * 4)) % 5 == 0:
			continue
		line(CRACK[i].x, CRACK[i].y + y_off, CRACK[i + 1].x, CRACK[i + 1].y + y_off, c)


func landscape(tt: float, y_off := 0.0, open := false) -> void:
	disc(232, 124 + y_off, 16, "amber")
	disc(232, 124 + y_off, 11, "yellow")
	for x in W:
		R(x, MTN_FAR[x] + y_off, 1, H, "plum")
	for x in W:
		R(x, MTN_NEAR[x] + y_off, 1, H, "navy")
	R(0, 140 + y_off, W, H, "dbrown")
	for x in range(0, W, 3):
		px(x, 140 + y_off + ((x * 7) % 5), "brown")
	var tx := 262
	var by := 140 + y_off
	R(tx, by - 46, 6, 46, "ink")
	var y := by - 44
	while y < by:
		line(tx, y, tx + 5, y + 3, "slate")
		y += 4
	R(tx + 9, by - 34, 5, 4, "red")
	R(tx + 8, by - 30, 7, 26, "light")
	R(tx + 9, by - 24, 5, 1, "red")
	R(tx + 6, by - 6, 3, 6, "orange")
	R(tx + 14, by - 6, 3, 6, "orange")
	R(tx + 8, by - 4, 7, 4, "steel")
	R(32, by - 4, 26, 5, "slate")
	if open:
		R(34, by - 14, 22, 2, "steel")
		R(36, by - 3, 18, 3, "ink")
		R(37, by - 3, 16, 1, "amber")
	else:
		R(34, by - 6, 22, 2, "steel")
		var blink := "amber" if int(tt * 2) % 2 == 1 else "clay"
		px(44, by - 7, blink)
		px(45, by - 7, blink)


func dust(_tt: float, d: float) -> void:
	for p in DUST:
		p["x"] += p["v"] * d
		if p["x"] > W:
			p["x"] = -2
		px(p["x"], p["y"], "peach" if int(p["x"]) % 3 != 0 else "sand")


func bunker_bg(tt: float, screen := "earth") -> void:
	R(0, 0, W, H, "teal")
	for x in range(0, W, 32):
		R(x, 0, 1, 130, "ink")
		R(x + 1, 0, 1, 130, "forest")
	R(0, 0, W, 8, "ink")
	for x in range(4, W, 16):
		R(x, 8, 8, 2, "slate")
	R(98, 16, 124, 74, "ink")
	R(101, 19, 118, 68, "navy")
	if screen == "earth":
		disc(160, 53, 22, "blue")
		R(146, 40, 10, 7, "dgreen")
		R(161, 50, 12, 9, "dgreen")
		R(152, 61, 6, 5, "dgreen")
		R(148, 38, 8, 1, "white")
		var k := int(tt * 3) % 2
		ring(160, 53, 27, "red" if k else "magenta")
		ring(160, 53, 28, "dred" if k else "red")
	elif screen == "poll":
		rocket_icon(136, 33)
	for y in range(19, 87, 2):
		R(101, y, 118, 1, Color(0, 0, 0, .18))
	R(0, 112, W, 18, "slate")
	R(0, 110, W, 3, "steel")
	for i in 40:
		var x := 6 + i * 8
		var on := hash2(i, int(tt * 2)) > .45
		px(x, 117, ["green", "amber", "red", "cyan"][i % 4] if on else "navy")
		px(x + 2, 121, "cyan" if hash2(i + 3, int(tt * 1.5)) > .6 else "navy")
	R(0, 130, W, 50, "navy")
	for x in range(0, W, 20):
		R(x, 130, 1, 50, "slate")
	for y in range(140, H, 12):
		R(0, y, W, 1, "slate")


func workshop_bg(_tt: float) -> void:
	R(0, 0, W, H, "slate")
	for y in range(8, 140, 6):
		for x in range(6, W, 6):
			px(x + ((y / 6) & 1) * 3, y, "navy")
	R(26, 40, 3, 18, "steel")
	R(22, 38, 11, 4, "steel")
	R(48, 42, 14, 3, "brown")
	R(53, 45, 4, 10, "grey")
	R(268, 40, 2, 20, "grey")
	R(264, 38, 10, 3, "grey")
	R(286, 44, 3, 14, "red")
	R(106, 16, 108, 124, "ink")
	R(108, 18, 104, 120, "blue")
	for x in range(112, 212, 8):
		R(x, 18, 1, 120, Color("#1a5c96"))
	for y in range(22, 138, 8):
		R(108, y, 104, 1, Color("#1a5c96"))
	R(0, 140, W, 40, "brown")
	R(0, 140, W, 3, "clay")
	for x in range(0, W, 40):
		R(x, 143, 1, 37, "dbrown")


func rocket_icon(ox: float, oy: float, locked := false) -> void:
	for i in 30:
		px(ox + int(hash2(i, 7) * 48), oy + int(hash2(i, 9) * 40), "navy" if locked else ("steel" if i % 3 else "white"))
	var c = "slate" if locked else null
	var r := func(x, y, w, h, cc): R(ox + x, oy + y, w, h, c if c else cc)
	r.call(22, 6, 4, 2, "red"); r.call(21, 8, 6, 3, "red"); r.call(20, 11, 8, 14, "light"); r.call(21, 13, 6, 1, "red")
	r.call(23, 15, 2, 2, "cyan"); r.call(20, 25, 8, 6, "steel"); r.call(17, 27, 3, 5, "orange"); r.call(28, 27, 3, 5, "orange")
	if not locked:
		r.call(22, 31, 4, 2, "orange")
		r.call(23, 33, 2, 3, "yellow")


## The demo's 32x32 planet sprites, drawn at (x, y) with an integer scale.
func planet(kind: String, x: float, y: float, sz := 32.0) -> void:
	var s := sz / 32.0
	var r := func(a, b, w, h, c): R(x + a * s, y + b * s, ceilf(w * s), ceilf(h * s), c)
	var d := func(cx, cy, rad, c): disc(x + cx * s, y + cy * s, rad * s, c)
	if kind == "earth":
		d.call(16, 16, 12, "blue")
		r.call(9, 9, 6, 5, "dgreen"); r.call(17, 15, 7, 6, "dgreen"); r.call(12, 19, 4, 4, "dgreen"); r.call(10, 7, 5, 1, "white")
		for a in range(0, 48, 2):
			var tt := a / 48.0 * TAU
			R(x + (16 + cos(tt) * 14) * s, y + (16 + sin(tt) * 14) * s, maxf(1, s), maxf(1, s), "rose")
	elif kind == "moon":
		d.call(16, 16, 11, "grey")
		r.call(11, 10, 3, 3, "steel"); r.call(18, 17, 4, 3, "steel"); r.call(13, 20, 2, 2, "steel"); r.call(14, 24, 4, 2, "ink")
	elif kind == "mars":
		d.call(16, 16, 11, "rust")
		r.call(10, 11, 8, 3, "burnt"); r.call(14, 19, 9, 2, "burnt"); r.call(13, 5, 6, 2, "white")


func ceres(cx: float, cy: float, r: float, tt: float) -> void:
	disc(cx, cy, r + 1, "ink")
	disc(cx, cy, r, "grey")
	disc(cx - 1, cy - 1, r - 2, "light")
	var blink := int(tt * 1.3) % 5 == 0 and fmod(tt * 1.3, 1.0) < .25
	R(cx - ceilf(r * .6), cy - 1, ceilf(r * 1.2), 3, "ink")
	R(cx - ceilf(r * .45), cy, ceilf(r * .9), 1, "slate" if blink else "cyan")
	R(cx, cy - r - 3, 1, 2, "steel")
	R(cx - 1, cy - r - 4, 3, 1, "cyan" if int(tt * 3) % 2 else "sky")


## drawRocket from the demo: (cx, base) = bottom centre of the motor.
func rocket(cx: float, base: float, d: Dictionary, tt: float, flame := false) -> void:
	var big: bool = d.get("motor", "small") == "big"
	var mh := 26 if big else 16
	var motor_top := base - mh
	R(cx - 6, motor_top, 12, mh, "ink")
	R(cx - 5, motor_top + 1, 10, mh - 2, "slate" if big else "steel")
	R(cx - 5, motor_top + 1, 10, 1, "light")
	if big:
		R(cx - 5, motor_top + 8, 10, 1, "red")
	R(cx - 4, base, 8, 3, "ink")
	for i in 8:
		R(cx - 7 - i / 2.0, base - 8 + i, 2, 1, "orange")
		R(cx + 6 + i / 2.0, base - 8 + i, 2, 1, "orange")
	var body_top := motor_top - 26
	R(cx - 6, body_top, 12, 26, "ink")
	R(cx - 5, body_top, 10, 26, "light")
	R(cx - 5, body_top + 20, 10, 2, "red")
	if d.get("uv", false):
		R(cx - 3, body_top + 5, 6, 5, "ink")
		R(cx - 2, body_top + 6, 4, 3, "plum")
		px(cx, body_top + 7, "cyan")
	if d.get("cam", false):
		R(cx - 3, body_top + 12, 6, 5, "ink")
		R(cx - 2, body_top + 13, 4, 3, "steel")
		px(cx, body_top + 14, "sky")
	for i in 12:
		R(cx - floorf(i / 2.0), body_top - 12 + i, floorf(i / 2.0) * 2 + 1, 1, "ink" if i < 2 else "red")
	if d.get("chute", false):
		R(cx + 6, body_top + 1, 4, 6, "ink")
		R(cx + 7, body_top + 2, 2, 4, "red")
		px(cx + 7, body_top + 3, "white")
	if d.get("radio", false):
		R(cx, body_top - 18, 1, 6, "ink")
		px(cx, body_top - 19, "cyan" if int(tt * 3) % 2 else "sky")
	if flame:
		var k := int(tt * 14) % 2
		R(cx - 3, base + 3, 6, 4, "orange")
		R(cx - 2, base + 7, 4, 6 if k else 4, "yellow")
		px(cx, base + 12 + k, "white")


## A crew member from the sprite sheets, (x, y) = top-left, s = scale.
## robot = the Mars robot body (Acts 4-5); it is drawn at its own frame size, feet at y + 20 * s.
func person(role: String, x: float, y: float, dir := "down", frame := 0, s := 1.0, suit := false, robot := false) -> void:
	var anim := ("walk_" if frame > 0 else "idle_") + ("side" if dir == "left" or dir == "right" else dir)
	var f: SpriteFrames = RoleSprites.frames(role, suit, robot)
	var tex := f.get_frame_texture(anim, (frame % 4) if frame > 0 else 0)
	var fs := Vector2(RoleSprites.frame_size(robot)) * s
	var at := Vector2(floorf(x + 7 * s - fs.x / 2.0), floorf(y + 20 * s - fs.y))
	if dir == "left":
		draw_texture_rect(tex, Rect2(at.x + fs.x, at.y, -fs.x, fs.y), false)
	else:
		draw_texture_rect(tex, Rect2(at, fs), false)


func person_color(body: Color, x: float, y: float, dir := "left", frame := 0) -> void:
	# a civilian in a coloured shirt (intro crowd)
	var f: SpriteFrames = RoleSprites.frames("civ")
	var tex := f.get_frame_texture("walk_side", frame % 4)
	draw_texture_rect(tex, Rect2(floorf(x) + (14 if dir == "left" else 0), floorf(y), -14 if dir == "left" else 14, 20), false, body.lerp(Color.WHITE, 0.5))


# ---------------------------------------------------------------- periscope and bunker-network views (Wake-Up)

func peri(tt: float) -> void:
	R(0, 0, W, H, Color("#04020a"))
	var cx := 160.0
	var cy := 80.0
	var r := 56.0
	var pulse := sin(tt * 2) * 0.07
	var bands := [[Color("#2a1052"), 24, 42], [Color("#4b1f7e"), 42, 56], [Color("#7a2f9a"), 56, 70], [Color("#b0458f"), 70, 80], [Color("#e08a3c"), 80, 92]]
	var clip := func(y0: float, y1: float, c: Color):
		for y in range(int(y0), int(y1)):
			var dy := y - cy
			if absf(dy) >= r:
				continue
			var hw := sqrt(r * r - dy * dy)
			R(cx - hw, y, hw * 2, 1, c)
	for b in bands:
		clip.call(b[1], b[2], b[0])
	disc(196, 76, 10, Color(0.965, 0.843, 0.541, 0.3))
	disc(196, 76, 6, Color("#f6d78a"))
	for b in [[114, 38, 26], [172, 32, 28], [128, 52, 20], [178, 50, 18]]:
		R(b[0], b[1], b[2], 2, Color(0.64, 0.36, 0.82, .55))
	clip.call(92, 140, Color("#1a0f2e"))
	for b in [[118, 80, 7, 12], [127, 73, 6, 19], [135, 82, 9, 10], [148, 76, 5, 16], [168, 77, 6, 15], [176, 83, 8, 9], [189, 74, 6, 18]]:
		R(b[0], b[1], b[2], b[3], Color("#1a0f2e"))
	draw_colored_polygon(PackedVector2Array([Vector2(155, 92), Vector2(165, 92), Vector2(190, 136), Vector2(130, 136)]), Color("#2b1a3d"))
	R(159, 97, 2, 2, Color("#8c5a78"))
	R(159, 105, 2, 3, Color("#8c5a78"))
	R(159, 115, 2, 4, Color("#8c5a78"))
	clip.call(cy - r, cy + r, Color(0.7, 0.42, 1.0, 0.12 + pulse))
	draw_arc(Vector2(cx, cy), r + 1.5, 0, TAU, 96, Color("#3a4552"), 3.0)
	draw_arc(Vector2(cx, cy), r + 4.5, 0, TAU, 96, Color("#1b1e27"), 3.0)
	var g := Color(0, 1, 0.25, .8)
	R(cx, cy - r + 2, 1, 7, g)
	R(cx, cy + r - 9, 1, 7, g)
	R(cx - r + 2, cy, 7, 1, g)
	R(cx + r - 9, cy, 7, 1, g)


const LAND := [[[66, 32], [82, 28], [94, 32], [98, 40], [90, 48], [84, 54], [76, 52], [70, 46], [66, 40]], [[84, 58], [92, 58], [96, 66], [92, 78], [88, 84], [84, 74], [82, 64]],
	[[112, 30], [124, 28], [128, 36], [118, 40], [112, 38]], [[114, 44], [126, 44], [132, 54], [128, 68], [120, 72], [116, 60], [112, 50]],
	[[130, 28], [154, 26], [176, 32], [180, 42], [168, 50], [154, 52], [144, 46], [132, 40]], [[162, 64], [176, 64], [178, 72], [166, 74]]]


static func mapx(x: float) -> float:
	return 64 + (x - 56) * 4 / 3.0


static func mapy(y: float) -> float:
	return 24 + (y - 18) * 4 / 3.0


func net(tt: float, linked: bool) -> void:
	R(0, 0, W, H, Color("#04060c"))
	R(62, 22, 196, 100, Color("#3a4552"))
	R(64, 24, 192, 96, Color("#0f1830"))
	for y in [34, 50, 66, 82]:
		R(64, mapy(y), 192, 1, Color("#17254a"))
	for x in [80, 104, 128, 152, 176]:
		R(mapx(x), 24, 1, 96, Color("#17254a"))
	for pts in LAND:
		var poly := PackedVector2Array()
		for p in pts:
			poly.append(Vector2(mapx(p[0]), mapy(p[1])))
		draw_colored_polygon(poly, Color("#2f6b4a"))
	var B := [[70, 36], [86, 38], [88, 64], [120, 52], [124, 62], [146, 36], [160, 40], [170, 46], [168, 68]]
	var bx := mapx(118)
	var by := mapy(34)
	for p in B:
		if linked:
			draw_line(Vector2(bx, by), Vector2(mapx(p[0]), mapy(p[1])), Color(0, 1, .25, .45), 1.0)
		R(mapx(p[0]) - 2, mapy(p[1]) - 2, 4, 4, Color("#00ff41") if linked else Color("#9aa3b3"))
	var on := int(tt * 2) % 2 == 0
	draw_rect(Rect2(bx - 6.5, by - 6.5, 13, 13), Color(0, 1, .25, .7 if on else .2), false, 1.0)
	R(bx - 2, by - 2, 5, 5, Color("#00ff41"))
