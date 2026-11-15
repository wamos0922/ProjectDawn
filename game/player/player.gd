extends CharacterBody2D
## Top-down player for local co-op. Owner: Sufi (gameplay). Visuals: Zaliq/Wafi.
##
## How Zaliq/Wafi add art (no code changes needed):
##   Add an AnimatedSprite2D child named "Sprite" with animations named
##   idle_down, idle_up, idle_side, walk_down, walk_up, walk_side
##   (side animations face RIGHT; the script flips them for left).
##   While there is no "Sprite" child, a coloured placeholder is drawn.
##
## Other scripts use:
##   player_index        which keyboard set controls this player (0..3). Online: always 0 (WASD+E)
##   color_index         which colour to draw (-1 = same as player_index). Online: the player's slot
##   can_move            false while the player is inside a mini-game or dialogue
##   facing / is_moving  read-only state for animation, footsteps, etc.
##   signal interact_requested(player)   emitted when the interact key is pressed
##
## Online (see game/net/network.gd): every device spawns every player.
## Call set_multiplayer_authority(peer_id) before add_child. The owner's device moves
## the player and sends its position ~20 times a second; other devices smooth it.

const InputSetup := preload("res://game/input_setup.gd")
const RoleSprites := preload("res://game/player/role_sprites.gd")

signal interact_requested(player: CharacterBody2D)

## Placeholder colours, also handy for HUD markers. Same order as P1..P4.
const PLAYER_COLORS := [Color("#ffcf4a"), Color("#4ad6ff"), Color("#7dff7a"), Color("#ff7ad9")]

@export_range(0, 3) var player_index := 0
@export_range(-1, 3) var color_index := -1
@export var max_speed := 70.0        ## pixels per second (world pixels, before camera zoom)
@export var acceleration := 900.0    ## how fast it reaches max speed; higher = snappier
@export var friction := 1200.0       ## how fast it stops when keys are released

## Role outfit ("eng", "sci", "nav", "qm"). Empty = coloured placeholder. See role_sprites.gd.
@export var role := ""
@export var sprite_scale := 1.0
## Wearing the spacesuit (put on at the Crew Quarters locker before flying).
var suited := false:
	set(v):
		suited = v
		_redress()


## Computer-controlled crew member (CERES autopilot): ignores the keyboard and walks by ai_input.
var ai := false
var ai_input := Vector2.ZERO
var _footstep_timer := 0.0
const FOOTSTEP_INTERVAL := 0.38

var can_move := true
var facing := Vector2.DOWN
var is_moving := false

var _sprite: AnimatedSprite2D

var _tag: Label                      # role name above the head (spacesuits all look alike)

## Short role names shown above each crew member.
const TAG_TEXT := {"eng": "ENGINEER", "sci": "SCIENTIST", "nav": "NAVIGATOR", "qm": "QUARTERMASTER"}
const TAG_FONT_SIZE := 18            # bigger number = bigger text
const TAG_SCALE := 0.25              # drawn at 4x then shrunk, so the pixel font stays sharp at camera zoom 4

const SEND_INTERVAL := 0.05          # seconds between position updates (20 per second)
var _send_timer := 0.0
var _net_target := Vector2.ZERO      # where a remote player should be
var _has_net_target := false



func _redress() -> void:
	if _sprite and role != "":
		RoleSprites.dress(_sprite, role, suited, sprite_scale)
	_place_tag()          # <-- add this line

func _ready() -> void:
	InputSetup.ensure()
	_sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if _sprite == null and role != "":
		_sprite = RoleSprites.make(role, suited, sprite_scale)
		add_child(_sprite)
	_make_tag() 
	if get_node_or_null("CollisionShape2D") == null:
		# Feet-sized box: in top-down games only the feet should hit walls.
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(10, 6)
		shape.shape = rect
		shape.position = Vector2(0, -3)
		add_child(shape)
	# Layer 2 = players, mask 1 = world. Players pass through each other (like Among Us).
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	queue_redraw()
	# Opened on its own with F6? Add a still, zoomed camera so you can see it move.
	if get_parent() == get_tree().root:
		var cam := Camera2D.new()
		cam.zoom = Vector2(4, 4)
		get_parent().add_child.call_deferred(cam)
		
		
# ---------------------------------------------------------------- name tag above the head

func _make_tag() -> void:
	if role == "" or not TAG_TEXT.has(role):
		return
	_tag = Label.new()
	_tag.text = TAG_TEXT[role]
	_tag.add_theme_font_override("font", DawnTheme.body_font())
	_tag.add_theme_font_size_override("font_size", TAG_FONT_SIZE)
	_tag.add_theme_color_override("font_color", RoleSprites.TAGS[role])
	_tag.add_theme_color_override("font_outline_color", Color("#181425"))
	_tag.add_theme_constant_override("outline_size", 6)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.size = Vector2(200, 22)
	_tag.scale = Vector2(TAG_SCALE, TAG_SCALE)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.z_index = 5
	add_child(_tag)
	_place_tag()


