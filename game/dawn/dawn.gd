extends Node2D
## Project Dawn: Earth, Moon and Mars, ported from the HTML demo (web/demo). Owner: Sufi (gameplay).
##
## START: game/dawn/title.tscn (F6) → PLAY SOLO / HOST A CREW / JOIN A CREW, pick a role, START MISSION.
## KEYS: WASD or arrows walk · E or Enter use · TAB switch crew member · F crew follow you ·
##       C CERES autopilot on/off · M world map · J mission details · F9/F10/F11 debug jump (solo only).
## Who controls which crew member lives in crew.gd; the world map and door trips in world_map.gd.
##
## The host owns the shared state S (story progress, suits, clock...). Everyone else asks the host
## with act(), the host runs story.do_effect() and sends S to everyone (_apply_state).
## Each device moves its own crew member(s); the host also moves the autopilot crew.

const InputSetup := preload("res://game/input_setup.gd")
const PlayerScene := preload("res://game/player/player.tscn")
const RoomCamera := preload("res://game/camera/room_camera.gd")
const RoleSprites := preload("res://game/player/role_sprites.gd")
const WD := preload("res://game/dawn/world_data.gd")
const RoomView := preload("res://game/dawn/room_view.gd")
const DawnUI := preload("res://game/dawn/dawn_ui.gd")
const Designers := preload("res://game/dawn/designers.gd")
const Crew := preload("res://game/dawn/crew.gd")
const WorldMap := preload("res://game/dawn/world_map.gd")
const STORY_PATH := "res://game/dawn/story.gd"
const LOBBY := "res://game/dawn/title.tscn"
const POSTERS_FILE := "res://data/posters.json"
const SAVE_FILE := "user://posters_found.json"

const ROLES := ["eng", "sci", "nav", "qm"]
const SPRITE_SCALE := 1.5
const GAME_MINUTES_PER_SECOND := 4.0
const INTERACT_RANGE := 18.0
const DOOR_LANE := 34.0          ## px in front of each door kept free of furniture collision
const UV_MAX := 12.0
const COLD_MAX := 30.0
const BATTERY_MAX := 100.0

const POSTER_THEMES := {
	"earth": {"bg": Color("#0F1B2D"), "acc": Color("#F2D16B"), "chip": Color("#7CC6E8"), "planet": Color("#2D6CB5"), "name": "EARTH · BUNKER 4"},
	"moon": {"bg": Color("#17191F"), "acc": Color("#F2D16B"), "chip": Color("#E8ECF2"), "planet": Color("#B9BEC8"), "name": "MOON · SHACKLETON OUTPOST"},
	"mars": {"bg": Color("#24130E"), "acc": Color("#F4A261"), "chip": Color("#F4A261"), "planet": Color("#C1592F"), "name": "MARS · JEZERO BASE"},
}

var S := {}                     ## shared state (host is the boss of it)
var crew := {}                  ## role -> player node (always all four); same dict as crew_ctl.members
var crew_ctl                    ## crew.gd: who controls whom, TAB switching, follow, autopilot
var world_map                   ## world_map.gd: M map + corridor walk between rooms
var camera: Camera2D
var ui: CanvasLayer
var story                       ## story.gd (null until that feature exists)
var posters: Array = []
var found := {}

var _views := {}
var _stations := {}
var _door_bars := {}            ## "room>to" -> CollisionShape2D that closes a locked door
var _hz := {}                   ## role -> {uv, cold, bat}
var _push_t := 0.0
var _clock_seen := {"v": 0.0, "at": 0}
var _dark: Sprite2D
var _shown_world := "earth"     ## world/scene this screen is showing (to spot changes in S)
var _shown_scene := "game"


