extends Control
## Base for the new minigames (from docs/minigames mockup: dawn_minigames_pixel.html). Owner: Sufi.
## A minigame is a 640x360 drawing area inside the task popup (minigames.gd play()).
## Each game file extends this and fills in: setup(), tick(dt), paint(), and the input hooks.
##
##   coordinates  640x360 like the HTML ("hi" games). Set lo = true for the 320x180 HTML games:
##                every helper then doubles the numbers for you.
##   finish(stars, why, nasa)  stars 1-3 = task complete, 0 = failed (TRY AGAIN appears).
##   say(text, kind)           message line under the game. kind "ok" green, "bad" red.
##   add_button / add_hold_button   buttons in the popup's bottom row.
##   pic(key, x, y, w, h)      instrument photo from assets/minigames/<key>.png or .jpg.
##                             Until the photo is uploaded it draws a "PHOTO COMING SOON" card.

const WD := preload("res://game/dawn/world_data.gd")
const PIC_DIR := "res://assets/minigames/"
const W := 640.0
const H := 360.0
## The HTML colour names (P.w, P.y ...) in the game palette (Endesga 32).
const P := {"k": Color("#181425"), "nv": Color("#262b44"), "sl": Color("#3a4466"), "st": Color("#5a6988"),
	"pu": Color("#68386c"), "dg": Color("#3e8948"), "br": Color("#b86f50"), "gy": Color("#8b9bb4"),
	"lg": Color("#c0cbdc"), "w": Color("#ffffff"), "r": Color("#e43b44"), "o": Color("#feae34"),
	"or": Color("#f77622"), "y": Color("#fee761"), "g": Color("#63c74d"), "b": Color("#2ce8f5"),
	"bl": Color("#0099db"), "pk": Color("#f6757a"), "pe": Color("#e4a672"), "sand": Color("#ead4aa"),
	"plum": Color("#b55088")}

var lo := false                 ## true = the game uses 320x180 numbers (drawn 2x)
var title := ""                 ## filled in by the game
var goal := ""                  ## HOW TO PLAY text, shown before the game starts
var host                        ## minigames.gd Game (msg line, foot row, win)
var on_win: Callable            ## what a win does (records the task)

var started := false            ## false while the HOW TO PLAY card is up
var over := false
var mouse := Vector2(-999, -999)  ## pointer in game numbers
var mouse_down := false
var t := 0.0                    ## seconds since start
var _result := {}               ## {stars, why, nasa} once finished
var _buttons: Array[Control] = []        ## buttons and sliders this game put in the bottom row
var _font: Font
var _title_font: Font
var _pics := {}

static var STARS: Array = []
static var _crisp_body: FontFile
static var _crisp_title: FontFile


## Sharp pixel text: the game fonts with smoothing off. Pixelify Sans only lands on whole pixels at
## some sizes, so every text size is snapped to the nearest clean one (10, 13, 16, 20, 26, 32 px);
## Press Start 2P is clean at multiples of 8.
const BODY_SIZES := [10, 13, 16, 20, 26, 32]


static func crisp_font(title_font := false) -> FontFile:
	if _crisp_body == null:
		_crisp_body = (DawnTheme.body_font() as FontFile).duplicate()
		_crisp_title = (DawnTheme.title_font() as FontFile).duplicate()
		for f in [_crisp_body, _crisp_title]:
			f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			f.hinting = TextServer.HINTING_NONE
	return _crisp_title if title_font else _crisp_body


static func clean_size(px: float, title_font := false) -> int:
	if title_font:
		return maxi(8, roundi(px / 8.0) * 8)
	for sz in BODY_SIZES:              # the smallest clean size that is not (much) smaller
		if sz >= px - 0.6:
			return sz
	return BODY_SIZES[-1]


# ---------------------------------------------------------------- what each game fills in

func setup() -> void:
	pass

func tick(_dt: float) -> void:
	pass

func paint() -> void:
	pass

