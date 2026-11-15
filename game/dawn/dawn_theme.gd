class_name DawnTheme
extends RefCounted
## The look of the HTML demo: Press Start 2P for titles and buttons, Pixelify Sans for text,
## amber buttons with a rust shadow, navy panels with amber borders. Owner: Sufi (Zaliq: restyle here).
## Fonts: assets/fonts (SIL Open Font License, see the OFL files next to them).

const TITLE_FONT := "res://assets/fonts/PressStart2P-Regular.ttf"
const BODY_FONT := "res://assets/fonts/PixelifySans.ttf"
const SYMBOL_FONT := "res://assets/fonts/DawnSymbols.ttf"
const C := {"ink": Color("#181425"), "navy": Color("#262b44"), "slate": Color("#3a4466"), "steel": Color("#5a6988"),
	"amber": Color("#feae34"), "yellow": Color("#fee761"), "rust": Color("#be4a2f"), "sand": Color("#ead4aa"),
	"cyan": Color("#2ce8f5"), "white": Color("#ffffff"), "grey": Color("#8b9bb4"), "green": Color("#63c74d")}

static var _theme: Theme
static var _title: Font
static var _body: Font


static func title_font() -> Font:
	if _title == null:
		_title = load(TITLE_FONT)
		_title.fallbacks = [load(SYMBOL_FONT)]
	return _title


static func body_font() -> Font:
	if _body == null:
		_body = load(BODY_FONT)
		_body.fallbacks = [load(SYMBOL_FONT)]
	return _body


static func box(bg: Color, border := Color(0, 0, 0, 0), bw := 0, shadow := Color(0, 0, 0, 0), sh := 0, pad := Vector4(20, 12, 20, 12)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	if sh > 0:
		s.border_width_bottom = bw + sh
		s.border_color = border if bw > 0 else shadow
		if bw == 0:
			s.border_width_left = 0
			s.border_width_right = 0
			s.border_width_top = 0
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	return s


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var th := Theme.new()
	th.default_font = body_font()
	th.default_font_size = 22
	# buttons: amber with a rust shadow; GhostButton: navy
	th.set_font("font", "Button", title_font())
	th.set_font_size("font_size", "Button", 14)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(k, "Button", C["ink"])
	th.set_color("font_disabled_color", "Button", C["slate"])
	th.set_stylebox("normal", "Button", box(C["amber"], Color(0, 0, 0, 0), 0, C["rust"], 6))
	th.set_stylebox("hover", "Button", box(C["yellow"], Color(0, 0, 0, 0), 0, C["rust"], 6))
	th.set_stylebox("pressed", "Button", box(C["amber"].darkened(0.1), Color(0, 0, 0, 0), 0, C["rust"], 2))
	th.set_stylebox("hover_pressed", "Button", box(C["yellow"], Color(0, 0, 0, 0), 0, C["rust"], 2))
	th.set_stylebox("disabled", "Button", box(C["grey"], Color(0, 0, 0, 0), 0, C["slate"], 6))
	var focus := box(Color(0, 0, 0, 0), C["cyan"], 4)
	focus.draw_center = false
	focus.expand_margin_left = 4
	focus.expand_margin_right = 4
	focus.expand_margin_top = 4
	focus.expand_margin_bottom = 4
	th.set_stylebox("focus", "Button", focus)
	th.set_type_variation("GhostButton", "Button")
	for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		th.set_color(k, "GhostButton", C["sand"])
	th.set_stylebox("normal", "GhostButton", box(C["navy"], Color(0, 0, 0, 0), 0, C["ink"], 6))
	th.set_stylebox("hover", "GhostButton", box(C["slate"], Color(0, 0, 0, 0), 0, C["ink"], 6))
	th.set_stylebox("pressed", "GhostButton", box(C["navy"], Color(0, 0, 0, 0), 0, C["ink"], 2))
	# panels
	th.set_stylebox("panel", "PanelContainer", box(Color(C["navy"], 0.97), C["amber"], 4, C["ink"], 0, Vector4(24, 20, 24, 20)))
	# text
	th.set_color("font_color", "Label", C["white"])
	th.set_font("normal_font", "RichTextLabel", body_font())
	th.set_font("bold_font", "RichTextLabel", title_font())
	th.set_color("default_color", "RichTextLabel", C["white"])
	th.set_font("font", "LineEdit", title_font())
	th.set_font_size("font_size", "LineEdit", 26)
	th.set_stylebox("normal", "LineEdit", box(C["ink"], C["steel"], 3, Color(0, 0, 0, 0), 0, Vector4(12, 10, 12, 10)))
	th.set_stylebox("focus", "LineEdit", box(C["ink"], C["cyan"], 3, Color(0, 0, 0, 0), 0, Vector4(12, 10, 12, 10)))
	th.set_color("font_color", "LineEdit", C["white"])
	th.set_stylebox("background", "ProgressBar", box(C["ink"], C["slate"], 2, Color(0, 0, 0, 0), 0, Vector4(0, 0, 0, 0)))
	th.set_stylebox("fill", "ProgressBar", box(C["green"], Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, Vector4(0, 0, 0, 0)))
	th.set_font("font", "CheckBox", body_font())
	th.set_color("font_color", "CheckBox", C["white"])
	th.set_color("font_hover_color", "CheckBox", C["yellow"])
	th.set_color("font_pressed_color", "CheckBox", C["green"])
	th.set_color("font_hover_pressed_color", "CheckBox", C["green"])
	th.set_color("font_focus_color", "CheckBox", C["white"])
	_theme = th
	return th