func _ready() -> void:
	get_viewport().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	InputSetup.ensure()
	_load_posters()
	if ResourceLoader.exists(STORY_PATH):
		story = load(STORY_PATH).new()
		story.g = self
	S = fresh_state()
	crew_ctl = Crew.new()
	crew_ctl.name = "Crew"
	crew_ctl.g = self
	crew_ctl.me_role = str(Network.get_meta("my_role", "eng"))
	crew_ctl.autopilot = str(Network.get_meta("crew_mode", "autopilot")) == "autopilot"
	crew = crew_ctl.members
	add_child(crew_ctl)
	for id in WD.rooms():
		_build_room(id)
	camera = RoomCamera.new()
	add_child(camera)
	_build_darkness()
	ui = DawnUI.new()
	ui.game = self
	add_child(ui)
	world_map = WorldMap.new()
	world_map.name = "WorldMap"
	world_map.g = self
	add_child(world_map)
	if Network.is_online():
		Network.players_changed.connect(_rebuild_crew)
		Network.disconnected.connect(_back_to_lobby)
	_rebuild_crew()
	refresh_locks()
	if story and story.has_method("start"):
		story.start()
	else:
		ui.toast("Bunker 4. Walk around, read the posters, try the suit locker in Crew Quarters.", 5.0)


static func fresh_state() -> Dictionary:
	return {"world": "earth", "time": 360.0, "ozone": 8, "suits": {}, "step": 0, "ms": 0, "rs": 0,
		"opt": [], "pen": 0, "storm": {}, "hold": {}, "design": {"motor": "small", "uv": true, "cam": true, "chute": false, "radio": false},
		"sats": 4, "sats_chosen": false, "canopy": false, "hydro": false, "tasks": {}, "scene": "game", "cut": {}, "event": "", "result": {},
		"report": {}, "stars": {}, "shield": {}, "mpower": {}, "gpower": {}}


# ---------------------------------------------------------------- crew

func _rebuild_crew() -> void:
	crew_ctl.rebuild()
	for r in ROLES:
		if not _hz.has(r):
			_hz[r] = {"uv": UV_MAX, "cold": COLD_MAX, "bat": BATTERY_MAX}


## The crew member this screen controls (and the camera follows).
func my_crew():
	return crew_ctl.me()


## Crew members this computer moves (mine + the autopilot crew on the host / in solo).
func local_crew() -> Array:
	return crew_ctl.local()


## True if no person is playing this role right now (CERES autopilot or waiting for a TAB switch).
func is_ai(role: String) -> bool:
	return not crew_ctl.is_person(role)


func set_frozen(on: bool) -> void:
	for p in local_crew():
		p.can_move = not on
		if on:
			p.velocity = Vector2.ZERO


func place(p, room_id: String, at := Vector2.INF) -> void:
	p.position = WD.room_origin(room_id) + (WD.IB_CENTER if at == Vector2.INF else at)
	p.velocity = Vector2.ZERO
	if p == camera.target:
		camera.target = p


func _back_to_lobby(reason: String) -> void:
	Network.set_meta("last_message", "Disconnected: " + reason)
	get_tree().change_scene_to_file(LOBBY)


# ---------------------------------------------------------------- shared state

func is_host() -> bool:
	return not Network.is_online() or Network.is_host()


## Ask the host to do something. role = the crew member doing it.
func act(id: String, p: Dictionary, role: String) -> void:
	if is_host():
		_do_act(id, p, role)
	else:
		_req_act.rpc_id(1, id, p, role)


@rpc("any_peer", "reliable")
func _req_act(id: String, p: Dictionary, role: String) -> void:
	if not Network.is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if crew_ctl.owner_peer(role) != sender and crew_ctl.is_person(role):
		return                      # you may act for your own role or for a role nobody plays
	_do_act(id, p, role)


func _do_act(id: String, p: Dictionary, role: String) -> void:
	if id == "suit":
		if S["world"] != "earth":
			return
		S["suits"][role] = bool(p.get("on", false))
		if story and story.has_method("on_suit"):
			story.on_suit(role)
		commit()
	elif story:
		story.do_effect(id, p, role)
	else:
		commit()