func press(_p: Vector2) -> void:
	pass

func drag(_p: Vector2) -> void:
	pass

func release(_p: Vector2) -> void:
	pass

## k is a Key constant (KEY_SPACE, KEY_LEFT ...). Return true if the game used the key.
func key(_k: int, _down: bool) -> bool:
	return false


# ---------------------------------------------------------------- life cycle

func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # photos shrink smoothly
	clip_contents = true                 # nothing is drawn outside the 640x360 game
	_font = crisp_font()
	_title_font = crisp_font(true)
	if STARS.is_empty():
		for i in 110:
			STARS.append([float((i * 97 + 13) % 640), float((i * 53 + i * i * 7) % 360), 1.2 if i % 7 == 0 else 0.7, 0.35 + float((i * 37) % 10) / 16.0])
	restart()


## (Re)starts the game: clears buttons, runs setup(), shows the HOW TO PLAY card.
func restart() -> void:
	for b in _buttons:
		if is_instance_valid(b):
			b.queue_free()
	_buttons.clear()
	over = false
	started = false
	_result = {}
	t = 0.0
	say("")
	setup()
	_set_buttons_enabled(false)


func _start() -> void:
	started = true
	_set_buttons_enabled(true)


func _set_buttons_enabled(on: bool) -> void:
	for b in _buttons:
		if is_instance_valid(b) and b is BaseButton:
			b.disabled = not on
		elif is_instance_valid(b) and b is Range:
			b.editable = on


func _process(delta: float) -> void:
	if started and not over:
		t += delta
		tick(minf(delta, 0.05))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), P["k"])
	paint()
	if not started:
		_intro_card()
	elif not _result.is_empty():
		_result_card()
	# pixel frame
	draw_rect(Rect2(0, 0, W, H), P["sl"], false, 4.0)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mouse = _to_game(e.position)
		if started and not over:
			drag(mouse)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		mouse = _to_game(e.position)
		mouse_down = e.pressed
		if e.pressed and not started:
			_start()
		elif started and not over:
			if e.pressed:
				press(mouse)
			else:
				release(mouse)
		accept_event()


## Keys go to the game before the popup's buttons (so SPACE never "clicks" a focused button).
func _input(e: InputEvent) -> void:
	if not is_visible_in_tree() or not (e is InputEventKey) or e.echo:
		return
	var k: int = e.physical_keycode
	if not started:
		if e.pressed and k in [KEY_SPACE, KEY_ENTER]:
			_start()
			get_viewport().set_input_as_handled()
		return
	if over:
		return
	if key(k, e.pressed):
		get_viewport().set_input_as_handled()


func _to_game(p: Vector2) -> Vector2:
	return p / 2.0 if lo else p


# ---------------------------------------------------------------- ending

## stars 1-3 = complete (win), 0 = failed. why = what happened, nasa = the real-world fact.
func finish(stars: int, why: String, nasa := "") -> void:
	if over:
		return
	over = true
	_result = {"stars": stars, "why": why, "nasa": nasa}
	for b in _buttons:
		if is_instance_valid(b):
			b.queue_free()
	_buttons.clear()
	if stars > 0:
		if host:
			host.win(on_win)            # the NASA fact is already on the result card
		else:
			say("TASK COMPLETE", "ok")
	else:
		if host:
			host.fail("Task failed. Read why, then try again.")
		var b := add_button("TRY AGAIN", func(_b): restart())
		b.disabled = false


func _intro_card() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(P["k"], 0.88))
	var x := 60.0
	_text_px("HOW TO PLAY", Vector2(x, 54), P["y"], 22, 0, _title_font)
	var y := _wrap_px(goal, Vector2(x, 96), 520.0, 26.0, P["w"], 20)
	var blink := int(Time.get_ticks_msec() / 450) % 2 == 0
	_text_px("CLICK HERE OR PRESS SPACE TO START", Vector2(W / 2, maxf(y + 24, 300)), P["o"] if blink else P["y"], 12, 1, _title_font)


