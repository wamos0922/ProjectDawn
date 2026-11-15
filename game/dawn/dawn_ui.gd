extends CanvasLayer
## HUD and pop-up panels for the Dawn game (1280x720), styled like the HTML demo (dawn_theme.gd).
## Owner: Sufi for now; Zaliq can restyle freely. Nothing here changes game state.
##
##   toast(text)                     short message at the bottom
##   say(lines, on_done)             dialogue box [{who, text}] with typewriter text; Space/E/click goes on
##   info(title, text, fact)         read-only panel
##   task(title, text, btn, secs, on_done)       press-and-wait task (progress bar)
##   choice(title, text, choices)    [{label, sub, fn}] buttons
##   panel(bg, border, width) -> VBoxContainer   build your own (minigames, mission panel)
## Everything lives under `root` (a themed Control), so full-screen story moments sit under the
## dialogue box and panels.

const WD := preload("res://game/dawn/world_data.gd")
const RoleSprites := preload("res://game/player/role_sprites.gd")
const Pixel := preload("res://game/dawn/pixel.gd")

const WHO := {
	"ceres": ["CERES", Color("#2ce8f5")], "eng": ["ENGINEER", Color("#f77622")], "sci": ["SCIENTIST", Color("#0099db")],
	"nav": ["NAVIGATOR", Color("#b55088")], "qm": ["QUARTERMASTER", Color("#feae34")], "narrator": ["", Color("#c0cbdc")],
}

signal panel_closed

signal chat_send(message: String)

var _chat_panel: PanelContainer
var _chat_log: RichTextLabel
var _chat_input: LineEdit

var game
var root: Control
var top: Label
var obj: Button
var room_label: Label
var hint: Label
var meter_box: HBoxContainer
var meter_label: Label
var meter_bar: ProgressBar
var hold_bar: ProgressBar
var _toast: PanelContainer
var _toast_l: Label
var _toast_t := 0.0
var _panel: Control
var _shade: ColorRect
var _dlg: PanelContainer
var _dlg_box: StyleBoxFlat
var _dlg_who: Label
var _dlg_text: Label
var _dlg_cont: Label
var _portrait: Control
var _queue: Array = []
var _dlg_done: Array = []
var _type := 0.0
var _full := ""
var _who := "ceres"


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.size = Vector2(1280, 720)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = DawnTheme.get_theme()
	add_child(root)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", DawnTheme.box(Color(0.094, 0.078, 0.145, 0.88), DawnTheme.C["slate"], 4, Color(0, 0, 0, 0), 0, Vector4(12, 7, 12, 7)))
	chip.position = Vector2(12, 8)
	root.add_child(chip)
	top = Label.new()
	top.add_theme_font_override("font", DawnTheme.title_font())
	top.add_theme_font_size_override("font_size", 10)
	top.add_theme_color_override("font_color", DawnTheme.C["sand"])
	chip.add_child(top)
	obj = Button.new()
	obj.position = Vector2(448, 8)
	obj.size = Vector2(598, 44)
	obj.add_theme_font_override("font", DawnTheme.body_font())
	obj.add_theme_font_size_override("font_size", 18)
	obj.add_theme_stylebox_override("normal", DawnTheme.box(Color(0.094, 0.078, 0.145, 0.88), DawnTheme.C["amber"], 4, Color(0, 0, 0, 0), 0, Vector4(12, 4, 12, 4)))
	obj.add_theme_stylebox_override("hover", DawnTheme.box(Color(0.15, 0.13, 0.22, 0.92), DawnTheme.C["yellow"], 4, Color(0, 0, 0, 0), 0, Vector4(12, 4, 12, 4)))
	obj.add_theme_stylebox_override("pressed", DawnTheme.box(Color(0.15, 0.13, 0.22, 0.92), DawnTheme.C["yellow"], 4, Color(0, 0, 0, 0), 0, Vector4(12, 4, 12, 4)))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		obj.add_theme_color_override(k, DawnTheme.C["white"])
	obj.clip_text = true
	obj.focus_mode = Control.FOCUS_NONE
	obj.tooltip_text = "Mission details (J)"
	obj.pressed.connect(func(): game.open_mission_panel())
	root.add_child(obj)
	hold_bar = ProgressBar.new()
	hold_bar.position = Vector2(448, 54)
	hold_bar.size = Vector2(598, 10)
	hold_bar.show_percentage = false
	hold_bar.max_value = 1.0
	hold_bar.visible = false
	root.add_child(hold_bar)
	_build_crewbar()
	room_label = _label(Vector2(16, 52), 12, DawnTheme.C["grey"], true)
	hint = _label(Vector2(16, 74), 20, DawnTheme.C["yellow"])
	meter_box = HBoxContainer.new()
	meter_box.position = Vector2(1020, 680)
	meter_box.add_theme_constant_override("separation", 8)
	meter_label = Label.new()
	meter_label.add_theme_font_override("font", DawnTheme.title_font())
	meter_label.add_theme_font_size_override("font_size", 11)
	meter_bar = ProgressBar.new()
	meter_bar.custom_minimum_size = Vector2(150, 16)
	meter_bar.show_percentage = false
	meter_bar.max_value = 1.0
	meter_box.add_child(meter_label)
	meter_box.add_child(meter_bar)
	meter_box.visible = false
	root.add_child(meter_box)
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", DawnTheme.box(Color(0.094, 0.078, 0.145, 0.92), DawnTheme.C["steel"], 4, Color(0, 0, 0, 0), 0, Vector4(16, 8, 16, 8)))
	_toast_l = Label.new()
	_toast_l.add_theme_font_size_override("font_size", 22)
	_toast_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_l.custom_minimum_size = Vector2(0, 0)
	_toast.add_child(_toast_l)
	_toast.visible = false
	root.add_child(_toast)
	_build_chat()
	_build_dialogue()