## Sit the tag just above the head.
func _place_tag() -> void:
	if _tag == null:
		return
	var head := float(RoleSprites.FRAME.y) * sprite_scale
	_tag.position = Vector2(-_tag.size.x * TAG_SCALE / 2.0, -head - 6.0)


## The crew member you control shows "▼ENG" in yellow, like the HTML's yellow arrow.
func _update_tag() -> void:
	if _tag == null:
		return
	var mine := is_multiplayer_authority() and not ai
	_tag.text = ("▼" + TAG_TEXT[role]) if mine else TAG_TEXT[role]
	_tag.add_theme_color_override("font_color", Color("#fee761") if mine else RoleSprites.TAGS[role])


func _process(_delta: float) -> void:
	_update_tag()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		_follow_network(delta)
		return

	var input := Vector2.ZERO
	if ai:
		input = ai_input if can_move else Vector2.ZERO
	elif can_move and not _typing_in_chat():
		input = Input.get_vector(
			InputSetup.action(player_index, "left"),
			InputSetup.action(player_index, "right"),
			InputSetup.action(player_index, "up"),
			InputSetup.action(player_index, "down")
		)

	step(input, delta)
	move_and_slide()
	_update_footsteps(delta)
	_update_animation()
	_send_state(delta)


# ---------------------------------------------------------------- online sync

func _is_online() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)

func _typing_in_chat() -> bool:
	var focused_control: Control = get_viewport().gui_get_focus_owner()
	return focused_control is LineEdit or focused_control is TextEdit

func _send_state(delta: float) -> void:
	if not _is_online():
		return
	_send_timer -= delta
	if _send_timer <= 0.0:
		_send_timer = SEND_INTERVAL
		_net_state.rpc(position, facing, is_moving)


@rpc("authority", "unreliable_ordered")
func _net_state(pos: Vector2, dir: Vector2, moving: bool) -> void:
	_net_target = pos
	facing = dir
	is_moving = moving
	if not _has_net_target:
		position = pos               # first update: jump straight there
		_has_net_target = true


func _follow_network(delta: float) -> void:
	if _has_net_target:
		if position.distance_to(_net_target) > 48.0:
			position = _net_target   # too far behind (lag spike / room change): snap
		else:
			position = position.lerp(_net_target, 1.0 - exp(-15.0 * delta))
	_update_animation()


## Movement maths, separated from input so tests can drive it directly.
func step(input: Vector2, delta: float) -> void:
	if input.length() > 1.0:
		input = input.normalized()   # diagonal is not faster than straight
	if input != Vector2.ZERO:
		velocity = velocity.move_toward(input * max_speed, acceleration * delta)
		facing = _snap_to_4(input)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	is_moving = velocity.length() > 1.0

func _update_footsteps(delta: float) -> void:
	if not ai and can_move and get_real_velocity().length() > 1.0:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			Sound.play("footstep")
			_footstep_timer = FOOTSTEP_INTERVAL
	else:
		_footstep_timer = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if _typing_in_chat():
		return
	if can_move and not ai and is_multiplayer_authority() and event.is_action_pressed(InputSetup.action(player_index, "interact")):
		get_viewport().set_input_as_handled()     # one key press = one action (no double dialogue skip)
		interact_requested.emit(self)
		get_viewport().set_input_as_handled()


func _snap_to_4(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2.RIGHT if v.x > 0 else Vector2.LEFT
	return Vector2.DOWN if v.y > 0 else Vector2.UP


func _update_animation() -> void:
	if _sprite == null:
		queue_redraw()   # placeholder shows facing
		return
	var dir := "down" if facing == Vector2.DOWN else "up" if facing == Vector2.UP else "side"
	var anim := ("walk_" if is_moving else "idle_") + dir
	_sprite.flip_h = facing == Vector2.LEFT
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(anim) and _sprite.animation != anim:
		_sprite.play(anim)


## Placeholder body (only while there is no art): 12x18 px, origin at the feet.
func _draw() -> void:
	if _sprite != null:
		return
	var ci := player_index if color_index < 0 else color_index
	var c: Color = PLAYER_COLORS[ci % PLAYER_COLORS.size()]
	draw_rect(Rect2(-6, -18, 12, 18), c)                          # suit
	draw_rect(Rect2(-6, -18, 12, 18), Color.BLACK, false, 1.0)    # outline
	var visor := Rect2(-1 + facing.x * 3, -15 + maxf(facing.y, -0.5) * 2, 6, 4)
	if facing == Vector2.UP:
		visor = Rect2(-4, -16, 8, 2)                              # back of helmet
	draw_rect(visor, Color("#9fd8ff"))
