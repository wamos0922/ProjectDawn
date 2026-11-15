extends SceneTree
## Opens each new minigame from its station (story.gd role_task), plays it with a simple bot until
## TASK COMPLETE, presses CONTINUE and checks that the task was recorded.
## Run: godot --headless -s tests/new_minigames_test.gd   (add SHOTS=1 and no --headless for pictures)
var g
var n := 0
var ci := -1
var phase := ""
var log := []
var game: Control
var only := OS.get_environment("ONLY")
var cases := []
var shots := OS.get_environment("SHOTS") != ""
## [game id, world, step/ms, room key, what counts as done]
var cases_all := [
	["E1", "earth", 1, "shop", "cube"], ["S1", "earth", 1, "ozone", "uvcal"], ["Q1", "earth", 1, "comms", "tune"],
	["N1", "earth", 5, "nav", "perigee"], ["N2", "moon", 0, "landing", "arrival"], ["S2", "moon", 1, "science", "ms2"],
	["Q2", "moon", 2, "solar", "outpost"], ["E2", "moon", 3, "mine", "icescan"], ["S3", "moon", 5, "factory", "sunscan"],
	["N3", "moon", 6, "port", "l1"], ["E3", "moon", 6, "port", "aperture"], ["Q3", "moon", 6, "lc", "datahome"],
	["PF", "earth", 5, "pad", "bolts"]]


func _init():
	change_scene_to_file.call_deferred("res://game/dawn/dawn.tscn")


func buttons(node: Node, out: Array) -> Array:
	for c in node.get_children():
		if c is Button: out.append(c)
		buttons(c, out)
	return out


func find(text: String) -> Button:
	if g.ui._panel == null: return null
	for b in buttons(g.ui._panel, []):
		if b.text.find(text) >= 0 and not b.disabled: return b
	return null


func find_game(node: Node) -> Control:
	for c in node.get_children():
		if c is Control and "host" in c and c.has_method("finish"): return c
		var x := find_game(c)
		if x: return x
	return null


func shot(name: String) -> void:
	if shots:
		root.get_texture().get_image().save_png("/tmp/nm_%s.png" % name)


func _process(_d):
	if g == null:
		g = current_scene
		if g == null or not g.has_method("commit"): g = null; return false
		g.story.sui._intro_done(); g.story.sui._close()
		cases = cases_all.filter(func(c): return only == "" or c[0] in only.split(","))
		return false
	n += 1
	if phase == "":
		ci += 1
		if ci >= cases.size():
			print("\n".join(log)); quit(); return true
		var c: Array = cases[ci]
		g.ui.close_panel()
		while g.ui.dialogue_open(): g.ui.advance()
		g.S["world"] = c[1]; g.S["tasks"] = {}; g.S["storm"] = {}; g.S["sats_chosen"] = false
		if c[1] == "earth": g.S["step"] = c[2]
		else: g.S["ms"] = c[2]
		if c[0] == "E3": g.S["tasks"]["l1"] = true
		if c[0] == "Q3": g.S["tasks"]["l1"] = true; g.S["tasks"]["aperture"] = true
		g.commit()
		var a: Dictionary = g.story.role_task(c[3])
		if a.is_empty(): log.append("NO TASK " + c[0]); return false
		a["fn"].call()
		game = find_game(g.ui._panel)
		if game == null: log.append("NO GAME " + c[0]); return false
		phase = "intro"; n = 0
		return false
	var c: Array = cases[ci]
	if phase == "intro":
		if n == 3: shot(c[0] + "_0intro")
		if n == 4: game._start(); phase = "play"; n = 0
		return false
	if n == 40: shot(c[0] + "_1play")
	var cont := find("CONTINUE")
	if cont:
		shot(c[0] + "_2done")
		cont.pressed.emit()
		var ok: bool = g.S["ms"] == 2 if c[4] == "ms2" else g.S["tasks"].get(c[4], false)
		log.append(("OK   " if ok else "FAIL ") + "%s (%s) recorded=%s stars=%s" % [c[0], c[4], ok, game._result.get("stars", "?")])
		phase = ""; return false
	if game.over and game._result.get("stars", 0) == 0:
		log.append("LOST %s: %s" % [c[0], game._result["why"]]); shot(c[0] + "_lost"); phase = ""; return false
	if n > 20000:
		log.append("TIMEOUT " + c[0]); phase = ""; return false
	bot(c[0])
	return false


## A simple player for each game.
func bot(id: String) -> void:
	if n < 45: return                     # let the screenshot happen first
	match id:
		"E1":
			for p in game.pieces:
				if not p["lock"]:
					var h: Dictionary = p["src"]
					game.press(Vector2(p["x"] + 2, p["y"] + 2))
					game.drag(Vector2(h["x"] + (h["w"] - p["w"]) / 2.0, h["y"] + (h["h"] - p["h"]) / 2.0) + Vector2(game.held["ox"], game.held["oy"]))
					game.release(Vector2.ZERO)
					return
		"S1":
			var want: int = 1984 if game.part == 1 else 1994
			for i in game.order.size():
				if game.OZ[game.order[i]]["y"] == want: game.sel = i
			game.lock()
		"Q1":
			if game.loaded.is_empty():
				game.press(game._card(1).get_center())
			else:
				game.launch()
		"N1":
			if game.st.is_empty():
				game.v = 7.7; game.fire()
		"N2":
			if game.fired == null and int(game.i) >= game.peri:
				game.fire()
		"S2":
			if game.round_ == 1 and game.stage == "peak": game.press(Vector2(game._l_to_x(308), game.GY + 50))
			elif game.round_ == 1: game.press(game._row(0).get_center())
			else:
				for d in game.ABS:
					if not d in game.found: game.press(Vector2(game._l_to_x(d), game.GY + 50)); return
		"Q2":
			if game.sel.is_empty():
				game.press(game._card(1).get_center()); game.press(game._card(6).get_center())
			else:
				game.seal()
		"E2":
			for i in game.cells.size():
				var q: Dictionary = game.cells[i]
				if q["temp"] < 120 and q["neu"] < 0.8:
					var p := Vector2((i % game.CW) * 8 + 4, (i / game.CW) * 8 + 4)
					if p.x >= 100 and p.x <= 540 and p.y >= 72 and p.y <= 288:
						game.mouse = p; game.press(p); return
		"S3":
			for i in game.BANDS.size():
				game.sel = i; game._tag(game.BANDS[i]["a"])
			game.check()
		"N3":
			var future: float = game.d + game.v * 1.5
			if game.fx <= 0 and absf(future) > 6 and signf(game.v) == signf(game.d) and game.fuel > 0:
				game.thrust(-1 if future > 0 else 1)
		"E3":
			game.holding = game.tension < 55 and game.jam_t <= 0
		"Q3":
			if game.inst == null: game.choose(4)
			elif not game.rip.is_empty(): game.press(game.rip[0]["p"])
		"PF":
			for i in game.BOLTS.size():
				if not game.tight[i]: game.press(game.BOLTS[i]); return