# ---------------------------------------------------------------- crew bar (top right, like the HTML)
## Four squares, one per crew member: click one (or press TAB) to control them.
## Yellow outline = you. Green dot = played by someone online.

var _crew_buttons := {}           ## role -> Button
var _crew_state := ""             ## last drawn state, so buttons only restyle when it changes


func _build_crewbar() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(1060, 6)
	bar.add_theme_constant_override("separation", 6)
	root.add_child(bar)
	for i in RoleSprites.ROLES.size():
		var r: String = RoleSprites.ROLES[i]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		bar.add_child(col)
		var b := Button.new()
		b.custom_minimum_size = Vector2(48, 48)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): game.crew_ctl.switch_to(r))
		# the character's head: top 8 rows of the first (front-facing) frame, 3x bigger
		var head := AtlasTexture.new()
		head.atlas = load(RoleSprites.sheet_path(r))
		head.region = Rect2(0, 0, 14, 8)
		var face := TextureRect.new()
		face.texture = head
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.position = Vector2(3, 12)
		face.size = Vector2(42, 24)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(face)
		var dot := ColorRect.new()
		dot.name = "Online"
		dot.color = DawnTheme.C["green"]
		dot.size = Vector2(12, 12)
		dot.position = Vector2(40, -4)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(dot)
		col.add_child(b)
		# the key to press, under the head
		var key := Label.new()
		key.text = str(i + 1)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_theme_font_override("font", DawnTheme.title_font())
		key.add_theme_font_size_override("font_size", 12)
		key.add_theme_color_override("font_color", DawnTheme.C["white"])
		key.add_theme_color_override("font_outline_color", DawnTheme.C["ink"])
		key.add_theme_constant_override("outline_size", 4)
		col.add_child(key)
		_crew_buttons[r] = b
		
func _build_chat() -> void:
	_chat_panel = PanelContainer.new()
	_chat_panel.position = Vector2(12, 546)
	_chat_panel.size = Vector2(360, 162)
	_chat_panel.custom_minimum_size = Vector2(360, 162)
	_chat_panel.add_theme_stylebox_override(
		"panel",
		DawnTheme.box(Color(0.06, 0.07, 0.11, 0.94), DawnTheme.C["slate"], 3)
	)
	root.add_child(_chat_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_chat_panel.add_child(box)

	var heading := Label.new()
	heading.text = "CREW CHAT"
	heading.add_theme_font_override("font", DawnTheme.title_font())
	heading.add_theme_font_size_override("font_size", 9)
	heading.add_theme_color_override("font_color", DawnTheme.C["cyan"])
	box.add_child(heading)

	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = true
	_chat_log.scroll_active = true
	_chat_log.custom_minimum_size = Vector2(0, 78)
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.add_theme_font_override("normal_font", DawnTheme.body_font())
	_chat_log.add_theme_font_size_override("normal_font_size", 16)
	_chat_log.add_theme_color_override("default_color", DawnTheme.C["white"])
	box.add_child(_chat_log)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)

	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Type a message..."
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.add_theme_font_override("font", DawnTheme.body_font())
	_chat_input.add_theme_font_size_override("font_size", 16)
	row.add_child(_chat_input)

	var send_button := Button.new()
	send_button.text = "SEND"
	send_button.add_theme_font_override("font", DawnTheme.title_font())
	send_button.add_theme_font_size_override("font_size", 8)
	row.add_child(send_button)

	send_button.pressed.connect(_send_chat)
	_chat_input.text_submitted.connect(func(_text: String): _send_chat())


