extends CanvasLayer
## The overview map of the current world (rooms + corridors), drawn exactly like the HTML demo.
## Owner: Sufi (gameplay) / Zaliq (art). Lives as a child of dawn.gd ("WorldMap").
##
## Two uses:
##   toggle()                     M key: show / hide the whole map (rooms, who is where, objective).
##   travel(from, to, done)       walking through a door: the map shows your crew member walking
##                                down the corridor to the next room, then done() puts them inside.
##
## Where the picture comes from:
##   assets/map/<world>_under.png   floor, surface and corridors   (exported from the HTML by
##   assets/map/<world>_over.png    furniture drawn over the rooms  tools/export_world_maps.js)
##   data/map.json                  room shapes, tones, labels (same numbers as the HTML DEFS)
##   Rooms are painted here at runtime, so locked rooms show as dotted outlines until they open.

const Pixel := preload("res://game/dawn/pixel.gd")
const WD := preload("res://game/dawn/world_data.gd")
const RoleSprites := preload("res://game/player/role_sprites.gd")
const MAP_FILE := "res://data/map.json"
const W := 320
const H := 180
const WALK_SPEED := 80.0           ## map pixels per second during corridor travel (HTML walks ~46)
const MIN_TRAVEL := 0.55           ## seconds; short corridors still read as a walk

var g                              ## dawn.gd
var _map := {}                     ## data/map.json
var _tex := {}                     ## signature -> ImageTexture of the finished map picture
var _view: Control                 ## Pixel canvas (320x180 scaled 4x)
var _labels: Control
var _labels_sig := ""
var _trip := {}                    ## {role, a: Vector2, b: Vector2, t, dur, done}
var showing := false


func _ready() -> void:
	layer = 5
	_map = JSON.parse_string(FileAccess.get_file_as_string(MAP_FILE))
	_view = Pixel.new()
	_view.painter = _paint
	add_child(_view)
	_labels = Control.new()
	_labels.size = Vector2(1280, 720)
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_labels)
	visible = false


func busy() -> bool:
	return not _trip.is_empty()


# ---------------------------------------------------------------- public

func toggle() -> void:
	if busy():
		return
	showing = not showing
	visible = showing
	g.set_frozen(showing)
	if showing:
		_build_labels()


func travel(from_id: String, to_id: String, role: String, done: Callable) -> void:
	var a := _room_center(from_id)
	var b := _room_center(to_id)
	_trip = {"role": role, "a": a, "b": b, "t": 0.0, "dur": maxf(MIN_TRAVEL, a.distance_to(b) / WALK_SPEED), "done": done, "to": to_id}
	visible = true
	_build_labels()


func _process(delta: float) -> void:
	if _trip.is_empty():
		return
	_trip["t"] += delta
	if _trip["t"] >= _trip["dur"]:
		var done: Callable = _trip["done"]
		_trip = {}
		visible = showing
		done.call()


func _unhandled_input(event: InputEvent) -> void:
	if showing and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- data

func _world() -> String:
	return g.S["world"]


func _rooms() -> Array:
	return _map[_world()]["rooms"]


func _room(k: String) -> Dictionary:
	for r in _rooms():
		if r["k"] == k:
			return r
	return {}


func _room_center(id: String) -> Vector2:
	var r := _room(WD.key_of(id))
	return Vector2(r.get("cx", 160), r.get("cy", 90))


func _locked(r: Dictionary) -> bool:
	return g.is_locked(_world() + "." + r["k"])


## Same rules as the HTML inside(): is map pixel (x, y) inside room r?
static func inside(r: Dictionary, x: float, y: float) -> bool:
	var s: Array = r["shape"]
	match s[0]:
		"rect":
			return x >= s[1] and x <= s[3] and y >= s[2] and y <= s[4]
		"ell":
			var dx: float = (x - s[1]) / s[3]
			var dy: float = (y - s[2]) / s[4]
			return dx * dx + dy * dy <= 1.0
		"oct":
			var dx: float = absf(x - s[1])
			var dy: float = absf(y - s[2])
			return dx <= s[3] and dy <= s[3] * 0.82 and dx + dy <= s[3] * 1.35
		"hex":
			var dx: float = absf(x - s[1])
			var dy: float = absf(y - s[2])
			return dy <= s[3] * 0.8 and dx + dy * 0.55 <= s[3]
		"trap":
			if y < s[2] or y > s[4]:
				return false
			var k: float = (y - s[2]) / (s[4] - s[2]) * 7.0
			if s.size() > 5 and s[5]:
				k = 7.0 - k
			return x >= s[1] + k and x <= s[3] - k
		"poly":
			return Geometry2D.is_point_in_polygon(Vector2(x, y), PackedVector2Array(s[1].map(func(p): return Vector2(p[0], p[1]))))
	return false


# ---------------------------------------------------------------- the map picture (cached per lock state)