## Host: send the state to everyone.
func commit() -> void:
	if Network.is_online():
		_apply_state.rpc(S)
	else:
		_apply_state(S)


@rpc("authority", "call_local", "reliable")
func _apply_state(s: Dictionary) -> void:
	var old_world := _shown_world
	var old_scene := _shown_scene
	S = s
	_shown_world = S["world"]
	_shown_scene = S["scene"]
	for r in crew:
		var p = crew[r]
		if not is_instance_valid(p):
			continue
		var want: bool = S["suits"].get(r, false)
		if p.suited != want:
			p.suited = want
		var rb: bool = S["world"] == "mars"
		if p.robot != rb:
			p.robot = rb
			p.max_speed = 60.0 if rb else 70.0
	if S["world"] != old_world:
		var arrive := WD.arrive(S["world"])
		for p in local_crew():
			place(p, arrive, WD.IB_CENTER + Vector2(-24 + ROLES.find(p.role) * 16, 10))
			_hz[p.role] = {"uv": UV_MAX, "cold": COLD_MAX, "bat": BATTERY_MAX}
	refresh_locks()
	if story and story.has_method("on_state"):
		story.on_state(old_scene, old_world)


## Host: show dialogue on every screen.
func say_all(lines: Array) -> void:
	if Network.is_online():
		_say.rpc(lines)
	else:
		_say(lines)


@rpc("authority", "call_local", "reliable")
func _say(lines: Array) -> void:
	ui.say(lines)


# ---------------------------------------------------------------- frame loop

func _process(delta: float) -> void:
	if is_host():
		if S["scene"] == "game":
			S["time"] += delta * GAME_MINUTES_PER_SECOND
		if story and story.has_method("host_tick"):
			story.host_tick(delta)
		if Network.is_online():
			_push_t -= delta
			if _push_t <= 0.0:
				_push_t = 1.0
				_apply_state.rpc(S)
	crew_ctl.tick(delta)
	_refresh_hud()
	var me = camera.target
	if is_instance_valid(me):
		var here := WD.room_at(me.position)
		if _views.has(here):
			_views[here].queue_redraw()
		_dark.visible = here == "moon.mine"
		if _dark.visible:
			_dark.global_position = me.global_position + Vector2(0, -14)


func _physics_process(delta: float) -> void:
	for p in local_crew():
		_check_doors(p)
		if not p.ai:
			_hazards(p, delta)


func _check_doors(p) -> void:
	if p == camera.target and world_map.busy():
		return
	var id := WD.room_at(p.position)
	if id == "":
		return
	var local: Vector2 = p.position - WD.room_origin(id)
	if WD.inside_local(id, local):
		return
	var best := {}
	var bd := 1e9
	for d in WD.doors(id):
		var dist: float = local.distance_to(d["pos"])
		if dist < bd:
			bd = dist
			best = d
	if best.is_empty() or bd > WD.DOOR_WIDTH or is_locked(best["to"]):
		p.position = WD.room_origin(id) + WD.snap_inside(id, local, 3.0)
		return
	var c := local - WD.IB_CENTER
	if c.length() < WD.wall_distance(id, c.angle()) + WD.EXIT_DEPTH:
		return
	var to: String = best["to"]
	if p != camera.target:
		place(p, to, WD.entry_point(to, id))       # crew I am not watching just step through
		return
	# my crew member: walk the corridor on the world map, then arrive in the next room
	p.can_move = false
	p.velocity = Vector2.ZERO
	p.position = WD.room_origin(id) + WD.snap_inside(id, local, 3.0)
	world_map.travel(id, to, p.role, func(): _arrive(p, id, to))


## Finish a door trip: put the crew member (and followers) inside the new room.
func _arrive(p, from: String, to: String) -> void:
	place(p, to, WD.entry_point(to, from))
	p.can_move = not ui.panel_open() and not world_map.showing
	if p != camera.target:
		return
	var r := WD.room(to)
	ui.toast(r["name"] + " · " + r["info"][0], 2.2)
	crew_ctl.on_leader_moved(to, WD.entry_point(to, from))
	if story and story.has_method("on_enter"):
		story.on_enter(p, to)