func _send_chat() -> void:
	var message := _chat_input.text.strip_edges()
	if message.is_empty():
		return

	_chat_input.clear()
	chat_send.emit(message)


func add_chat_message(sender: String, message: String) -> void:
	if _chat_log == null:
		return

	# Keep player text from being interpreted as RichTextLabel formatting.
	var safe_message := message.replace("[", "[lb]")
	_chat_log.append_text(
		"[color=#2ce8f5]%s[/color]: %s\n" % [sender, safe_message]
	)
	_chat_log.scroll_to_line(_chat_log.get_line_count())


## me = role I control; online = roles other people play; where = role -> room name.
func update_crewbar(me: String, online: Array, where: Dictionary, autopilot: bool) -> void:
	var key := "%s|%s|%s|%s" % [me, online, where, autopilot]
	if key == _crew_state:
		return
	_crew_state = key
	for r in _crew_buttons:
		var b: Button = _crew_buttons[r]
		var mine: bool = r == me
		var edge: Color = DawnTheme.C["yellow"] if mine else DawnTheme.C["ink"]
		var st := DawnTheme.box(RoleSprites.TAGS[r], edge, 4 if mine else 3, Color(0, 0, 0, 0), 0, Vector4(0, 0, 0, 0))
		for k in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(k, st)
		b.get_node("Online").visible = online.has(r)
		var who := " (you)" if mine else (" (online player)" if online.has(r) else (" (CERES autopilot)" if autopilot else " (waiting)"))
		b.tooltip_text = "%s%s · %s" % [RoleSprites.NAMES[r], who, where.get(r, "?")]


func _process(delta: float) -> void:
	_toast_t -= delta
	_toast.visible = _toast_t > 0.0
	if _dlg.visible and _dlg_text.visible_characters < _full.length() and _dlg_text.visible_characters >= 0:
		_type += delta
		var before := _dlg_text.visible_characters
		_dlg_text.visible_characters = mini(_full.length(), int(_type / 0.022))
		if _dlg_text.visible_characters / 2 != before / 2:
			Sound.play("robot_type" if _who == "ceres" else "type")
		_dlg_cont.visible = _dlg_text.visible_characters >= _full.length()
		
	_chat_panel.visible = not _dlg.visible and _panel == null


