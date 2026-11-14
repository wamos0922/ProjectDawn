extends Node
## The four crew members: who controls each one, switching (TAB), following (F) and CERES autopilot (C).
## Owner: Sufi (gameplay). Lives as a child of dawn.gd ("Crew"); dawn.gd keeps `crew` = members.
##
## RULES
##   Solo:   all four crew members run on this computer. You control ONE of them (`me_role`).
##           TAB switches to the next one, or click a square in the crew bar (top right).
##   Online: you control the role you picked in the lobby. Roles nobody picked run on the host,
##           and the host may TAB to them too.
##   Crew you are not controlling:
##     follow ON  (F) → they walk behind you and come through doors with you.
##     autopilot ON (C, default) → CERES moves them onto the spots a "hold" needs and into
##                                 shelters during storms. OFF → they wait until you switch to them.

const RoleSprites := preload("res://game/player/role_sprites.gd")
const WD := preload("res://game/dawn/world_data.gd")
const ROLES := ["eng", "sci", "nav", "qm"]
const FOLLOW_GAP := 18.0          ## follow distance, pixels
const AUTOPILOT_DELAY := 2.0      ## seconds before CERES moves someone to their spot
const STORM_RESCUE_DELAY := 8.0   ## even with autopilot off, CERES rescues crew in a storm

var g                             ## dawn.gd
var members := {}                 ## role -> player node (always all four)
var me_role := "eng"              ## the crew member this screen controls
var follow := false
var autopilot := true
var _waiting := {}                ## role -> seconds since autopilot wanted them somewhere


# ---------------------------------------------------------------- who plays what

## Roles played by a person (online: every connected player's pick; solo: just me_role).
func human_roles() -> Dictionary:
	var out := {}
	if Network.is_online():
		for id in Network.players:
			var r: String = me_role if id == Network.my_id() else RoleSprites.role_for_slot(Network.players[id]["slot"])
			out[r] = id
	else:
		out[me_role] = 1
	return out


## Peer that moves this role: the player who picked it, or the host for everyone else.
func owner_peer(role: String) -> int:
	return human_roles().get(role, 1) if Network.is_online() else 1


func me():
	return members.get(me_role)


## Crew this computer moves (my own + all autopilot crew if I am the host or solo).
func local() -> Array:
	var out := []
	for r in ROLES:
		var p = members.get(r)
		if is_instance_valid(p) and p.is_multiplayer_authority():
			out.append(p)
	return out


## True if this computer could switch to the role (solo: always; online: mine or unclaimed on the host).
func can_switch_to(role: String) -> bool:
	var p = members.get(role)
	if not is_instance_valid(p) or not p.is_multiplayer_authority():
		return false
	var humans := human_roles()
	return not Network.is_online() or not humans.has(role) or humans[role] == Network.my_id()


func is_person(role: String) -> bool:
	return human_roles().has(role)


# ---------------------------------------------------------------- building

func rebuild() -> void:
	if Network.is_online():
		for id in Network.players:
			if id == Network.my_id():
				me_role = RoleSprites.role_for_slot(Network.players[id]["slot"])
	var keep := {}
	for r in members:
		if is_instance_valid(members[r]):
			keep[r] = members[r].position
			g.remove_child(members[r])
			members[r].free()
	members.clear()
	var arrive := WD.arrive(g.S["world"])
	for i in ROLES.size():
		var r: String = ROLES[i]
		var p = g.PlayerScene.instantiate()
		p.name = "C_" + r
		p.role = r
		p.sprite_scale = g.SPRITE_SCALE
		p.color_index = i
		p.player_index = 0                    # everyone uses WASD / arrows + E on their own screen
		p.ai = r != me_role
		p.suited = g.S["suits"].get(r, false)
		p.max_speed = 70.0
		p.set_multiplayer_authority(owner_peer(r))
		p.position = keep.get(r, WD.room_origin(arrive) + WD.IB_CENTER + Vector2(-24 + i * 16, 10))
		p.interact_requested.connect(g._on_interact)
		g.add_child(p)
		members[r] = p
	g.camera.target = me()