func _result_card() -> void:
	var st: int = _result["stars"]
	draw_rect(Rect2(0, 0, W, H), Color(P["k"], 0.9))
	var head := "TASK COMPLETE" if st > 0 else "TASK FAILED"
	_text_px(head, Vector2(W / 2, 34), P["g"] if st > 0 else P["r"], 22, 1, _title_font)
	if st > 0:
		for i in 3:
			_star(Vector2(W / 2 - 50 + i * 50, 92), 18.0, P["y"] if i < st else P["sl"])
	var y := _wrap_px("WHY: " + String(_result["why"]), Vector2(56, 126 if st > 0 else 84), 528.0, 24.0, P["w"], 18)
	if String(_result["nasa"]) != "":
		_wrap_px("NASA DATA: " + String(_result["nasa"]), Vector2(56, y + 10), 528.0, 22.0, P["b"], 16)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)


# ---------------------------------------------------------------- popup helpers

func say(text: String, kind := "") -> void:
	if host == null or host.msg == null:
		return
	var col := "#63c74d" if kind == "ok" else ("#f6757a" if kind == "bad" else "#c0cbdc")
	host.msg.text = "[color=%s]%s[/color]" % [col, text] if text != "" else ""


## Button in the popup's bottom row. fn(button) runs on click.
func add_button(text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): fn.call(b))
	_add_to_foot(b)
	return b


## Button you hold down: fn(true) on press, fn(false) on release.
func add_hold_button(text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.button_down.connect(func(): fn.call(true))
	b.button_up.connect(func(): fn.call(false))
	_add_to_foot(b)
	return b


## Slider in the bottom row: fn(value) runs when it moves.
func add_slider(label: String, mn: float, mx: float, step: float, val: float, fn: Callable) -> HSlider:
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 18)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sl := HSlider.new()
	sl.min_value = mn
	sl.max_value = mx
	sl.step = step
	sl.value = val
	sl.focus_mode = Control.FOCUS_NONE
	sl.custom_minimum_size = Vector2(260, 32)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.value_changed.connect(func(v): fn.call(v))
	_add_to_foot(l)
	_add_to_foot(sl)
	return sl


func _add_to_foot(b: Control) -> void:
	if host and host.foot:
		host.foot.add_child(b)
		host.foot.move_child(b, _buttons.size())
	else:
		add_child(b)
	_buttons.append(b)


# ---------------------------------------------------------------- drawing (game numbers)

## 65.0 -> "65", 0.481 -> "0.481" (numbers as the HTML prints them).
func num(v) -> String:
	var s := str(v)
	return s.substr(0, s.length() - 2) if s.ends_with(".0") else s


func k() -> float:
	return 2.0 if lo else 1.0


func R(x: float, y: float, w: float, h: float, col: Color) -> void:
	var s := k()
	draw_rect(Rect2(x * s, y * s, w * s, h * s), col)


## Square box with an optional pixel border (the HTML rounded boxes, made square).
func RR(x: float, y: float, w: float, h: float, fill, stroke = null, lw := 2.0) -> void:
	var s := k()
	var r := Rect2(x * s, y * s, w * s, h * s)
	if fill != null:
		draw_rect(r, fill)
	if stroke != null:
		draw_rect(r, stroke, false, lw)


func disc(cx: float, cy: float, r: float, col: Color) -> void:
	var s := k()
	draw_circle(Vector2(cx, cy) * s, maxf(0.0, r * s), col)


func ring(cx: float, cy: float, rx: float, col: Color, ry := -1.0, lw := 1.0, dashed := false) -> void:
	var s := k()
	if ry < 0:
		ry = rx
	var n := 48
	for i in n:
		if dashed and i % 2 == 1:
			continue
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		draw_line(Vector2(cx + rx * cos(a0), cy + ry * sin(a0)) * s, Vector2(cx + rx * cos(a1), cy + ry * sin(a1)) * s, col, lw * s)