func _label(pos: Vector2, size: int, color: Color, title := false) -> Label:
	var l := Label.new()
	l.position = pos
	if title:
		l.add_theme_font_override("font", DawnTheme.title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	root.add_child(l)
	return l


func toast(text: String, seconds := 2.6) -> void:
	_toast_l.text = text
	var w := minf(960.0, DawnTheme.body_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 40)
	_toast_l.custom_minimum_size = Vector2(w, 0)
	_toast_t = seconds
	_toast.visible = true
	root.move_child(_toast, -1)
	_fit_toast()
	_fit_toast.call_deferred()     # again after the label has wrapped at its real width (the first toast was huge)


## Shrinks the toast box to its text and puts it above the bottom of the screen.
func _fit_toast() -> void:
	_toast.size = Vector2.ZERO
	_toast.reset_size()
	_toast.position = Vector2((1280 - _toast.size.x) / 2.0, 560 - _toast.size.y)

func meter(label: String, frac: float) -> void:
	meter_box.visible = frac >= 0.0
	if frac >= 0.0:
		meter_label.text = label
		meter_bar.value = frac
		meter_bar.modulate = DawnTheme.C["sand"] if frac >= 0.3 else Color("#e43b44")


# ---------------------------------------------------------------- dialogue (fixed size, like the demo)

func _build_dialogue() -> void:
	_dlg = PanelContainer.new()
	_dlg_box = DawnTheme.box(Color(0.094, 0.078, 0.145, 0.94), DawnTheme.C["cyan"], 4, Color(0, 0, 0, 0), 0, Vector4(24, 16, 24, 12))
	_dlg.add_theme_stylebox_override("panel", _dlg_box)
	_dlg.position = Vector2(280, 552)
	_dlg.custom_minimum_size = Vector2(968, 136)
	_dlg.size = Vector2(968, 136)
	_dlg.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_dlg.add_child(v)
	_dlg_who = Label.new()
	_dlg_who.add_theme_font_override("font", DawnTheme.title_font())
	_dlg_who.add_theme_font_size_override("font_size", 13)
	v.add_child(_dlg_who)
	_dlg_text = Label.new()
	_dlg_text.add_theme_font_size_override("font_size", 28)
	_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_text.custom_minimum_size = Vector2(916, 70)
	v.add_child(_dlg_text)
	_dlg_cont = Label.new()
	_dlg_cont.text = "click / space ▸"
	_dlg_cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dlg_cont.add_theme_font_size_override("font_size", 16)
	_dlg_cont.add_theme_color_override("font_color", DawnTheme.C["grey"])
	v.add_child(_dlg_cont)
	_dlg.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: advance())
	_dlg.visible = false
	root.add_child(_dlg)
	# speaker portrait on the left (like the crew close-up in the demo)
	_portrait = Pixel.new()
	_portrait.size = Vector2(1280, 720)
	_portrait.painter = func(pc, tt, _d):
		if not _dlg.visible or _queue.is_empty():
			return
		var who: String = _queue[0].get("who", "ceres")
		pc.R(8, 138, 60, 36, Color(0.094, 0.078, 0.145, 0.94))
		var c: Color = WHO.get(who, WHO["ceres"])[1]
		pc.R(8, 138, 60, 1, c); pc.R(8, 173, 60, 1, c); pc.R(8, 138, 1, 36, c); pc.R(67, 138, 1, 36, c)
		if who == "ceres":
			pc.ceres(38, 156, 11, tt)
		elif who in ["eng", "sci", "nav", "qm"]:
			pc.person(who, 24, 139 + (int(tt * 2) % 2), "down", 0, 1.6)
	root.add_child(_portrait)


## Queue dialogue lines. on_done runs after the last line of this batch.
func say(lines: Array, on_done := Callable()) -> void:
	for l in lines:
		_queue.append(l)
	_dlg_done.append({"after": _queue.size(), "fn": on_done})
	if not _dlg.visible:
		_show_next()


func dialogue_open() -> bool:
	return _dlg.visible


func advance() -> void:
	game.advance_dialogue_all()


func advance_local() -> void:
	if not _dlg.visible:
		return
	if _dlg_text.visible_characters >= 0 and _dlg_text.visible_characters < _full.length():
		_dlg_text.visible_characters = -1
		_dlg_cont.visible = true
		return
	_queue.pop_front()
	for d in _dlg_done:
		d["after"] -= 1
	var ready := _dlg_done.filter(func(d): return d["after"] <= 0)
	_dlg_done = _dlg_done.filter(func(d): return d["after"] > 0)
	_show_next()
	for d in ready:
		if d["fn"].is_valid():
			d["fn"].call()


func _show_next() -> void:
	if _queue.is_empty():
		_dlg.visible = false
		return
	var l: Dictionary = _queue[0]
	_who = l.get("who", "ceres")
	var who: Array = WHO.get(l.get("who", "ceres"), WHO["ceres"])
	_dlg_who.text = who[0]
	_dlg_who.add_theme_color_override("font_color", who[1])
	_dlg_box.border_color = who[1]
	_full = l.get("text", "")
	_dlg_text.text = _full
	_dlg_text.visible_characters = 0
	_type = 0.0
	_dlg_cont.visible = false
	_dlg.visible = true             
	root.move_child(_dlg, -1)
	root.move_child(_portrait, -1)


## Keep the dialogue box, its portrait and the toast above full-screen story moments.
func raise_overlays() -> void:
	for n in [_dlg, _portrait, _toast, _shade, _panel]:
		if n and is_instance_valid(n):
			root.move_child(n, -1)


# ---------------------------------------------------------------- panels

func panel_open() -> bool:
	return _panel != null