## UV on Earth's surface, cold and darkness in the Moon's ice mine, robot batteries on Mars.
func _hazards(p, delta: float) -> void:
	var id := WD.room_at(p.position)
	var h: Dictionary = _hz[p.role]
	var show_label := ""
	var show_frac := -1.0
	var w: String = S["world"]
	if w == "earth":
		var on: bool = id != "" and WD.room(id).get("surface", false) and uv_active()
		var safe: bool = p.suited or (id == "earth.canopy" and S["canopy"])
		if on and not safe:
			h["uv"] -= delta
			if h["uv"] <= 0.0:
				h["uv"] = UV_MAX
				place(p, "earth.med")
				_hazard_msg(p, "UV burns! Sent to the MED BAY. Wear a spacesuit on the surface.")
		else:
			h["uv"] = minf(UV_MAX, h["uv"] + delta * 3.0)
		if on and not safe:
			show_label = "UV"
			show_frac = h["uv"] / UV_MAX
	elif w == "moon":
		if id == "moon.mine":
			h["cold"] -= delta
			show_label = "COLD"
			show_frac = h["cold"] / COLD_MAX
			if h["cold"] <= 0.0:
				h["cold"] = COLD_MAX
				place(p, "moon.lc")
				_hazard_msg(p, "Too cold! CERES guides you back to Lunar Control. Crater work has to be fast.")
		else:
			h["cold"] = minf(COLD_MAX, h["cold"] + delta * 5.0)
	elif w == "mars":
		var dust: bool = S["storm"].get("kind", "") == "dust"
		if p.is_moving:
			h["bat"] -= delta * (2.4 if dust else 1.0)
		if id == "mars.hangar":
			h["bat"] = minf(BATTERY_MAX, h["bat"] + delta * 30.0)
		if h["bat"] <= 0.0:
			h["bat"] = 60.0
			place(p, "mars.hangar")
			_hazard_msg(p, "Battery flat! CERES tows your robot back to the Hangar.")
		show_label = "BATTERY"
		show_frac = h["bat"] / BATTERY_MAX
	if p == camera.target:
		ui.meter(show_label, show_frac)


func recharge(p) -> void:
	if is_instance_valid(p):
		_hz[p.role]["bat"] = BATTERY_MAX


func heal(p) -> void:
	if is_instance_valid(p):
		_hz[p.role]["uv"] = UV_MAX


func uv_active() -> bool:
	if story and story.has_method("uv_active"):
		return story.uv_active()
	return true


func _hazard_msg(p, text: String) -> void:
	if p == camera.target:
		ui.toast(text, 3.5)


# ---------------------------------------------------------------- holds and stations

## {id, need: {role: [room id, station id]}, secs} or {} when no hold is running.
func current_hold() -> Dictionary:
	if story and story.has_method("hold"):
		return story.hold()
	return {}


func station(room_id: String, sid: String) -> Dictionary:
	for s in _stations.get(room_id, []):
		if s["id"] == sid:
			return s
	return {}


func on_spot(role: String, room_id: String, sid: String) -> bool:
	var p = crew.get(role)
	if not is_instance_valid(p) or WD.room_at(p.position) != room_id:
		return false
	var s := station(room_id, sid)
	return not s.is_empty() and (p.position - WD.room_origin(room_id)).distance_to(s["pos"]) < WD.SEAT_RANGE


func station_near(p) -> Dictionary:
	var id := WD.room_at(p.position)
	if id == "":
		return {}
	var local: Vector2 = p.position - WD.room_origin(id)
	var best := {}
	var bd := INTERACT_RANGE
	for s in _stations[id]:
		var d: float = local.distance_to(s["pos"])
		if d < bd:
			bd = d
			best = s
	return best