func _texture() -> ImageTexture:
	var w := _world()
	var sig := w
	for r in _rooms():
		sig += "1" if _locked(r) else "0"
	if _tex.has(sig):
		return _tex[sig]
	var img: Image = load("res://assets/map/%s_under.png" % w).get_image()
	img.convert(Image.FORMAT_RGBA8)
	var tones: Dictionary = _map["tones"]
	for r in _rooms():
		var lk := _locked(r)
		var tone: String = "locked" if lk else (r["utone"] if r["tone"] == "locked" and r["utone"] else r["tone"])
		var T: Dictionary = tones[tone]
		var bb: Dictionary = r["bb"]
		for y in range(int(bb["y0"]), int(bb["y1"]) + 1):
			for x in range(int(bb["x0"]), int(bb["x1"]) + 1):
				if not inside(r, x, y):
					continue
				var edge := not inside(r, x - 1, y) or not inside(r, x + 1, y) or not inside(r, x, y - 1) or not inside(r, x, y + 1)
				if lk:
					if edge and (x + y) % 4 < 2:
						img.set_pixel(x, y, Color(T["b"]))
					continue
				var c: String = T["b"] if edge else (T["f"] if ((x >> 2) + (y >> 2)) & 1 else T["t"])
				img.set_pixel(x, y, Color(c))
	var over: Image = load("res://assets/map/%s_over.png" % w).get_image()
	over.convert(Image.FORMAT_RGBA8)
	img.blend_rect(over, Rect2i(0, 0, W, H), Vector2i.ZERO)
	_tex[sig] = ImageTexture.create_from_image(img)
	return _tex[sig]


# ---------------------------------------------------------------- drawing (every frame while visible)

func _paint(pc, t: float, _dt: float) -> void:
	pc.draw_texture(_texture(), Vector2.ZERO)
	var w := _world()
	if w == "earth":
		pc.ceres(160, 92 + (int(t * 2) % 2), 5, t)
	# objective arrow above its room (blinks)
	var ob: Dictionary = g.objective()
	var ok: String = WD.key_of(ob.get("room", "")) if ob.get("room", "") != "" else ""
	var r := _room(ok)
	if not r.is_empty() and WD.world_of(ob["room"]) == w:
		var bb: Dictionary = r["bb"]
		var y: float = bb["y0"] - 8 + (1 if int(t * 3) % 2 else 0)
		if y < 14:
			y = bb["y1"] + 3
		var c: Color = Pixel.P["red"] if ob.get("alert", false) else Pixel.P["yellow"]
		for i in 4:
			pc.R(r["cx"] - 3 + i, y + i, 7 - i * 2, 1, c)
		pc.R(r["cx"] - 4, y - 1, 9, 1, Pixel.P["ink"])
	# little squares at each room's top-right corner: who is inside (like the HTML)
	var travelling: String = _trip.get("role", "")
	for rr in _rooms():
		var i := 0
		for role in g.ROLES:
			if role == travelling:
				continue
			var p = g.crew.get(role)
			if not is_instance_valid(p) or WD.room_at(p.position) != w + "." + rr["k"]:
				continue
			var bb: Dictionary = rr["bb"]
			pc.R(bb["x1"] - 4 - i * 5, bb["y0"] + 1, 5, 5, Pixel.P["ink"])
			pc.R(bb["x1"] - 3 - i * 5, bb["y0"] + 2, 3, 3, RoleSprites.TAGS[role])
			if role == g.crew_ctl.me_role and int(t * 3) % 2 == 0:
				pc.R(bb["x1"] - 4 - i * 5, bb["y0"] + 7, 5, 1, Pixel.P["yellow"])
			i += 1
	# the crew member walking down the corridor
	if not _trip.is_empty():
		var k: float = clampf(_trip["t"] / _trip["dur"], 0.0, 1.0)
		var at: Vector2 = _trip["a"].lerp(_trip["b"], k)
		var d: Vector2 = _trip["b"] - _trip["a"]
		var dir := ("right" if d.x > 0 else "left") if absf(d.x) > absf(d.y) else ("down" if d.y > 0 else "up")
		pc.person(_trip["role"], at.x - 7, at.y - 18, dir, 1 + int(t * 8) % 4, 1.0, g.S["suits"].get(_trip["role"], false))
	if showing:
		pc.R(0, 172, W, 8, Color(Pixel.P["ink"], 0.85))
		pc.text("MAP · M OR ESC TO CLOSE · YOU = BLINKING", 160, 175, Pixel.P["grey"], 5)


func _build_labels() -> void:
	var sig := _world() + str(_rooms().map(func(r): return _locked(r)))
	if sig == _labels_sig:
		return
	_labels_sig = sig
	for c in _labels.get_children():
		c.queue_free()
	var M: Dictionary = _map[_world()]
	for r in _rooms():
		var lk := _locked(r)
		var bb: Dictionary = r["bb"]
		var y: float = r["cy"] + M["labelY"][r["k"]] if M["labelY"].has(r["k"]) else (bb["y1"] + 5 if bb["y0"] < 34 else bb["y0"] - 5)
		_label(r["name"] + ("\nLOCKED" if lk else ""), Vector2(r["cx"], y), DawnTheme.C["grey"] if lk else DawnTheme.C["white"])
	for l in M["labels"]:
		_label(l[0], Vector2(l[1], l[2]), Color(l[3]))


## HTML .lbl: small title font, centred on (x, y) in map pixels, black outline.
func _label(text: String, at: Vector2, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", DawnTheme.title_font())
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", DawnTheme.C["ink"])
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(320, 64)
	l.position = at * 4.0 - l.size / 2.0
	_labels.add_child(l)
