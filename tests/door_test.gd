extends SceneTree
## Walk the controlled crew member out of a door: the map trip must start, then land in the next room.
var g
var n := 0
const WD := preload("res://game/dawn/world_data.gd")
func _init():
	change_scene_to_file.call_deferred("res://game/dawn/dawn.tscn")
func _process(_d):
	if g == null:
		g = current_scene
		if g == null or not g.has_method("commit"): g = null
		return false
	n += 1
	while g.ui.dialogue_open(): g.ui.advance()
	if g.story.sui._screen and g.S["scene"] == "game": g.story.sui._close()
	var p = g.crew_ctl.me()
	if n == 10:
		var id := WD.room_at(p.position)
		var d: Dictionary = WD.doors(id)[0]
		g.set_meta("want", d["to"])
		var c: Vector2 = d["pos"] - WD.IB_CENTER
		p.position = WD.room_origin(id) + d["pos"] + c.normalized() * (WD.EXIT_DEPTH + 2)
		print("from ", id, " via door to ", d["to"])
	if n == 12:
		print("trip started: ", g.world_map.busy(), " map visible: ", g.world_map.visible, " can_move: ", p.can_move)
	if n > 12 and not g.world_map.busy():
		print("arrived in ", WD.room_at(p.position), " (wanted ", g.get_meta("want"), ") can_move: ", p.can_move, " after frames ", n)
		quit()
	if n > 400:
		print("TIMEOUT"); quit()
	return false
