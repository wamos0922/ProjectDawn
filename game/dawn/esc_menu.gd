extends Node
## Esc menu: SETTINGS and CONTROLS. The game keeps running (it is a co-op game), only your
## own crew member stops walking while the menu is open (like every other panel).
## Created by dawn.gd as a child named "EscMenu".

## Every key in the game, in groups. Each row: [keys..., what it does].
## Add a row here when you add a new key; the CONTROLS page builds itself from this list.
const CONTROLS := {
	"MOVE & USE": [
		[["W", "A", "S", "D"], "Walk (or arrow keys)"],
		[["E"], "Use / talk (or Enter)"],
		[["SPACE"], "Next line of dialogue"],
	],
	"CREW": [
		[["TAB"], "Switch crew member"],
		[["F"], "Crew follow you"],
		[["C"], "CERES autopilot on / off"],
	],
	"SCREENS": [
		[["M"], "World map"],
		[["J"], "Mission details"],
		[["ESC"], "Menu / close"],
	],
	"TEAM TESTING": [
		[["F8"], "Review mode: minigames become one click"],
	],
}

var g                             ## dawn.gd


## The first page: what Esc shows.
func open() -> void:
	var box: VBoxContainer = g.ui.panel(Color("#262b44"), Color("#feae34"), 420, 200)
	g.ui.title(box, "MENU")
	g.ui.button(box, "SETTINGS", _settings, false)
	g.ui.button(box, "CONTROLS", _controls, false)
	g.ui.button(box, "BACK TO GAME", g.ui.close_panel)


## CONTROLS page: the groups stacked under each other, keys drawn as key caps.
func _controls() -> void:
	var box: VBoxContainer = g.ui.panel(Color("#262b44"), Color("#feae34"), 620, 24)
	g.ui.title(box, "CONTROLS")
	for group in CONTROLS:
		var gap := Control.new()                    # a little air above each group
		gap.custom_minimum_size = Vector2(0, 4)
		box.add_child(gap)
		box.add_child(_text(group, DawnTheme.C["amber"], DawnTheme.title_font(), 11))
		for row in CONTROLS[group]:
			box.add_child(_control_row(row[0], row[1]))
	box.add_child(_text("Tip: you can also click the crew squares (top right) and the objective bar.", DawnTheme.C["grey"], DawnTheme.body_font(), 18))
	g.ui.button(box, "◂ BACK", open, false)


## One line: [key caps]  what it does.
func _control_row(keys: Array, what: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var caps := HBoxContainer.new()
	caps.add_theme_constant_override("separation", 4)
	caps.custom_minimum_size = Vector2(150, 0)     # same width every row, so the text lines up
	for k in keys:
		caps.add_child(_key_cap(k))
	row.add_child(caps)
	row.add_child(_text(what, DawnTheme.C["white"], DawnTheme.body_font(), 20))
	return row


## A key drawn like a keyboard key (dark box, light border, shadow underneath).
func _key_cap(key: String) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.add_theme_stylebox_override("panel", DawnTheme.box(DawnTheme.C["ink"], DawnTheme.C["steel"], 2, DawnTheme.C["slate"], 3, Vector4(8, 6, 8, 6)))
	cap.custom_minimum_size = Vector2(32, 0)
	var l := _text(key, DawnTheme.C["yellow"], DawnTheme.title_font(), 11)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(l)
	return cap


## SETTINGS page. Review mode: every minigame becomes a one-click placeholder (team testing).
func _settings() -> void:
	var box: VBoxContainer = g.ui.panel(Color("#262b44"), Color("#feae34"), 520, 200)
	g.ui.title(box, "SETTINGS")
	var on: bool = g.Minigames.review_mode()
	g.ui.rich(box, "[b]Review mode[/b]: every minigame becomes one COMPLETE button, so you can play through all the acts quickly. Only on this computer. [color=#8b9bb4](Shortcut: F8)[/color]")
	g.ui.button(box, "REVIEW MODE: %s" % ("ON" if on else "OFF"), func():
		g.toggle_review_mode()
		_settings(), false)
	g.ui.button(box, "◂ BACK", open, false)


func _text(text: String, color: Color, font: Font, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
