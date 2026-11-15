extends Control
## Title screen and crew lobby, like the HTML demo: PLAY SOLO · HOST A CREW · JOIN A CREW.
## Owner: Sufi (gameplay). Uses the Network autoload (game/net/network.gd).
##
## SOLO: pick who you start as and whether CERES autopilot moves the others (TAB switches in game).
## HOST: this laptop becomes the server. Friends on the same Wi-Fi type its ROOM CODE (the IP address).
## JOIN: type the host's CREW CODE. The host presses START MISSION when everyone is in.
## HOST and JOIN: click a role card to pick that role (roles nobody picks = CERES autopilot).
## Passed to the game as Network meta: "my_role" (solo) and "crew_mode" ("autopilot" or "wait").
## Make this the main scene to start the game here (Project Settings → Run → Main Scene).

const Pixel := preload("res://game/dawn/pixel.gd")
const RoleSprites := preload("res://game/player/role_sprites.gd")
const GAME := "res://game/dawn/dawn.tscn"
const C := DawnTheme.C
const ROLES := ["eng", "sci", "nav", "qm"]
const ROLE_DESC := {"eng": "Builds · drills · heaters", "sci": "Instruments · ice · crops", "nav": "Launches · fuel · telescope", "qm": "Power · cables · cargo"}

var _ui: Control
var _mode := ""
var _my_role := "eng"            ## solo: who you start as
var _crew_mode := "autopilot"     ## solo: "autopilot" (CERES moves the others) or "wait" (you TAB to each)
var _status: Label
var _slots: VBoxContainer
var _name: LineEdit
var _addr: LineEdit


func _ready() -> void:
	Sound.music("title")
	size = Vector2(1280, 720)
	theme = DawnTheme.get_theme()
	get_viewport().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var bg := Pixel.new()
	bg.painter = func(pc, t, dt):
		pc.dusk_sky(t)
		pc.stars(t)
		pc.crack(t)
		pc.landscape(t)
		pc.dust(t, dt)
	add_child(bg)
	Network.players_changed.connect(_refresh)
	Network.joined.connect(func():
		if _status: _status.text = "Connected. Waiting for the host to start…" if not Network.is_host() else "Hosting. Friends can join now."
		_refresh())
	Network.join_failed.connect(func(r): if _status: _status.text = "Join failed: " + r)
	Network.disconnected.connect(func(r):
		Network.set_meta("last_message", r)
		_title())
	_title()


func _clear() -> void:
	if _ui:
		_ui.queue_free()
	_ui = Control.new()
	_ui.size = Vector2(1280, 720)
	add_child(_ui)
	_status = null
	_slots = null


func _panel(pos: Vector2, w: float, h := 0.0) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", DawnTheme.box(Color(0.15, 0.17, 0.27, 0.95), C["amber"], 4, Color(0, 0, 0, 0), 0, Vector4(20, 20, 20, 20)))
	p.position = pos
	p.custom_minimum_size = Vector2(w, h)
	_ui.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	p.add_child(v)
	return v