func close_panel() -> void:
	station_mode = false
	if _panel:
		_panel.queue_free()
		_panel = null
	if _shade:
		_shade.queue_free()
		_shade = null
	game.set_frozen(false)
	panel_closed.emit()



func _modal(dim: float) -> void:
	if _panel:
		_panel.queue_free()
	if _shade == null:
		_shade = ColorRect.new()
		_shade.size = Vector2(1280, 720)
		_shade.mouse_filter = Control.MOUSE_FILTER_STOP
		root.add_child(_shade)
	_shade.color = Color(0.094, 0.078, 0.145, dim)
	root.move_child(_shade, -1)
	game.set_frozen(true)


## While station_mode is on, panel() opens the same fixed-size window as the minigames
## (station_window). dawn.gd turns it on when you press E at a station; close_panel() turns it off.
func panel(bg := Color("#262b44"), border := Color("#feae34"), width := 760.0, top_y := 70.0) -> VBoxContainer:
	if station_mode:
		return station_window(bg, border)
	_modal(0.55)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", DawnTheme.box(bg, border, 4, Color(0, 0, 0, 0), 0, Vector4(24, 20, 24, 20)))
	p.custom_minimum_size = Vector2(width, 0)
	p.position = Vector2((1280 - width) / 2.0, top_y)
	root.add_child(p)
	_panel = p
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	p.add_child(box)
	return box
	
# ---------------------------------------------------------------- station window (anything opened with E)

var station_mode := false                    ## true from pressing E at a station until the panel closes


## Fixed POPUP_SIZE window in the middle of the screen, room visible behind. Same colours as the
## panel that asked for it; the content scrolls if it is taller than the window.
func station_window(bg: Color, border: Color) -> VBoxContainer:
	_modal(POPUP_DIM)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", DawnTheme.box(bg, border, 4, Color(0, 0, 0, 0.5), 10, Vector4(24, 20, 12, 20)))
	p.custom_minimum_size = POPUP_SIZE
	p.size = POPUP_SIZE
	p.position = (Vector2(1280, 720) - POPUP_SIZE) / 2.0
	root.add_child(p)
	_panel = p
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	_pop_in(p)
	return box


## Grow from 92% and fade in (both popups).
func _pop_in(p: Control) -> void:
	p.pivot_offset = POPUP_SIZE / 2.0
	p.scale = Vector2(0.92, 0.92)
	p.modulate.a = 0.0
	var tw := p.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "scale", Vector2.ONE, 0.16)
	tw.tween_property(p, "modulate:a", 1.0, 0.1)

# ---------------------------------------------------------------- task popup (minigames)
# ---------------------------------------------------------------- task popup (minigames)

const POPUP_SIZE := Vector2(880, 560)        ## every minigame window has this size
const POPUP_DIM := 0.35                      ## how dark the game behind gets (0 = clear, 1 = black)


## Opens a fixed-size task window in the middle of the screen, like a task in Among Us: the room
## stays visible around it. Returns {"body": VBox to fill (scrolls if too tall), "foot": buttons row}.
## Same life cycle as panel(): panel_open(), close_panel() and Esc work the same.
func popup(kicker: String, heading: String, accent: Color) -> Dictionary:
	_modal(POPUP_DIM)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", DawnTheme.box(Color("#1b1e33"), DawnTheme.C["slate"], 6, Color(0, 0, 0, 0.5), 10, Vector4(0, 0, 0, 0)))
	p.custom_minimum_size = POPUP_SIZE
	p.size = POPUP_SIZE
	p.position = (Vector2(1280, 720) - POPUP_SIZE) / 2.0
	root.add_child(p)
	_panel = p
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 0)
	p.add_child(frame)
	# header strip: role + task name on the accent colour, close button on the right
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", DawnTheme.box(accent, Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, Vector4(20, 10, 12, 10)))
	frame.add_child(head)
	var hrow := HBoxContainer.new()
	head.add_child(hrow)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 6)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(names)
	title(names, kicker, DawnTheme.C["ink"], 10)
	title(names, heading, DawnTheme.C["ink"], 20)
	var x := Button.new()
	x.text = "✕"
	x.tooltip_text = "Close (Esc). You can come back later."
	x.focus_mode = Control.FOCUS_NONE
	x.theme_type_variation = "GhostButton"
	x.custom_minimum_size = Vector2(44, 44)
	x.add_theme_font_size_override("font_size", 22)
	x.pressed.connect(close_panel)
	hrow.add_child(x)
	# body (scrolls if a minigame is taller than the window) and the fixed button row
	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top"]:
		pad.add_theme_constant_override("margin_" + side, 20)
	frame.add_child(pad)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pad.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	var fpad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		fpad.add_theme_constant_override("margin_" + side, 16 if side != "top" else 8)
	frame.add_child(fpad)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	fpad.add_child(foot)
	_pop_in(p)
	return {"body": body, "foot": foot}