## What pressing E here would do: {label, role, fn} or {}.
func station_action(p, s: Dictionary) -> Dictionary:
	var id := WD.room_at(p.position)
	var sid: String = s["id"]
	if sid.begins_with("poster"):
		var ps: Dictionary = s["poster"]
		return {"label": "READ POSTER" if found.has(int(ps["n"])) else "NEW POSTER! READ", "fn": func(): open_poster(ps)}
	if sid == "locker":
		var on: bool = not p.suited
		return {"label": "PUT ON SPACESUIT" if on else "TAKE OFF SPACESUIT", "fn": func():
			act("suit", {"on": on}, p.role)
			ui.toast("Suited up. The suit blocks UV on the surface." if on else "Suit back in the locker.", 2.5)}
	if s.has("role"):
		return {"label": "STAND HERE", "fn": func():
			var h := current_hold()
			if h.get("need", {}).has(s["role"]):
				var miss := hold_missing()
				ui.toast(("Hold position. Waiting for: " + ", ".join(miss.map(func(x): return RoleSprites.NAMES[x]))) if not miss.is_empty() else "Everyone in place. Hold steady…", 2.4)
			else:
				ui.toast("%s spot. Nothing to do here right now." % RoleSprites.NAMES[s["role"]])}
	if story:
		var a: Dictionary = story.station_action(p, id, sid)
		if not a.is_empty():
			return a
	var r := WD.room(id)
	return {"label": "LOOK AROUND", "fn": func(): ui.info(r["name"], r["info"][0], r["info"][1] if r["info"].size() > 1 else "")}


func hold_missing() -> Array:
	var h := current_hold()
	var out := []
	for r in h.get("need", {}):
		if not on_spot(r, h["need"][r][0], h["need"][r][1]):
			out.append(r)
	return out


func _on_interact(p) -> void:
	if ui.dialogue_open():
		ui.advance()
		return
	if ui.panel_open():
		return
	var s := station_near(p)
	if s.is_empty():
		return
	var a := station_action(p, s)
	if a.is_empty():
		return
	var need: String = a.get("role", "")
	var rule: Dictionary = crew_ctl.may_do(p, need)
	if rule.has("msg"):
		ui.toast(rule["msg"], 2.0 if rule["ok"] else 3.5)
	if not rule["ok"]:
		return
	_acting_role = need if need != "" else p.role
	a["fn"].call()


var _acting_role := "eng"
## Role of whoever pressed E last (story code uses it for act()).
func acting_role() -> String:
	return _acting_role


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.physical_keycode
	if ui.dialogue_open() and (k == KEY_SPACE or k == KEY_ENTER):
		ui.advance()
		get_viewport().set_input_as_handled()
	elif k == KEY_TAB and not ui.panel_open() and not ui.dialogue_open():
		crew_ctl.cycle()                       # switch to the next crew member (like the HTML)
		get_viewport().set_input_as_handled()
	elif k in [KEY_1, KEY_2, KEY_3, KEY_4] and not ui.panel_open() and not ui.dialogue_open():
		crew_ctl.switch_to(ROLES[k - KEY_1])   # 1 ENG · 2 SCI · 3 NAV · 4 QM
		get_viewport().set_input_as_handled()
	elif k == KEY_F and not ui.panel_open():
		crew_ctl.toggle_follow()
	elif k == KEY_C and not ui.panel_open():
		crew_ctl.toggle_autopilot()
	elif k == KEY_J:
		open_mission_panel()
	elif k == KEY_M and not ui.panel_open() and not ui.dialogue_open():
		world_map.toggle()
	elif k == KEY_ESCAPE and ui.panel_open():
		ui.close_panel()
	elif not Network.is_online() and k in [KEY_F9, KEY_F10, KEY_F11]:
		S["world"] = {KEY_F9: "earth", KEY_F10: "moon", KEY_F11: "mars"}[k]
		commit()
		ui.toast("Debug: jumped to " + S["world"].to_upper())


