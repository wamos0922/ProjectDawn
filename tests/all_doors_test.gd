extends SceneTree
## Run: godot --headless --path . -s res://tests/all_doors_test.gd   (about 3 minutes)
## For every door in every room: start 30 px inside, walk out with real physics, must arrive.
var g
var n := 0
var jobs := []
var job := {}
var t := 0
var fails := []
const WD := preload("res://game/dawn/world_data.gd")
func _init():
	change_scene_to_file.call_deferred("res://game/dawn/dawn.tscn")
func _physics_process(_d):
	if g == null:
		g = current_scene
		if g == null or not g.has_method("commit"): g = null; return false
		for id in WD.rooms():
			for d in WD.doors(id): jobs.append({"from": id, "to": d["to"]})
		return false
	while g.ui.dialogue_open(): g.ui.advance()
	if g.story.sui._screen and g.S["scene"] == "game": g.story.sui._close()
	var p = g.crew_ctl.me()
	p.ai = true
	if g.world_map.busy(): return false
	if job.is_empty():
		if jobs.is_empty():
			print("doors failed: ", fails.size(), " ", fails); quit(); return false
		job = jobs.pop_back()
		var w := WD.world_of(job["from"])
		for r in g.ROLES: g.S["suits"][r] = true
		g.S["step"] = 9; g.S["ms"] = 9; g.S["rs"] = 9; g.S["hydro"] = true; g.S["storm"] = {}
		g.S["world"] = w; g.commit()
		var d = WD.door_to(job["from"], job["to"])
		g.place(p, job["from"], d["pos"] - d["dir"] * 30)
		p.can_move = true
		t = 0
		return false
	t += 1
	if WD.room_at(p.position) == job["to"]:
		job = {}; return false
	if t > 200:
		var dd = WD.door_to(job["from"], job["to"]); fails.append(job["from"] + ">" + job["to"] + " stuck " + str(p.position - WD.room_origin(job["from"])) + " door " + str(dd["pos"]) + " dir " + str(dd["dir"]) + " locked " + str(g.is_locked(job["to"]))); job = {}; return false
	var d = WD.door_to(job["from"], job["to"])
	p.ai_input = (d["pos"] + d["dir"] * 10 - (p.position - WD.room_origin(job["from"]))).normalized()
	return false
