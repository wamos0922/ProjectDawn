extends SceneTree
## Engine tests. Owner: Sufi.
## Run: godot --headless --path . -s res://tests/run_tests.gd

var _fails := 0
var _passes := 0

func _init() -> void:
	var eng = load("res://engine/game_engine.gd").new()
	eng._ready()

	_check(eng.get_acts().size() == 5, "5 acts load")
	_check(not eng.get_mission("m1_2_ozone_cubesat").is_empty(), "mission m1_2 loads")
	_check(eng.get_mission("does_not_exist").is_empty(), "unknown mission returns empty")
	_check(eng.get_parts("m1_2_ozone_cubesat").size() > 0, "starting parts unlocked")

	var empty: Dictionary = eng.check_design("m1_2_ozone_cubesat", {"parts": [], "signoffs": {}})
	_check(not empty["ok"], "empty design is blocked")

	var design := {
		"parts": ["frame_1u", "phone_computer", "uv_sensor", "solar_body", "battery_medium", "radio_uhf"],
		"launcher": "rideshare_small", "fuel_kg": 0,
		"signoffs": {"engineer": true, "scientist": true, "navigator": true, "quartermaster": true}}
	var check: Dictionary = eng.check_design("m1_2_ozone_cubesat", design)
	_check(is_equal_approx(check["totals"]["mass_kg"], 1.2), "mass totals 1.2 kg")

	eng.make_choice("m1_1_launch_site", "site_bunker")
	var result: Dictionary = eng.run_mission("m1_2_ozone_cubesat", design)
	_check(result["outcome"] == "success", "valid design launches (stub)")
	_check(eng.get_state()["ozone"] == 15, "ozone meter rises by reward")

	var RS = load("res://game/player/role_sprites.gd")
	_check(RS.role_for_slot(2) == "nav", "slot 2 plays the navigator")
	_check(RS.frames("qm", true).has_animation("walk_side"), "suit sheet has walk_side")

	var WD = load("res://game/dawn/world_data.gd")
	var all_ok := true
	for id in WD.rooms():
		for d in WD.doors(id):
			if WD.door_to(d["to"], id).is_empty() or not WD.inside_local(d["to"], WD.entry_point(d["to"], id)):
				all_ok = false
				print("    door problem: %s -> %s" % [id, d["to"]])
		if WD.doors(id).size() != WD.neighbours(id).size():
			all_ok = false
			print("    missing door in " + id)
		for s in WD.stations(id, []):
			if not WD.inside_local(id, s["pos"]):
				all_ok = false
				print("    station outside the floor: %s %s" % [id, s["id"]])
	_check(all_ok, "every door has a way back, every station is on the floor (37 rooms)")
	_check(WD.rooms().size() == 37, "37 rooms across Earth, Moon and Mars")
	_check(WD.next_hop("earth.crew", "earth.pad", {"earth.canopy": true}) == "earth.mc", "crew quarters to launch pad goes via mission control")
	_check(WD.next_hop("earth.mc", "earth.hydro", {"earth.hydro": true}) == "", "locked rooms are unreachable")
	_check(WD.room_at(WD.room_origin("moon.mine") + Vector2(10, 10)) == "moon.mine", "room_at finds the Moon's ice mine")
	_check(WD.clock_text(6 * 60 + 1440 * 2 + 5) == "DAY 3 · 06:05", "clock text")

	var Story = load("res://game/dawn/story.gd")
	var c1: Dictionary = Story.calc({"motor": "small", "uv": true, "cam": false, "chute": true, "radio": false})
	_check(c1["kg"] == 141 and c1["alt"] == 104 and c1["all"], "small motor + UV sensor + parachute reaches 104 km inside budget")
	var c2: Dictionary = Story.calc({"motor": "small", "uv": true, "cam": true, "chute": false, "radio": false})
	_check(not c2["ok"]["rec"], "no parachute and no radio = the data never comes back")

	var DZ = load("res://game/dawn/designers.gd")
	_check(DZ.shield_calc({"n": 6, "h": 0, "big": 0})["after"] < 60, "6 cheap shield satellites fail the solar storm")
	_check(DZ.shield_calc({"n": 4, "h": 4, "big": 1})["ok"] and DZ.shield_calc({"n": 4, "h": 4, "big": 1})["lost"] == 0, "4 hardened satellites with large panels hold 60%")
	var mp: Dictionary = DZ.moon_calc({"site": "rim", "solar": 1, "cable": 1, "rtg": 0, "bat": 1})
	_check(mp["ok"] and mp["cr"] == 75 and mp["kg"] == 85 and mp["survives"], "rim solar + cable + battery: 75 cr, 85 kg, survives the cable cut")
	_check(not DZ.moon_calc({"site": "floor", "solar": 0, "cable": 0, "rtg": 1, "bat": 1})["ok"], "one RTG on the crater floor is not enough")
	_check(DZ.mars_calc({"solar": 3, "bat": 0, "rtg": 0, "ins": 0})["days"] == 0, "all-solar greenhouse dies on storm day 1")
	_check(DZ.mars_calc({"solar": 2, "bat": 1, "rtg": 1, "ins": 1})["days"] == 3, "RTG + insulation + battery survives the 3-day storm")
	_check(DZ.du(0) == 92 and DZ.du(100) == 300, "ozone % maps to the real Dobson range")

	print("\n%d passed, %d failed" % [_passes, _fails])
	eng.free()
	quit(1 if _fails > 0 else 0)

func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("  PASS  " + label)
	else:
		_fails += 1
		print("  FAIL  " + label)