func line(x0: float, y0: float, x1: float, y1: float, col: Color, lw := 1.0) -> void:
	var s := k()
	draw_line(Vector2(x0, y0) * s, Vector2(x1, y1) * s, col, lw * s)


func dline(x0: float, y0: float, x1: float, y1: float, col: Color, lw := 1.0, dash := 4.0) -> void:
	var s := k()
	draw_dashed_line(Vector2(x0, y0) * s, Vector2(x1, y1) * s, col, lw * s, dash * s)


func poly(pts: Array, col: Color, lw := 1.0) -> void:
	if pts.size() < 2:
		return
	var s := k()
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(Vector2(p[0], p[1]) * s)
	draw_polyline(arr, col, lw * s)


func fill_poly(pts: Array, col: Color) -> void:
	var s := k()
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(Vector2(p[0], p[1]) * s)
	draw_colored_polygon(arr, col)


## Bar that fills f (0..1).
func bar(x: float, y: float, w: float, h: float, f: float, col: Color, bg := Color("#3a4466")) -> void:
	R(x, y, w, h, bg)
	if f > 0:
		R(x, y, w * clampf(f, 0.0, 1.0), h, col)


## Text. size is in the same units as the HTML T() sizes. al: 0 left, 1 center, 2 right.
func T(s: String, x: float, y: float, col := Color.WHITE, al := 0, size := -1.0) -> void:
	if size < 0:
		size = 13.0 if not lo else 7.0
	_text_px(s, Vector2(x, y) * k(), col, int(round(size * k() * 0.92)), al)


func TW(s: String, size := -1.0) -> float:
	if size < 0:
		size = 13.0 if not lo else 7.0
	return _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, clean_size(size * k() * 0.92)).x / k()


## Word-wrapped text; returns the y under the last line.
func wrap_text(s: String, x: float, y: float, maxw: float, lh: float, col: Color, size := -1.0) -> float:
	if size < 0:
		size = 13.0 if not lo else 7.0
	var sc := k()
	return _wrap_px(s, Vector2(x, y) * sc, maxw * sc, lh * sc, col, int(round(size * sc * 0.92))) / sc


