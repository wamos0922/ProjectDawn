extends Node2D
## Draws one room: wall ring, floor tiles, furniture, stations, doors and the hold rings.
## Owner: Sufi (gameplay). Created by dawn.gd, one per room, at the room's grid cell.

const WD := preload("res://game/dawn/world_data.gd")

var id := ""
var game                     ## dawn.gd
var stations: Array = []
var doors: Array = []


func _ready() -> void:
	z_index = -10


func _draw() -> void:
	var r := WD.room(id)
	var w := WD.world_of(id)
	var tone: Dictionary = WD.TONES[r["tone"]]
	var floor_c: Color = WD.PAL[tone["f"]]
	var trim: Color = WD.PAL[tone["b"]]
	var pts := WD.outline(id)
	draw_rect(Rect2(Vector2.ZERO, WD.ROOM_SIZE), WD.VOID[w])
	var ring := PackedVector2Array()
	for p in pts:
		ring.append(p + (p - WD.IB_CENTER).normalized() * 5.0)
	draw_colored_polygon(ring, floor_c.darkened(0.55))
	draw_colored_polygon(pts, floor_c.darkened(0.15))
	for y in range(30, 172, 8):
		for x in range(20, 300, 8):
			if (x / 8 + y / 8) % 2 == 0 and WD.inside_local(id, Vector2(x, y)) and WD.inside_local(id, Vector2(x + 8, y)) \
					and WD.inside_local(id, Vector2(x, y + 8)) and WD.inside_local(id, Vector2(x + 8, y + 8)):
				draw_rect(Rect2(x, y, 8, 8), floor_c.darkened(0.05))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, trim, 1.0)
	for pr in r["props"]:
		var pos: Vector2 = WD.to_local(pr[1], pr[2])
		_prop(pr[0], Rect2(pos - Vector2(pr[3], pr[4]) / 2.0, Vector2(pr[3], pr[4])), tone)
	var hold: Dictionary = game.current_hold()
	for s in stations:
		_station(s, hold)
	_doors()
	# soft ring under anything a local player can use right now
	for p in game.local_crew():
		if WD.room_at(p.position) == id:
			var s: Dictionary = game.station_near(p)
			if not s.is_empty():
				draw_circle(s["pos"], 11.0, Color(WD.PAL["yellow"], 0.18))


func _doors() -> void:
	var obj: Dictionary = game.objective()
	var hop := ""
	if obj.get("room", "") != "" and obj["room"] != id:
		hop = WD.next_hop(id, obj["room"], game.locked_map())
	var blink := int(Time.get_ticks_msec() / 300) % 2 == 0
	for d in doors:
		var locked: bool = game.is_locked(d["to"])
		var c: Color = WD.PAL["rose"] if locked else WD.PAL["amber"]
		if d["to"] == hop and blink:
			c = WD.PAL["yellow"]
		var n: Vector2 = Vector2(-d["dir"].y, d["dir"].x)
		var a: Vector2 = d["pos"] + n * WD.DOOR_WIDTH / 2.0
		var b: Vector2 = d["pos"] - n * WD.DOOR_WIDTH / 2.0
		draw_line(a, a + d["dir"] * 6.0, c, 2.0)
		draw_line(b, b + d["dir"] * 6.0, c, 2.0)
		if locked:
			draw_line(a, b, WD.PAL["rose"], 2.0)
		else:
			draw_line(a + d["dir"] * 6.0, b + d["dir"] * 6.0, WD.VOID[WD.world_of(id)], 3.0)
		if d["to"] == hop:
			var tip: Vector2 = d["pos"] - d["dir"] * 12.0
			draw_colored_polygon(PackedVector2Array([tip + d["dir"] * 5.0, tip - n * 4.0, tip + n * 4.0]), WD.PAL["yellow"])