func _h(parent: Node, text: String, size := 20, color := Color("#fee761")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", DawnTheme.title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _p(parent: Node, text: String, size := 20, color := Color("#c0cbdc")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _btn(parent: Node, text: String, fn: Callable, ghost := false) -> Button:
	var b := Button.new()
	b.text = text
	if ghost:
		b.theme_type_variation = "GhostButton"
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(fn)
	parent.add_child(b)
	return b


# ---------------------------------------------------------------- title

func _title() -> void:
	Network.leave()
	_mode = ""
	_clear()
	var ban := PanelContainer.new()
	ban.add_theme_stylebox_override("panel", DawnTheme.box(Color(0.094, 0.078, 0.145, 0.82), C["amber"], 4, Color(0, 0, 0, 0), 0, Vector4(12, 12, 12, 16)))
	ban.position = Vector2(24, 20)
	ban.custom_minimum_size = Vector2(1232, 0)
	_ui.add_child(ban)
	var v := VBoxContainer.new()
	ban.add_child(v)
	var h := _h(v, "PROJECT DAWN", 44)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_color_override("font_shadow_color", Color("#f77622"))
	h.add_theme_constant_override("shadow_offset_x", 4)
	h.add_theme_constant_override("shadow_offset_y", 4)
	var s := _p(v, "Design real space missions. Heal the sky. Bring humanity home.", 24, C["sand"])
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var imp := _p(v, "For students aged 12–18: learn how real space missions balance mass, power and budget, and why the ozone layer matters. Play as a team, like a real mission crew.", 18, C["cyan"])
	imp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var m := VBoxContainer.new()
	m.position = Vector2(400, 300)
	m.custom_minimum_size = Vector2(480, 0)
	m.add_theme_constant_override("separation", 18)
	_ui.add_child(m)
	var solo := _btn(m, "PLAY SOLO  ▸▸", _solo)
	_btn(m, "HOST A CREW  ▸▸", _host_screen, true)
	_btn(m, "JOIN A CREW  ▸▸", _join_screen, true)
	_btn(m, "CREDITS & NASA DATA", _credits, true).custom_minimum_size = Vector2(0, 44)
	solo.grab_focus.call_deferred()
	var msg: String = Network.get_meta("last_message", "")
	if msg != "":
		var l := _p(m, msg, 18, Color("#f6757a"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Network.set_meta("last_message", "")
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", DawnTheme.box(Color(0.094, 0.078, 0.145, 0.88), C["slate"], 4, Color(0, 0, 0, 0), 0, Vector4(12, 7, 12, 7)))
	chip.position = Vector2(32, 662)
	var cl := Label.new()
	cl.text = "CO-OP · 1–4 PLAYERS · EARTH · MOON"
	cl.add_theme_font_override("font", DawnTheme.title_font())
	cl.add_theme_font_size_override("font_size", 12)
	cl.add_theme_color_override("font_color", C["sand"])
	chip.add_child(cl)
	_ui.add_child(chip)


# ---------------------------------------------------------------- credits

func _credits() -> void:
	_clear()
	var v := _panel(Vector2(120, 30), 1040, 660)
	_h(v, "CREDITS & NASA DATA", 20)
	var N: Dictionary = preload("res://game/dawn/designers.gd").NASA
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.add_theme_font_size_override("normal_font_size", 19)
	t.text = ("[color=#feae34]TEAM BIMA · NASA SPACE APPS 2026[/color]\nGame design, story, art and code by the Project Dawn team.\n\n" +
		"[color=#feae34]NASA DATA THAT DRIVES THE GAME[/color] (full list: docs/SOURCES.md)\n" +
		"• Ozone: healthy %d DU, hole below %d DU, record low %d DU (%s). NASA Ozone Watch\n" % [N["ozone"]["normal"], N["ozone"]["hole"], N["ozone"]["low"], N["ozone"]["low_when"]] +
		"• Solar storm and satellites: %s. NASA Science\n" % N["storm"]["name"] +
		"• Lunar south pole: Shackleton rim sunlit %s%% of the time, crater floors near %d K. LRO LOLA and Diviner\n" % [str(N["moon"]["rim"]), N["moon"]["cold"]] +
		"• RTG power: about %d W, %d kg. NASA MMRTG fact sheet\n\n" % [N["rtg"]["w"], N["rtg"]["kg"]] +
		"[color=#feae34]FONTS[/color]\nPress Start 2P and Pixelify Sans (SIL Open Font License, Google Fonts).\n\n" +
		"[color=#feae34]AI TOOLS USED[/color]\nClaude (Anthropic) and Codex helped write code, pixel art and text. The team chose the design, checked the facts and tested the game.")
	v.add_child(t)
	_btn(v, "◂ BACK", _title, true).grab_focus.call_deferred()


# ---------------------------------------------------------------- solo

func _solo() -> void:
	_mode = "solo"
	_my_role = str(Network.get_meta("my_role", "eng"))
	_crew_mode = str(Network.get_meta("crew_mode", "autopilot"))
	_clear()
	var L := _panel(Vector2(32, 32), 720, 656)
	_h(L, "YOUR CREW", 18)
	_p(L, "You play all four. Pick who you start as; press TAB in the game to switch and F to have the others follow you.", 20)
	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override("separation", 10)
	L.add_child(_slots)
	var R := _panel(Vector2(784, 32), 464, 656)
	_h(R, "SOLO CREW", 18)
	_h(R, "THE OTHER THREE", 11, C["grey"])
	var modes := VBoxContainer.new()
	modes.add_theme_constant_override("separation", 10)
	R.add_child(modes)
	_mode_button(modes, "autopilot", "CERES AUTOPILOT", "CERES walks them to their spots and shelters.")
	_mode_button(modes, "wait", "I MOVE EVERYONE", "They wait. Press TAB to take over each one.")
	_p(R, "Change it in the game with C. Keys: WASD or arrows to walk, E to use.", 17, C["grey"])
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	R.add_child(sp)
	var go := _btn(R, "START MISSION  ▸▸", func():
		Network.leave()
		Network.set_meta("my_role", _my_role)
		Network.set_meta("crew_mode", _crew_mode)
		get_tree().change_scene_to_file(GAME))
	_btn(R, "◂ BACK", _title, true)
	go.grab_focus.call_deferred()
	_refresh()


func _mode_button(parent: Node, mode: String, label: String, note: String) -> void:
	var b := _btn(parent, ("● " if _crew_mode == mode else "○ ") + label, func():
		_crew_mode = mode
		for c in parent.get_children():
			var on: bool = c.get_meta("mode") == mode
			c.text = ("● " if on else "○ ") + c.get_meta("label")
			c.theme_type_variation = "" if on else "GhostButton", _crew_mode != mode)
	b.set_meta("mode", mode)
	b.set_meta("label", label)
	b.tooltip_text = note
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT


# ---------------------------------------------------------------- host / join

func _name_field(parent: Node) -> void:
	_h(parent, "YOUR NAME", 11, C["grey"])
	_name = LineEdit.new()
	_name.text = Network.get_meta("my_name", "PLAYER")
	_name.max_length = 12
	parent.add_child(_name)

func _host_screen() -> void:
	_mode = "host"
	_clear()
	var L := _panel(Vector2(32, 32), 720, 656)
	_h(L, "CREW LOBBY", 18)
	_p(L, "Pick a role. Roles nobody picks are run by CERES autopilot; the host can switch to them with TAB.", 20)
	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override("separation", 10)
	L.add_child(_slots)
	var R := _panel(Vector2(784, 32), 464, 656)
	_h(R, "HOST A CREW", 18)
	_name_field(R)
		_h(R, "ROOM CODE", 11, C["grey"])
	var code := _h(R, "—", 24, C["white"])
	code.name = "Code"
	var how := _p(R, "Press OPEN THE CREW to get a room code, then tell your friends the code.", 18)
	_status = _p(R, "", 18, C["cyan"])
	var start := _btn(R, "OPEN THE CREW  ▸▸", func(): pass)
	Network.joined.connect(func():
		if is_instance_valid(code) and Network.is_host():
			code.text = Network.room_code
			how.text = "Friends open the game, press JOIN A CREW and type this code."
			start.text = "START MISSION  ▸▸")
	start.pressed.connect(func():
		if Network.is_host():
			Network.set_meta("crew_mode", "autopilot")
			Network.start_game(GAME)
			return
		if Network.multiplayer.multiplayer_peer is Network.RelayPeer:
			return
		Network.set_meta("my_name", _name.text)
		var err: Error = Network.host(_name.text)
		_status.text = "Opening the crew…" if err == OK else "Could not go online: " + error_string(err))
	_btn(R, "◂ BACK", _title, true)
	start.grab_focus.call_deferred()
	_refresh()


func _join_screen() -> void:
	_mode = "join"
	_clear()
	var L := _panel(Vector2(32, 32), 720, 656)
	_h(L, "CREW LOBBY", 18)
	_p(L, "Pick a role. Roles nobody picks are run by CERES autopilot; the host can switch to them with TAB.", 20)
	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override("separation", 10)
	L.add_child(_slots)
	var R := _panel(Vector2(784, 32), 464, 656)
	_h(R, "JOIN A CREW", 18)
	_p(R, "Type the CREW CODE shown on the host laptop.", 20)
	_name_field(R)
	_h(R, "CREW CODE", 11, C["grey"])
	_addr = LineEdit.new()
	_addr.text = Network.get_meta("last_code", "")
	_addr.placeholder_text = "K7QX"
	_addr.max_length = 4
	R.add_child(_addr)
	_status = _p(R, "", 18, C["cyan"])
	var go := _btn(R, "JOIN  ▸▸", func():
		var code := _addr.text.strip_edges()
		if code == "":
			_status.text = "Type the host's crew code first."
			return
		Network.set_meta("my_name", _name.text)
		Network.set_meta("last_code", code)
		var err: Error = Network.join(code, _name.text) if Network.is_lan_code(code) else Network.join_online(code, _name.text)
		_status.text = ("Connecting to %s …" % code) if err == OK else "Could not join: " + error_string(err))
	_btn(R, "◂ BACK", _title, true)
	_addr.grab_focus.call_deferred()
	go.focus_neighbor_top = _addr.get_path()
	_addr.text_submitted.connect(func(_t): go.pressed.emit())
	_refresh()


# ---------------------------------------------------------------- crew slots (click one to pick that role)

## Role -> [player name, peer id] for everyone online.
func _taken() -> Dictionary:
	var who := {}
	for id in Network.players:
		who[RoleSprites.role_for_slot(Network.players[id]["slot"])] = [Network.players[id]["name"], id]
	return who


func _pick(r: String) -> void:
	if _mode == "solo":
		_my_role = r
		_refresh()
	elif Network.is_online():
		Network.claim_slot(ROLES.find(r))      # the host checks the role is still free
	else:
		_status.text = "Open the crew first, then pick a role." if _mode == "host" else "Join the crew first, then pick a role."


func _refresh() -> void:
	if _slots == null or not is_instance_valid(_slots):
		return
	for c in _slots.get_children():
		c.queue_free()
	var who := _taken() if Network.is_online() else {}
	for r in ROLES:
		var mine: bool = (_mode == "solo" and r == _my_role) or (who.has(r) and who[r][1] == Network.my_id())
		var taken: bool = who.has(r) and not mine
		var status := ""
		if _mode == "solo":
			status = "YOU START AS THIS ROLE" if mine else ("CERES autopilot" if _crew_mode == "autopilot" else "Waits for you (TAB)")
		elif who.has(r):
			status = who[r][0] + (" (you)" if mine else "") + (" · HOST" if who[r][1] == 1 else "")
		else:
			status = "OPEN · click to pick · CERES autopilot"
		_slots.add_child(_slot_card(r, mine, taken, status))


func _slot_card(r: String, mine: bool, taken: bool, status: String) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(660, 104)
	card.disabled = taken
	card.tooltip_text = "Taken by another player" if taken else "Play as the " + RoleSprites.NAMES[r]
	var edge: Color = C["yellow"] if mine else (RoleSprites.TAGS[r] if taken else C["steel"])
	for k in ["normal", "disabled"]:
		card.add_theme_stylebox_override(k, DawnTheme.box(C["ink"], edge, 4, Color(0, 0, 0, 0), 0, Vector4(12, 8, 12, 8)))
	for k in ["hover", "pressed", "focus"]:
		card.add_theme_stylebox_override(k, DawnTheme.box(C["navy"], C["yellow"] if mine else RoleSprites.TAGS[r], 4, Color(0, 0, 0, 0), 0, Vector4(12, 8, 12, 8)))
	card.pressed.connect(func(): _pick(r))
	var row := HBoxContainer.new()
	row.position = Vector2(12, 12)
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var tr := TextureRect.new()
	tr.texture = RoleSprites.frames(r).get_frame_texture("idle_down", 0)
	tr.custom_minimum_size = Vector2(56, 80)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(tr)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var nm := _h(col, RoleSprites.NAMES[r], 12, RoleSprites.TAGS[r])
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	_p(col, status, 22, C["yellow"] if mine else C["white"]).autowrap_mode = TextServer.AUTOWRAP_OFF
	_p(col, ROLE_DESC[r], 18, C["grey"]).autowrap_mode = TextServer.AUTOWRAP_OFF
	for n in col.get_children():
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card
