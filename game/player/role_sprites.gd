extends RefCounted
## Role outfits for the player: Engineer, Scientist, Navigator, Quartermaster,
## plus a spacesuit version of each. Owner: Sufi (gameplay). Art: assets/art/characters/.
##
## Each sheet is 56x60: 4 walk frames (14x20 px) per row, rows = down, up, side (facing RIGHT).
##   var spr := RoleSprites.make("nav")          # uniform
##   var spr := RoleSprites.make("nav", true)    # spacesuit
## Animation names match player.gd: idle_down, walk_down, idle_up, walk_up, idle_side, walk_side.

const ROLES := ["eng", "sci", "nav", "qm"]
const NAMES := {"eng": "ENGINEER", "sci": "SCIENTIST", "nav": "NAVIGATOR", "qm": "QUARTERMASTER"}
const TAGS := {"eng": Color("#f77622"), "sci": Color("#e8ecf2"), "nav": Color("#4b6cb7"), "qm": Color("#feae34")}
const FRAME := Vector2i(14, 20)
const ROWS := {"down": 0, "up": 1, "side": 2}
const WALK_FPS := 8.0

static var _cache := {}


## Role for a player slot or local player index (0..3).
static func role_for_slot(slot: int) -> String:
	return ROLES[posmod(slot, ROLES.size())]


static func sheet_path(role: String, suit := false) -> String:
	var key := role if role in ROLES else "civ"
	return "res://assets/art/characters/%s%s.png" % ["suit_" if suit and key != "civ" else "", key]


static func frames(role: String, suit := false) -> SpriteFrames:
	var path := sheet_path(role, suit)
	var fs := FRAME
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = load(path)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for dir in ROWS:
		var row: int = ROWS[dir]
		var idle: String = "idle_" + dir
		var walk: String = "walk_" + dir
		sf.add_animation(idle)
		sf.add_animation(walk)
		sf.set_animation_speed(walk, WALK_FPS)
		sf.set_animation_loop(walk, true)
		for f in 4:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(Vector2(f * fs.x, row * fs.y), Vector2(fs))
			sf.add_frame(walk, at)
			if f == 0:
				sf.add_frame(idle, at)
	_cache[path] = sf
	return sf


## A ready-made "Sprite" node for player.gd. Origin = feet (bottom centre).
static func make(role: String, suit := false, scale := 1.0) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.name = "Sprite"
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dress(s, role, suit, scale)
	s.play("idle_down")
	return s


## Swap an existing Sprite to another outfit (uniform or spacesuit), keeping its animation.
static func dress(s: AnimatedSprite2D, role: String, suit: bool, scale: float) -> void:
	var anim := s.animation
	var fs := FRAME
	s.sprite_frames = frames(role, suit)
	s.scale = Vector2(scale, scale)
	s.position = Vector2(-fs.x / 2.0, -fs.y + 1) * scale
	if s.sprite_frames.has_animation(anim):
		s.play(anim)