func _prop(kind: String, rect: Rect2, tone: Dictionary) -> void:
	var P := WD.PAL
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	match kind:
		"rug":
			draw_rect(rect, Color(P[tone["b"]], 0.16))
		"rocket":
			draw_rect(Rect2(x + w / 2 - 5, y + 6, 10, h - 6), P["ink"])
			draw_rect(Rect2(x + w / 2 - 4, y + 7, 8, h - 12), P["light"])
			draw_colored_polygon(PackedVector2Array([Vector2(x + w / 2, y), Vector2(x + w / 2 - 5, y + 8), Vector2(x + w / 2 + 5, y + 8)]), P["red"])
			draw_rect(Rect2(x + w / 2 - 8, y + h - 8, 16, 4), P["orange"])
		"capsule":
			draw_rect(rect, P["ink"])
			draw_rect(rect.grow(-1), Color("#2b3a45"))
			draw_rect(Rect2(x + 3, y + 3, w - 6, h - 8), Color("#0a1a1a"))
			draw_rect(Rect2(x + w / 2 - 2, y + 1, 4, 1), P["green"])
		"screen":
			draw_rect(rect, P["ink"])
			draw_rect(rect.grow(-1), P["navy"])
			for i in range(0, int(w) - 4, 3):
				draw_rect(Rect2(x + 2 + i, y + 3 + (i * 7) % maxi(1, int(h) - 6), 2, 1), P["cyan"] if i % 2 == 0 else P[tone["b"]])
		"plant":
			draw_rect(Rect2(x, y + h - 5, w, 5), P["dbrown"])
			for i in range(0, int(w), 4):
				draw_rect(Rect2(x + i, y + 2, 3, h - 6), P["forest"])
				draw_rect(Rect2(x + i + 1, y, 2, 3), P["green"])
		"dish":
			draw_circle(rect.get_center(), minf(w, h) / 2.0, P["ink"])
			draw_circle(rect.get_center(), minf(w, h) / 2.0 - 1, P["light"])
			draw_circle(rect.get_center(), 3, P["grey"])
		"tank":
			draw_rect(rect, P["ink"])
			draw_rect(rect.grow(-1), P["light"])
			draw_rect(Rect2(x + 2, y + 2, 2, h - 4), P["white"])
			draw_rect(Rect2(x + 1, y + h * 0.6, w - 2, 2), P[tone["b"]])
		"bed":
			draw_rect(rect, P["ink"])
			draw_rect(rect.grow(-1), P["white"])
			draw_rect(Rect2(x + 1, y + h / 2, w - 2, h / 2 - 1), P["sky"])
		"panels":
			for i in range(0, int(w), 10):
				draw_rect(Rect2(x + i, y, 9, h), P["ink"])
				draw_rect(Rect2(x + i + 1, y + 1, 7, h - 2), Color("#124e89"))
				draw_rect(Rect2(x + i + 1, y + 1, 7, 1), Color("#2c6fb0"))
		"drill":
			draw_rect(Rect2(x + w / 2 - 3, y, 6, h), P["ink"])
			draw_rect(Rect2(x + w / 2 - 2, y + 1, 4, h - 2), P["grey"])
			draw_rect(Rect2(x, y + 3, w, 4), P["orange"])
		"ice":
			draw_rect(rect, P["ink"])
			draw_rect(rect.grow(-1), P["cyan"])
			draw_rect(Rect2(x + 2, y + 2, 3, 2), P["white"])
		"pipes":
			draw_rect(rect, P["ink"])
			draw_rect(Rect2(x + 1, y + 1, w - 2, 2), P["sky"])
			draw_rect(Rect2(x + 1, y + h - 3, w - 2, 2), P["light"])
		"dome":
			draw_circle(rect.get_center(), minf(w, h) / 2.0, P["cyan"])
			draw_circle(rect.get_center(), minf(w, h) / 2.0 - 1, Color("#1a3a2a"))
			for i in 5:
				draw_rect(Rect2(x + w / 2 - 8 + i * 4, y + h / 2 - 2 + (i % 2) * 3, 2, 3), P["green"])
		"rtg":
			draw_rect(rect, P["ink"])
			draw_rect(rect.grow(-1), P["steel"])
			for i in range(2, int(w) - 2, 3):
				draw_rect(Rect2(x + i, y + 1, 1, h - 2), P["slate"])
			draw_rect(Rect2(x + w / 2 - 2, y + h / 2 - 2, 4, 4), P["orange"])
		"scope":
			draw_rect(Rect2(x + w / 2 - 3, y, 6, h), P["ink"])
			draw_rect(Rect2(x + w / 2 - 2, y + 1, 4, h - 6), P["light"])
			draw_rect(Rect2(x + w / 2 - 2, y + 1, 4, 2), P["cyan"])
			draw_rect(Rect2(x, y + h - 4, w, 4), P["steel"])
		"rack":
			draw_rect(rect, P["ink"])
			draw_rect(rect.grow(-1), P["slate"])
			for yy in range(3, int(h) - 2, 4):
				draw_rect(Rect2(x + 2, y + yy, w - 4, 2), P["steel"])
				draw_rect(Rect2(x + 3, y + yy, 1, 1), P["green"] if yy % 8 == 3 else P["cyan"])
		"crate":
			draw_rect(rect, P["ink"])
			draw_rect(rect.grow(-1), P["clay"])
			draw_line(rect.position + Vector2(1, 1), rect.end - Vector2(2, 2), P["brown"])
			draw_line(Vector2(rect.end.x - 2, y + 1), Vector2(x + 1, rect.end.y - 2), P["brown"])
		"table":
			draw_rect(rect, P["ink"])
			draw_rect(rect.grow(-1), P[tone["t"]])
			for i in range(4, int(w) - 4, 6):
				draw_rect(Rect2(x + i, y + h / 2, 3, 1), P[tone["b"]])
		_:  # bench
			draw_rect(rect, P["ink"])
			draw_rect(Rect2(x + 1, y + 1, w - 2, h - 4), P["brown"])
			draw_rect(Rect2(x + 1, y + 1, w - 2, 1), P["clay"])


