extends Node2D
## Draws one room screen (320x180), one node per room, placed at the room's grid cell by dawn.gd.
## Owner: Sufi (gameplay).
##
## The still picture (floor, walls, furniture, consoles, posters) is the HTML demo's own drawing,
## exported to assets/rooms/int_<world>_<key>.png by tools/export_world_maps.js.
## This script only adds what changes while you play:
##   doors        amber frame; grey bar when the room behind is locked; the door on the way to the
##                objective blinks yellow with an arrow
##   rings        dashed ring on a spot a co-op "hold" needs (green when someone stands on it),
##                yellow ring on the main console when the objective is here
##   CERES        the bunker AI robot in Mission Control / Lunar Control
##   highlights   soft glow under whatever you can use right now, dot on posters you have not read

const WD := preload("res://game/dawn/world_data.gd")
const Pixel := preload("res://game/dawn/pixel.gd")
const RoleSprites := preload("res://game/player/role_sprites.gd")

## Where CERES stands in each world: the HTML spot (DEFS.<world>.fx), moved 26 px right so the
## robot body does not cover the main console's standing spot.
const CERES_AT := {"earth.mc": Vector2(186, 64), "moon.lc": Vector2(186, 58)}

var id := ""
var game                     ## dawn.gd
var stations: Array = []
var doors: Array = []
var _picture: Texture2D
var _ceres: Pixel


func _ready() -> void:
	z_index = -10
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture = load(WD.interior_path(id))
	if CERES_AT.has(id):
		_ceres = Pixel.new()                  # small canvas so CERES animates like everywhere else
		_ceres.scale = Vector2(0.25, 0.25)    # Pixel draws at 4x for the UI; rooms are 1x world pixels
		_ceres.painter = func(pc, t, _dt): pc.ceres(CERES_AT[id].x, CERES_AT[id].y, 7, t)
		add_child(_ceres)


func _draw() -> void:
	if _picture:
		draw_texture(_picture, Vector2.ZERO)
	var hold: Dictionary = game.current_hold()
	var ob: Dictionary = game.objective()
	var k := int(Time.get_ticks_msec() / 250) % 2
	for s in stations:
		var need := _hold_role(hold, s["id"])
		if need != "":
			_ring(s["pos"], WD.PAL["green"] if game.on_spot(need, id, s["id"]) else RoleSprites.TAGS[need], k)
		elif s["id"] == "main" and ob.get("room", "") == id and not ob.get("hold", false):
			_ring(s["pos"], WD.PAL["yellow"], k)
		if s["id"].begins_with("poster") and not game.found.has(int(s["poster"]["n"])):
			draw_rect(Rect2(s["pos"].x + 5, s["pos"].y - 22, 2, 2), WD.PAL["yellow"] if k == 0 else WD.PAL["white"])
	_doors()
	for p in game.local_crew():
		if WD.room_at(p.position) == id:
			var near: Dictionary = game.station_near(p)
			if not near.is_empty():
				draw_circle(near["pos"], 11.0, Color(WD.PAL["yellow"], 0.18))


func _hold_role(hold: Dictionary, sid: String) -> String:
	for r in hold.get("need", {}):
		if hold["need"][r][0] == id and hold["need"][r][1] == sid:
			return r
	return ""


## Dashed ring around a spot (HTML: 24 dashes, every other one lit, flipping 4 times a second).
func _ring(at: Vector2, c: Color, k: int) -> void:
	for a in 24:
		if (a + k) % 2 == 0:
			var an := a / 24.0 * TAU
			draw_rect(Rect2(roundf(at.x + cos(an) * 13), roundf(at.y - 2 + sin(an) * 6), 2, 1), c)


## Doors exactly like the HTML: amber frame, dark opening (grey bar = locked).
func _doors() -> void:
	var ob: Dictionary = game.objective()
	var hop := ""
	if ob.get("room", "") != "" and ob["room"] != id:
		hop = WD.next_hop(id, ob["room"], game.locked_map())
	var blink := int(Time.get_ticks_msec() / 300) % 2 == 0
	var P := WD.PAL
	for d in doors:
		var locked: bool = game.is_locked(d["to"])
		var u: Vector2 = d["dir"]
		var at: Vector2 = d["pos"] - u          # HTML puts the door on the last floor pixel
		var vert := absf(u.x) > absf(u.y)
		var w := 7.0 if vert else 22.0
		var h := 22.0 if vert else 7.0
		var x := roundf(at.x + u.x * 3 - w / 2)
		var y := roundf(at.y + u.y * 3 - h / 2)
		var frame: Color = P["yellow"] if d["to"] == hop and blink else P["amber"]
		draw_rect(Rect2(x - 1, y - 1, w + 2, h + 2), frame)
		draw_rect(Rect2(x, y, w, h), P["slate"] if locked else P["ink"])
		var bar: Color = P["grey"] if locked else Color("#2b2440")
		draw_rect(Rect2(x + 2, y + 2, 3, h - 4) if vert else Rect2(x + 2, y + 2, w - 4, 3), bar)
		if d["to"] == hop:
			var n := Vector2(-u.y, u.x)
			var tip: Vector2 = at - u * 14.0
			draw_colored_polygon(PackedVector2Array([tip + u * 5.0, tip - n * 4.0, tip + n * 4.0]), P["yellow"])
