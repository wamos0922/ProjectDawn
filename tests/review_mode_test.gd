extends SceneTree
## Review mode check: with review mode on, every minigame is a placeholder with one COMPLETE
## button, and pressing it records the task exactly like a real win.
## Run:  godot --headless --path . -s res://tests/review_mode_test.gd
var g
var out := []
var step := 0


func _init():
	change_scene_to_file.call_deferred("res://game/dawn/dawn.tscn")


func ok(c: bool, m: String) -> void:
	out.append(("PASS " if c else "FAIL ") + m)


func buttons(node: Node, acc: Array) -> Array:
	for c in node.get_children():
		if c is Button:
			acc.append(c)
		buttons(c, acc)
	return acc


func find(text: String) -> Button:
	if g.ui._panel == null:
		return null
	for b in buttons(g.ui._panel, []):
		if b.text.find(text) >= 0 and not b.disabled:
			return b
	return null


func _process(_d):
	if g == null:
		g = current_scene
		if g == null or not g.has_method("commit"):
			g = null
			return false
		g.story.sui._intro_done()
		g.story.sui._close()
		return false
	step += 1
	if step < 5:
		return false
	while g.ui.dialogue_open():
		g.ui.advance()
	var MG = g.Minigames

	# 1. off by default: the real minigame opens
	MG.set_review_mode(false)
	_task("earth", 1, "ozone")
	ok(find("COMPLETE") == null and find("STOP") != null, "review mode off: the real UV minigame opens (STOP button, no COMPLETE)")
	g.ui.close_panel()

	# 2. F8 turns it on
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F8
	ev.pressed = true
	g._unhandled_input(ev)
	ok(MG.review_mode(), "F8 turns review mode on")

	# 3. every station minigame is a placeholder and COMPLETE records the task
	var cases := [["uvcal", "earth", 1, "ozone"], ["tune", "earth", 1, "comms"], ["wind", "earth", 1, "nav"],
		["perigee", "earth", 5, "nav"], ["cargo", "earth", 5, "power"], ["bolts", "earth", 5, "pad"],
		["site", "earth", 5, "ozone"], ["burn", "mars", 4, "fuel"], ["bolts2", "mars", 4, "pad"], ["window", "mars", 6, "pad"]]
	for c in cases:
		var opened := _task(c[1], c[2], c[3], c[0] == "window")
		var b := find("COMPLETE")
		ok(opened and b != null and find("STOP") == null and find("LOCK IN") == null, "%s: placeholder panel with COMPLETE" % c[0])
		if b:
			b.pressed.emit()
		ok(g.S["tasks"].get(c[0], false) and g.ui._panel == null, "%s: one click records the task and closes the panel" % c[0])

	# 4. the minigames not reached above also use the placeholder
	var hits := {"n": 0}
	var win := func(): hits["n"] += 1
	for call in [func(): g.story.mg.scan("sci", win, func(): pass), func(): g.story.mg.wipe("qm", win),
			func(): g.story.mg.wires("qm", "WIRES", "x", win), func(): g.story.mg.pick("sci", "PICK", "x", [], win),
			func(): g.story.mg.pack("qm", "PACK", "x", [], 10, win), func(): g.story.mg.sliders("eng", "S", "x", [], func(v): return {}, win)]:
		call.call()
		var b := find("COMPLETE")
		if b:
			b.pressed.emit()
	ok(hits["n"] == 6, "scan, wipe, wires, pick, pack, sliders: all placeholders win (%d/6)" % hits["n"])

	# 5. Esc > SETTINGS shows the switch, and it turns review mode off
	g.esc_menu._settings()
	var sw := find("REVIEW MODE: ON")
	ok(sw != null, "Esc > SETTINGS shows REVIEW MODE: ON")
	if sw:
		sw.pressed.emit()
	ok(not MG.review_mode() and find("REVIEW MODE: OFF") != null, "settings switch turns it off")
	g.ui.close_panel()

	print("\n".join(out))
	var fails := out.filter(func(l): return l.begins_with("FAIL")).size()
	print("%d passed, %d failed" % [out.size() - fails, fails])
	quit()
	return true


## Put the story where this station has a minigame and press E on it. Returns true if a panel opened.
func _task(world: String, stage: int, station: String, window := false) -> bool:
	g.ui.close_panel()
	g.S["world"] = world
	g.S["tasks"] = {"pack2": true, "burn": true, "bolts2": true, "seeds": true} if window else {}
	if world == "earth":
		g.S["step"] = stage
	else:
		g.S["rs"] = stage
	g.commit()
	var a: Dictionary = g.story.role_task(station)
	if a.is_empty():
		return false
	a["fn"].call()
	return g.ui._panel != null
