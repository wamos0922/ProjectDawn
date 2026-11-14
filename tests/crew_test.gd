extends SceneTree
## Crew control check: autopilot fills holds, TAB switches, may_do rules, follow.
var g
var t := 0
var out := []
func _init():
	change_scene_to_file.call_deferred("res://game/dawn/dawn.tscn")
func ok(c: bool, m: String): out.append(("PASS " if c else "FAIL ") + m)
func _process(_d):
	if t == 0 and g == null and root.has_node("Network") and not root.get_node("Network").has_meta("my_role"):
		root.get_node("Network").set_meta("my_role", "sci")
		root.get_node("Network").set_meta("crew_mode", "autopilot")
		change_scene_to_file.call_deferred("res://game/dawn/dawn.tscn")
		return false
	if g == null:
		g = current_scene
		if g == null or not g.has_method("commit"): g = null
		return false
	t += 1

	if t > 600: print("\n".join(out)); quit(); return false
	while g.ui.dialogue_open(): g.ui.advance()
	if g.story.sui._screen and g.S["scene"] == "game": g.story.sui._close()
	var C = g.crew_ctl
	if t == 5:
		ok(C.me_role == "sci", "solo starts as picked role (sci)")
		ok(g.camera.target == g.crew["sci"], "camera follows sci")
		ok(not g.crew["sci"].ai and g.crew["eng"].ai, "sci is player, eng is autopilot")
		ok(g.local_crew().size() == 4, "solo moves all four")
		C.cycle()
		ok(C.me_role == "nav" and g.camera.target == g.crew["nav"] and g.crew["sci"].ai, "TAB -> nav")
		C.switch_to("qm"); C.cycle()
		ok(C.me_role == "eng", "cycle wraps to eng")
		var m = C.may_do(g.crew["eng"], "sci")
		ok(not m["ok"] and "TAB" in m["msg"], "solo role job says press TAB: " + m["msg"])
		ok(C.may_do(g.crew["eng"], "eng")["ok"], "own job ok")
	if t == 6:
		var h = {"id": "test", "need": {}}
		for r in g.ROLES:
			var st = g._stations.get("earth.mc", []).filter(func(s): return s.get("role", "") == r)
			if not st.is_empty(): h["need"][r] = ["earth.mc", st[0]["id"]]
		out.append("hold needs " + str(h["need"].keys()))
		g.set_meta("h", h)
	if t > 6 and t < 400:
		var h = g.get_meta("h")
		# drive autopilot tick directly with this hold
		for p in C.local():
			if p == C.me(): continue
			var tg = C._autopilot_target(p.role, h)
			if not tg.is_empty(): g.place(p, tg["room"], tg["pos"])
	if t == 400:
		var h = g.get_meta("h")
		var miss = []
		for r in h["need"]:
			if r != C.me_role and not g.on_spot(r, h["need"][r][0], h["need"][r][1]): miss.append(r)
		ok(miss.is_empty(), "autopilot put every non-me role on its hold spot (missing %s)" % str(miss))
		C.toggle_autopilot()
		var someone = "sci"
		ok(C._autopilot_target(someone, h).is_empty() or not C.autopilot, "autopilot off -> no hold moves")
		# follow
		C.follow = true
		C.on_leader_moved("earth.crew", Vector2(160, 90))
		var n = 0
		for r in g.ROLES:
			if r != C.me_role and WD().room_at(g.crew[r].position) == "earth.crew": n += 1
		ok(n == 3, "follow brings the other 3 through the door (%d)" % n)
		for l in out: print(l)
		quit()
	return false
func WD(): return preload("res://game/dawn/world_data.gd")