func title(box: Node, text: String, color := Color("#fee761"), size := 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", DawnTheme.title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	return l


func rich(box: Node, bb: String, size := 18) -> RichTextLabel:
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.scroll_active = false
	t.add_theme_font_size_override("normal_font_size", size + 4)
	t.add_theme_font_size_override("bold_font_size", maxi(10, int(size * 0.72)))
	t.text = bb
	box.add_child(t)
	return t


func button(box: Node, text: String, fn: Callable, primary := true) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	if not primary:
		b.theme_type_variation = "GhostButton"
	b.custom_minimum_size = Vector2(0, 46)
	if fn.is_valid():
		b.pressed.connect(fn)
	box.add_child(b)
	return b


func row(box: Node) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 14)
	box.add_child(r)
	return r


func info(t: String, text: String, fact := "", btn := "OK", on_done := Callable()) -> void:
	var box := panel()
	title(box, t)
	rich(box, text, 19)
	if fact != "":
		rich(box, "[color=#fee761]★ %s[/color]" % fact, 16)
	var b := button(box, btn, func():
		close_panel()
		if on_done.is_valid(): on_done.call())
	b.grab_focus.call_deferred()


## A job that takes a moment: press the button, wait for the bar, done.
func task(t: String, text: String, btn: String, secs: float, on_done: Callable, fact := "") -> void:
	var box := panel()
	title(box, t)
	rich(box, text, 19)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 16)
	bar.show_percentage = false
	bar.max_value = 1.0
	box.add_child(bar)
	if fact != "":
		rich(box, "[color=#fee761]★ %s[/color]" % fact, 16)
	var r := row(box)
	var go := button(r, btn + "  ▸▸", Callable())
	go.pressed.connect(func():
		go.disabled = true
		var tw := create_tween()
		tw.tween_property(bar, "value", 1.0, maxf(0.2, secs))
		tw.finished.connect(func():
			close_panel()
			on_done.call()))
	button(r, "LATER", close_panel, false)
	go.grab_focus.call_deferred()


## choices: [{label, sub, fn}]
## Review mode (F8): if one choice is marked "best", show a placeholder with COMPLETE that picks it.
func choice(t: String, text: String, choices: Array, tag := "") -> void:
	var best := choices.filter(func(c): return c.get("best", false))
	if not best.is_empty() and game and game.Minigames.review_mode():
		var pb := panel()
		if tag != "":
			title(pb, tag, Color("#f6757a"), 11)
		title(pb, t)
		rich(pb, "[color=#fee761]REVIEW MODE[/color] · placeholder question. COMPLETE picks the right answer: [b]%s[/b]. [color=#8b9bb4](F8 turns review mode off.)[/color]" % best[0]["label"], 19)
		var pr := row(pb)
		var fn_best: Callable = best[0]["fn"]
		var go := button(pr, "COMPLETE  ▸▸", func():
			close_panel()
			fn_best.call())
		button(pr, "LATER", close_panel, false)
		go.grab_focus.call_deferred()
		return
	var box := panel()
	if tag != "":
		title(box, tag, Color("#f6757a"), 11)
	title(box, t)
	rich(box, text, 19)
	var r := row(box)
	var first: Button
	for c in choices:
		var b := Button.new()
		b.theme_type_variation = "GhostButton"
		b.text = c["label"] + ("\n" + c["sub"] if c.get("sub", "") != "" else "")
		b.custom_minimum_size = Vector2(220, 84)
		b.add_theme_font_override("font", DawnTheme.body_font())
		b.add_theme_font_size_override("font_size", 20)
		var fn: Callable = c["fn"]
		b.pressed.connect(func():
			close_panel()
			fn.call())
		r.add_child(b)
		if first == null:
			first = b
	button(box, "LATER", close_panel, false)
	if first:
		first.grab_focus.call_deferred()