func _station(s: Dictionary, hold: Dictionary) -> void:
	var P := WD.PAL
	var x: float = s["pos"].x
	var y: float = s["pos"].y
	var sid: String = s["id"]
	if sid.begins_with("poster"):
		var ps: Dictionary = s["poster"]
		var th: Dictionary = game.POSTER_THEMES[ps["world"]]
		draw_rect(Rect2(x - 9, y - 26, 18, 16), P["ink"])
		draw_rect(Rect2(x - 8, y - 25, 16, 14), th["bg"])
		draw_rect(Rect2(x - 3, y - 23, 6, 5), th["planet"])
		draw_rect(Rect2(x - 7, y - 16, 10, 2), th["acc"])
		draw_rect(Rect2(x - 7, y - 13, 7, 1), th["chip"])
		if not game.found.has(int(ps["n"])):
			draw_rect(Rect2(x + 5, y - 24, 2, 2), P["yellow"])
		return
	if sid == "locker":
		draw_rect(Rect2(x - 12, y - 30, 24, 24), P["ink"])
		draw_rect(Rect2(x - 11, y - 29, 22, 22), P["steel"])
		for dx in [-10, 2]:
			draw_rect(Rect2(x + dx, y - 28, 8, 20), P["grey"])
			draw_rect(Rect2(x + dx + 2, y - 26, 4, 4), Color("#e8ecf2"))
			draw_rect(Rect2(x + dx + 1, y - 21, 6, 8), Color("#e8ecf2"))
		draw_rect(Rect2(x - 3, y - 6, 6, 1), P["yellow"])
		return
	if s.has("role"):
		# role spot: a coloured pad; it pulses when the current hold needs it
		var col: Color = game.RoleSprites.TAGS[s["role"]]
		var need: bool = hold.get("need", {}).has(s["role"]) and hold["need"][s["role"]][0] == id and hold["need"][s["role"]][1] == sid
		if need:
			var on: bool = game.on_spot(s["role"], id, sid)
			var k := int(Time.get_ticks_msec() / 250) % 2
			for a in 24:
				if (a + k) % 2 == 0:
					var an := a / 24.0 * TAU
					draw_rect(Rect2(round(x + cos(an) * 13), round(y - 2 + sin(an) * 6), 2, 1), P["green"] if on else col)
		draw_rect(Rect2(x - 7, y - 3, 14, 5), P["ink"])
		draw_rect(Rect2(x - 6, y - 2, 12, 3), col.darkened(0.3))
		if s.get("seat", false):
			draw_rect(Rect2(x - 5, y - 10, 10, 7), P["slate"])
		return
	# main console; glows when the objective is here
	var ob: Dictionary = game.objective()
	if ob.get("room", "") == id and not ob.get("hold", false):
		var k2 := int(Time.get_ticks_msec() / 250) % 2
		for a in 24:
			if (a + k2) % 2 == 0:
				var an2 := a / 24.0 * TAU
				draw_rect(Rect2(round(x + cos(an2) * 13), round(y - 2 + sin(an2) * 6), 2, 1), P["yellow"])
	draw_rect(Rect2(x - 9, y - 14, 18, 12), P["ink"])
	draw_rect(Rect2(x - 8, y - 13, 16, 9), P["teal"])
	draw_rect(Rect2(x - 6, y - 11, 8, 1), P["cyan"])
	draw_rect(Rect2(x - 6, y - 9, 5, 1), P["cyan"])
	draw_rect(Rect2(x - 10, y - 2, 20, 3), P["steel"])