# ---------------------------------------------------------------- locks

func is_locked(id: String) -> bool:
	var r := WD.room(id)
	if not r.has("unlock"):
		return false
	match r["unlock"]:
		"launched": return S["step"] < 4
		"hydro": return not S["hydro"]
		"fuel_made": return S["ms"] < 5
		"panels_clean": return S["rs"] < 2
	return true


func locked_map() -> Dictionary:
	var m := {}
	for id in WD.rooms():
		if is_locked(id):
			m[id] = true
	return m


func refresh_locks() -> void:
	for key in _door_bars:
		var to: String = key.get_slice(">", 1)
		_door_bars[key].set_deferred("disabled", not is_locked(to))


# ---------------------------------------------------------------- objective, clock, HUD

func objective() -> Dictionary:
	if story:
		return story.objective()
	return {"room": "", "text": "Explore. Story missions arrive with the story update."}


func game_minutes() -> float:
	var t: float = S["time"]
	if t != _clock_seen["v"]:
		_clock_seen = {"v": t, "at": Time.get_ticks_msec()}
	if not is_host() and S["scene"] == "game":
		t += minf(2.0, (Time.get_ticks_msec() - _clock_seen["at"]) / 1000.0) * GAME_MINUTES_PER_SECOND
	return t


func act_number() -> int:
	if S["world"] == "earth":
		return 1 if S["step"] < 5 else (2 if S["step"] == 5 else 5)
	if S["world"] == "moon":
		return 2 if S["ms"] < 5 else (3 if S["ms"] < 7 else 4)
	return 4 if S["rs"] < 4 else 5


func _refresh_hud() -> void:
	ui.top.text = "ACT %d · OZONE %d DU   ·   %s" % [act_number(), Designers.du(S["ozone"]), WD.clock_text(game_minutes())]
	var ob := objective()
	ui.obj.text = "> " + ob["text"] + "   [details: J]"
	ui.obj.add_theme_color_override("font_color", WD.PAL["rose"] if ob.get("alert", false) else WD.PAL["white"])
	var h: Dictionary = S["hold"]
	ui.hold_bar.visible = not h.is_empty()
	if not h.is_empty():
		ui.hold_bar.value = h.get("p", 0.0)
	var where := {}
	var online := []
	for r in ROLES:
		where[r] = WD.room(WD.room_at(crew[r].position)).get("name", "?").replace("\n", " ") if is_instance_valid(crew.get(r)) else "?"
		if crew_ctl.is_person(r) and r != crew_ctl.me_role:
			online.append(r)
	ui.update_crewbar(crew_ctl.me_role, online, where, crew_ctl.autopilot)
	var me = camera.target
	if is_instance_valid(me):
		var id := WD.room_at(me.position)
		ui.room_label.text = WD.room(id).get("name", "") if id != "" else ""
		var s := station_near(me)
		var a := {} if s.is_empty() or ui.panel_open() else station_action(me, s)
		if a.is_empty():
			ui.hint.text = ""
		else:
			var key := OS.get_keycode_string(InputSetup.BINDINGS[me.player_index]["interact"])
			var who: String = (" · " + RoleSprites.NAMES[a["role"]]) if a.get("role", "") != "" else ""
			ui.hint.text = "[%s] %s%s" % [key, a["label"], who]