func _text_px(s: String, p: Vector2, col: Color, px: int, al := 0, font: Font = null) -> void:
	var f := font if font else _font
	px = clean_size(px, f == _title_font)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var x := p.x - (w / 2.0 if al == 1 else (w if al == 2 else 0.0))
	draw_string(f, Vector2(roundf(x), roundf(p.y + f.get_ascent(px))), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _wrap_px(s: String, p: Vector2, maxw: float, lh: float, col: Color, px: int) -> float:
	px = clean_size(px)
	var y := p.y
	var cur := ""
	for word in s.split(" "):
		var test := word if cur == "" else cur + " " + word
		if _font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > maxw and cur != "":
			_text_px(cur, Vector2(p.x, y), col, px)
			y += lh
			cur = word
		else:
			cur = test
	if cur != "":
		_text_px(cur, Vector2(p.x, y), col, px)
		y += lh
	return y


# ---------------------------------------------------------------- scenery

func sky(col := Color("#0b0913")) -> void:
	draw_rect(Rect2(0, 0, W, H), col)
	for st in STARS:
		var a: float = st[3]
		var sz: float = 2.0 if st[2] > 1.0 else 1.0
		draw_rect(Rect2(floorf(st[0]), floorf(st[1]), sz, sz), Color(1, 1, 1, a))


## Flat pixel Earth: ocean, two land bands, ice caps, night side.
func earth(cx: float, cy: float, r: float, tt := 0.0) -> void:
	disc(cx, cy, r, Color("#124e89"))
	disc(cx - r * 0.12, cy - r * 0.12, r * 0.86, Color("#0099db"))
	for i in 4:
		var x := fposmod(i * 29.0 + tt * 10.0, r * 3.0) - r * 1.5
		var y := cy - r * 0.45 + (i % 3) * r * 0.4
		var hw := r * 0.38
		if absf(x) + hw < r * 0.95:
			R(cx + x - hw, y - r * 0.1, hw * 2, r * 0.22, Color("#63c74d"))
	R(cx - r * 0.5, cy - r * 0.98, r, r * 0.16, P["w"])
	R(cx - r * 0.5, cy + r * 0.82, r, r * 0.16, P["w"])
	_shade_right(cx, cy, r, Color(0.04, 0.03, 0.1, 0.45))


func moon(cx: float, cy: float, r: float) -> void:
	disc(cx, cy, r, Color("#8b9bb4"))
	disc(cx - r * 0.1, cy - r * 0.1, r * 0.88, Color("#c0cbdc"))
	for c in [[-0.3, -0.2, 0.22], [0.35, 0.1, 0.16], [-0.1, 0.45, 0.13], [0.1, -0.5, 0.1], [-0.55, 0.25, 0.09]]:
		disc(cx + c[0] * r, cy + c[1] * r, c[2] * r, Color("#8b9bb4"))
	_shade_right(cx, cy, r, Color(0.04, 0.03, 0.1, 0.35))


## Night side: a crescent of darker pixels on the lower right.
func _shade_right(cx: float, cy: float, r: float, col: Color) -> void:
	var s := k()
	var step := maxf(1.0, roundf(r * s / 14.0))
	var y := -r * s
	while y < r * s:
		var half := sqrt(maxf(0.0, r * s * r * s - y * y))
		var cut := half * 0.35 - y * 0.3
		if cut < half:
			draw_rect(Rect2(cx * s + cut, cy * s + y, half - cut, step), col)
		y += step


# ---------------------------------------------------------------- pictures

## Instrument photo, or a COMING SOON card until assets/minigames/<key>.png/.jpg is in the project.
func pic(key_: String, x: float, y: float, w: float, h: float, label := "") -> bool:
	var tex := _pic(key_)
	var s := k()
	var r := Rect2(x * s, y * s, w * s, h * s)
	if tex:
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		var sc := maxf(r.size.x / tw, r.size.y / th)
		var src := Rect2((tw - r.size.x / sc) / 2.0, (th - r.size.y / sc) / 2.0, r.size.x / sc, r.size.y / sc)
		draw_texture_rect_region(tex, r, src)
		draw_rect(r, P["lg"], false, 2.0)
		return true
	draw_rect(r, Color("#3a4466"))
	draw_rect(Rect2(r.position.x, r.position.y + r.size.y / 2, r.size.x, r.size.y / 2), Color("#262b44"))
	draw_rect(r, P["st"], false, 2.0)
	if minf(w, h) * s >= 40:
		var name := label if label != "" else key_.to_upper()
		var px := clean_size(clampf(r.size.x / 7.0, 9, 15))
		if _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > r.size.x - 4:
			name = name.split(" ")[0]          # "LROC NAC" -> "LROC" in a small slot
		_text_px(name, r.get_center() - Vector2(0, minf(14.0, r.size.y * 0.25)), P["lg"], px, 1)
		if r.size.y >= 56 and r.size.x >= 90:
			_text_px("PHOTO COMING SOON", r.get_center() + Vector2(0, r.size.y * 0.14), P["gy"], 10, 1)
	return false


func _pic(key_: String) -> Texture2D:
	if _pics.has(key_):
		return _pics[key_]
	var tex: Texture2D = null
	for ext in ["png", "jpg", "jpeg", "webp"]:
		var path: String = PIC_DIR + key_ + "." + ext
		if ResourceLoader.exists(path):
			# copy with mipmaps, so a 256 px photo stays clean when drawn at 40 px
			var img: Image = (load(path) as Texture2D).get_image()
			if img.is_compressed():
				img.decompress()
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
			break
	_pics[key_] = tex
	return tex