# ---------------------------------------------------------------- switching

func switch_to(role: String) -> void:
	if role == me_role:
		return
	if not can_switch_to(role):
		g.ui.toast("%s is played by someone else." % RoleSprites.NAMES[role])
		return
	var old = me()
	if is_instance_valid(old):
		old.ai = true
		old.ai_input = Vector2.ZERO
	me_role = role
	var p = me()
	p.ai = false
	g.camera.target = p
	g.ui.toast("You now control the %s" % RoleSprites.NAMES[role], 1.6)


func cycle() -> void:
	var options := ROLES.filter(func(r): return can_switch_to(r))
	if options.size() < 2:
		g.ui.toast("Every role is played by someone online.")
		return
	switch_to(options[(options.find(me_role) + 1) % options.size()])


func toggle_follow() -> void:
	follow = not follow
	if follow and is_instance_valid(me()):
		on_leader_moved(WD.room_at(me().position), me().position - WD.room_origin(WD.room_at(me().position)))
	g.ui.toast("Your other crew now follow you." if follow else "Crew stop following. They stay where they are.", 1.8)


func toggle_autopilot() -> void:
	autopilot = not autopilot
	g.ui.toast("CERES autopilot ON: crew walk to their spots for you" if autopilot else "CERES autopilot OFF: press TAB to move each crew member yourself", 2.6)


# ---------------------------------------------------------------- every frame (on the computer that moves them)

func tick(delta: float) -> void:
	var leader = me()
	if not is_instance_valid(leader):
		return
	var here := WD.room_at(leader.position)
	var h: Dictionary = g.current_hold()
	for p in local():
		if p == leader:
			continue
		p.ai_input = Vector2.ZERO
		var r: String = p.role
		var target := _autopilot_target(r, h)
		if not target.is_empty():
			_waiting[r] = _waiting.get(r, 0.0) + delta
			if _waiting[r] >= target["delay"]:
				_waiting[r] = 0.0
				g.place(p, target["room"], target["pos"])
			continue
		_waiting.erase(r)
		if follow and WD.room_at(p.position) == here:
			var to_me: Vector2 = leader.position - p.position
			if to_me.length() > FOLLOW_GAP:
				p.ai_input = to_me.normalized()


## Where CERES wants this crew member right now: {room, pos, delay} or {}.
func _autopilot_target(r: String, h: Dictionary) -> Dictionary:
	if h.get("need", {}).has(r):
		var need: Array = h["need"][r]
		if autopilot and not g.on_spot(r, need[0], need[1]):
			return {"room": need[0], "pos": g.station(need[0], need[1])["pos"], "delay": AUTOPILOT_DELAY}
		return {}
	var shelter: String = g.story.npc_room(r) if g.story and g.story.has_method("npc_room") else ""
	if shelter != "" and WD.room_at(members[r].position) != shelter:
		return {"room": shelter, "pos": WD.IB_CENTER + Vector2(-24 + ROLES.find(r) * 16, 12), "delay": AUTOPILOT_DELAY if autopilot else STORM_RESCUE_DELAY}
	return {}


## Called when the leader walks into another room: followers come along.
func on_leader_moved(room_id: String, entry: Vector2) -> void:
	if not follow:
		return
	var i := 0
	for p in local():
		if p == me() or WD.room_at(p.position) == room_id:
			continue
		i += 1
		g.place(p, room_id, WD.snap_inside(room_id, entry + Vector2(-14 + (i % 3) * 14, 8 + (i / 3) * 8), 6.0))


## Can `p` do a job that needs `role`? {ok, msg}
func may_do(p, role: String) -> Dictionary:
	if role == "" or role == p.role:
		return {"ok": true}
	var name: String = RoleSprites.NAMES[role]
	if can_switch_to(role):
		return {"ok": false, "msg": "Only the %s can do this. Press TAB to switch to them, or F so the crew follows you." % name}
	if not is_person(role):
		return {"ok": true, "msg": "Covering for the %s (CERES autopilot)." % name}
	return {"ok": false, "msg": "Only the %s can do this. Ask your teammate to come here." % name}