func open_mission_panel() -> void:
	if ui.panel_open():
		ui.close_panel()
		return
	var box: VBoxContainer = ui.panel(Color("#262b44"), WD.PAL["amber"], 820, 50)
	var ob := objective()
	var w: String = S["world"]
	var place_name: String = {"earth": "EARTH · BUNKER 4", "moon": "MOON · SHACKLETON OUTPOST", "mars": "MARS · JEZERO BASE"}[w]
	var bb := "[b][color=#feae34]MISSION DETAILS[/color][/b]\n"
	bb += "[color=#feae34]THE BIG GOAL[/color]\nHelp the ozone layer heal itself, and keep everyone alive until it does.\n"
	bb += "[b]OZONE %d%%[/b]  [color=#8b9bb4](healed at 100%%)[/color]\n\n" % S["ozone"]
	bb += "[color=#feae34]ACT %d · %s[/color]\n%s\n" % [act_number(), place_name, ob["text"]]
	if ob.get("room", "") != "":
		bb += "[color=#8b9bb4]Where:[/color] [b]%s[/b]  [color=#8b9bb4](follow the blinking yellow door)[/color]\n" % WD.room(ob["room"])["name"]
	bb += "\n[color=#feae34]WHO DOES WHAT[/color]\n"
	var work: Array = story.work_list() if story and story.has_method("work_list") else []
	for r in ROLES:
		var p = crew.get(r)
		var here := WD.room_at(p.position) if is_instance_valid(p) else ""
		var jobs := work.filter(func(j): return j["role"] == r or j["role"] == "")
		var job_txt := "; ".join(jobs.map(func(j): return "%s · %s" % [j["what"], WD.room(j["room"]).get("name", "")])) if not jobs.is_empty() else "Nothing waiting. Help the others."
		var tag := " (you)" if p == camera.target else ((" (autopilot)" if crew_ctl.autopilot else " (waiting)") if is_ai(r) else " (online player)")
		bb += "[color=#%s][b]%s%s[/b][/color] · in %s · %s\n" % [RoleSprites.TAGS[r].to_html(false), RoleSprites.NAMES[r], tag, WD.room(here).get("name", "?"), job_txt]
	bb += "\n[color=#feae34]PROGRESS[/color]\n%s · Posters found: %d/21 · Optional missions: %d\n" % [WD.clock_text(game_minutes()), found.size(), S["opt"].size()]
	bb += "[color=#8b9bb4]J or Esc closes this panel. TAB switch crew · F crew follow you · C CERES autopilot (%s)[/color]" % ("on" if crew_ctl.autopilot else "off")
	ui.rich(box, bb, 16)
	ui.button(box, "CLOSE", ui.close_panel)


# ---------------------------------------------------------------- posters

func _load_posters() -> void:
	var f := FileAccess.open(POSTERS_FILE, FileAccess.READ)
	if f:
		posters = JSON.parse_string(f.get_as_text())
	for i in posters.size():
		posters[i]["n"] = i + 1
	var s := FileAccess.open(SAVE_FILE, FileAccess.READ)
	if s:
		var list = JSON.parse_string(s.get_as_text())
		if list is Array:
			for n in list:
				found[int(n)] = true


func open_poster(ps: Dictionary) -> void:
	var n := int(ps["n"])
	var first := not found.has(n)
	found[n] = true
	var s := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if s:
		s.store_string(JSON.stringify(found.keys()))
	var th: Dictionary = POSTER_THEMES[ps["world"]]
	var box: VBoxContainer = ui.panel(th["bg"], th["acc"], 640)
	ui.rich(box, "[color=#%s][b]%s[/b][/color]      [color=#%s]FUN FACT %d/21[/color]" % [th["chip"].to_html(false), String(ps["category"]).to_upper(), th["acc"].to_html(false), n], 16)
	ui.rich(box, "[color=#%s][b]%s[/b][/color]" % [th["acc"].to_html(false), ps["hook"]], 44)
	ui.rich(box, "[color=#e8ecf2]%s[/color]" % ps["body"], 20)
	ui.rich(box, "[color=#8b9bb4]%s · Source: %s[/color]" % [th["name"], ps["source"]], 14)
	ui.button(box, ("FOUND %d/21" % found.size()) if first else "OK", ui.close_panel).grab_focus.call_deferred()


# ---------------------------------------------------------------- building the world

