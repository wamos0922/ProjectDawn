extends SceneTree
## Sound engine check: every file loads, music follows the situation, one-shot sounds play.
## Run: godot --headless --path . -s res://tests/sound_test.gd
var g
var n := 0
var out := []
var snd


func _init() -> void:
	change_scene_to_file.call_deferred("res://game/dawn/dawn.tscn")


func ok(c: bool, m: String) -> void:
	out.append(("PASS " if c else "FAIL ") + m)


func _process(_d: float) -> bool:
	if g == null:
		g = current_scene
		if g == null or not g.has_method("commit"):
			g = null
			return false
		snd = root.get_node("Sound")
		for k in snd.MUSIC:
			var p: String = snd.MUSIC[k]
			ok(p == "" or ResourceLoader.exists(p), "music file for '%s' exists" % k)
		for k in snd.SFX:
			ok(ResourceLoader.exists(snd.SFX[k]), "sound file for '%s' exists" % k)
		return false
	n += 1
	while g.ui.dialogue_open():
		g.ui.advance()
	if g.story.sui._screen and g.S["scene"] == "game":
		g.story.sui._close()
	match n:
		5:
			ok(snd.current_situation() == "earth", "Earth plays the earth music (%s)" % snd.current_situation())
			ok(snd._tracks[snd._front].playing, "a music player is playing")
			var p = g.crew_ctl.me()
			var from := "earth.crew"
			g.world_map.travel(from, "earth.mc", p.role, func(): g._arrive(p, from, "earth.mc"))
		7:
			ok(snd.current_situation() == "corridor", "door trip switches to corridor (%s)" % snd.current_situation())
			ok(snd._path.ends_with("music_earth.wav"), "corridor keeps the earth music for now")
			g.world_map._trip["t"] = 99.0
		12:
			g.S["step"] = 1
			g.commit()
			g.story.role_task("ozone")["fn"].call()
		14:
			ok(snd.current_situation() == "minigame", "minigame open switches to minigame (%s)" % snd.current_situation())
			g.ui.close_panel()
		16:
			g.S["world"] = "moon"
			g.S["ms"] = 4
			g.S["storm"] = {"kind": "solar", "t": 25.0}
			g.commit()
		18:
			ok(snd.current_situation() == "storm", "solar storm plays the alarm music (%s)" % snd.current_situation())
			ok(snd._voices.any(func(v): return v.playing), "storm start played the alarm beep")
			g.S["storm"] = {}
			g.S["scene"] = "ending"
			g.commit()
		22:
			ok(snd.current_situation() == "ending", "ending plays the ending music (%s)" % snd.current_situation())
			for v in snd._voices:
				v.stop()
			var b := Button.new()
			root.add_child(b)
			b.pressed.emit()
			ok(snd._voices.any(func(v): return v.playing), "every button clicks")
			b.queue_free()
		24:
			print("\n".join(out))
			var fails := out.filter(func(l): return l.begins_with("FAIL")).size()
			print("%d passed, %d failed" % [out.size() - fails, fails])
			quit()
	return false
