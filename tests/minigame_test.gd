extends SceneTree
## Plays each minigame through its real buttons until CONTINUE, then checks the task was recorded.
var g
var n := 0
var cases := []
var ci := -1
var phase := ""
var log := []
var vals := []
var vi := 0
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
func sliders() -> Array:
	var out := []
	var stack: Array = [g.ui._panel]
	while not stack.is_empty():
		var x = stack.pop_back()
		if x is HSlider: out.append(x)
		if x is CheckBox: out.append(x)
		stack.append_array(x.get_children())
	return out
func _process(_d):
	if g == null:
		g = current_scene
		if g == null or not g.has_method("commit"): g = null; return false
		g.story.sui._intro_done(); g.story.sui._close()
		cases = [
			["uvcal", "earth", 1, "ozone", "STOP"], ["tune", "earth", 1, "comms", "LOCK IN"], ["wind", "earth", 1, "nav", "cell"],
			["perigee", "earth", 5, "nav", "LAUNCH NOW"], ["cargo", "earth", 5, "power", "SEAL CARGO"], ["bolts", "earth", 5, "pad", "TIGHTEN"],
			["site", "earth", 5, "ozone", "card"], ["l1", "moon", 6, "port", "LOCK IN"]]
		return false
	n += 1
	if phase == "" :
		ci += 1
		if ci >= cases.size():
			print("\n".join(log)); quit(); return true
		var c: Array = cases[ci]
		g.ui.close_panel()
		g.S["world"] = c[1]; g.S["tasks"] = {}
		if c[1] == "earth": g.S["step"] = c[2]
		else: g.S["ms"] = c[2]
		g.commit()
		var a: Dictionary = g.story.role_task(c[3])
		if a.is_empty(): log.append("NO TASK " + c[0]); phase = ""; return false
		a["fn"].call()
		phase = "play"; vi = 0; n = 0
		return false
	var c: Array = cases[ci]
	var cont := find("CONTINUE")
	if cont:
		cont.pressed.emit()
		log.append(("OK   " if g.S["tasks"].get(c[0], false) else "FAIL ") + c[0] + " won and recorded=" + str(g.S["tasks"].get(c[0], false)))
		phase = ""; return false
	if n > 900:
		log.append("TIMEOUT " + c[0]); phase = ""; return false
	match c[4]:
		"STOP", "TIGHTEN", "LAUNCH NOW":
			var b := find(c[4]); if b: b.pressed.emit()
		"LOCK IN", "TEST BURN":
			var sl := sliders().filter(func(x): return x is HSlider)
			var s0: HSlider = sl[0]
			s0.value = s0.min_value + vi * s0.step; vi += 1
			var b2 := find(c[4]); if b2: b2.pressed.emit()
		"SEAL CARGO":
			for cb in sliders():
				if cb is CheckBox and cb.text.find("needed") >= 0: cb.button_pressed = true
			var b3 := find("SEAL"); if b3: b3.pressed.emit()
		"cell", "card":
			var bs := buttons(g.ui._panel, []).filter(func(b): return not b.disabled and b.text != "✕")   # not the close button
			if not bs.is_empty(): bs[vi % bs.size()].pressed.emit(); vi += 1
	return false