func _build_room(id: String) -> void:
	var r := WD.room(id)
	var origin := WD.room_origin(id)
	var view := RoomView.new()
	view.id = id
	view.game = self
	view.position = origin
	add_child(view)
	_views[id] = view
	_stations[id] = WD.stations(id, posters)
	view.stations = _stations[id]
	view.doors = WD.doors(id)
	var pts := WD.outline(id, 96)
	var segs := PackedVector2Array()
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var gap := false
		for d in view.doors:
			if Geometry2D.get_closest_point_to_segment(d["pos"], a, b).distance_to(d["pos"]) < WD.DOOR_WIDTH / 2.0:
				gap = true
		if not gap:
			segs.append(a)
			segs.append(b)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.position = origin
	var cs := CollisionShape2D.new()
	var shape := ConcavePolygonShape2D.new()
	shape.segments = segs
	cs.shape = shape
	body.add_child(cs)
	for d in view.doors:          # a bar across every door, switched on while the room behind is locked
		var n: Vector2 = Vector2(-d["dir"].y, d["dir"].x)
		var bar := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = d["pos"] + n * WD.DOOR_WIDTH * 0.6
		seg.b = d["pos"] - n * WD.DOOR_WIDTH * 0.6
		bar.shape = seg
		body.add_child(bar)
		_door_bars[id + ">" + d["to"]] = bar
	for rect in _solid_rects(id):   # furniture and consoles you walk around (same as the HTML)
		var box := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = rect.size
		box.shape = rs
		box.position = rect.get_center()
		body.add_child(box)
	add_child(body)
	for d in view.doors:
		var to: String = d["to"]
		var lp: Vector2 = d["pos"] - d["dir"] * 10.0 + Vector2(0, -8 if d["dir"].y >= -0.5 else 10)
		lp.x = clampf(lp.x, 40, 280)
		var lab := _world_label(view, "> " + WD.room(to)["name"], lp, WD.PAL["grey"], 18)
		if WD.room(to).has("unlock"):
			lab.set_meta("lock_for", to)
	for s in _stations[id]:
		if s.has("role"):
			_world_label(view, RoleSprites.NAMES[s["role"]], s["pos"] + Vector2(0, 8), RoleSprites.TAGS[s["role"]], 14)


## Furniture from the HTML picture + the screen part of every console (not seats, posters, the locker).
## Anything standing in front of a door is left walkable, so every door can always be reached
## (e.g. the Mission Control console right below the Airlock door).
func _solid_rects(id: String) -> Array:
	var out: Array = []
	var all: Array = WD.solids(id)
	for s in _stations[id]:
		if s.get("seat", false) or s["id"].begins_with("poster") or s["id"] == "locker":
			continue
		all.append(Rect2(s["pos"].x - 11, s["pos"].y - 24, 22, 15))
	for rect in all:
		var blocks_door := false
		for d in WD.doors(id):
			var lane := Rect2(d["pos"], Vector2.ZERO).expand(d["pos"] - d["dir"] * DOOR_LANE).grow(WD.DOOR_WIDTH / 2.0)
			blocks_door = blocks_door or lane.intersects(rect)
		if not blocks_door:
			out.append(rect)
	return out


func _world_label(parent: Node, text: String, center: Vector2, color: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.scale = Vector2(0.25, 0.25)
	l.size = Vector2(1200, size + 12)
	l.position = center - Vector2(150, (size + 12) / 8.0)
	l.z_index = 5
	parent.add_child(l)
	return l


## A dark mask with a lamp-sized hole, used in the Moon's ice mine.
func _build_darkness() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.02, 0.02, 0.04, 0.95))
	g.add_point(0.045, Color(0, 0, 0, 0))
	g.add_point(0.085, Color(0.02, 0.02, 0.04, 0.95))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	_dark = Sprite2D.new()
	_dark.texture = tex
	_dark.scale = Vector2(5, 5)
	_dark.z_index = 20
	_dark.visible = false
	add_child(_dark)
