extends Node2D
class_name Player

## Player — 1:1 port of JS fighter.js + combat.js
## Uses per-tick physics in _physics_process (60Hz fixed).
## Does NOT use move_and_slide — position updated directly to match JS:
##   this.x += this.velX; this.y += this.velY; this.velY += GRAVITY

# ── Per-tick constants (matching JS exactly) ──────────────────────────
const GRAVITY: float      = 0.55
const JUMP_VEL: float     = -11.0
const WALK_SPEED: float   = 3.0
const MAX_HEALTH: int     = 1000

# ── Stage bounds (from JS config: STAGE_LEFT=165, STAGE_RIGHT=657) ───
const STAGE_LEFT: int     = 165
const STAGE_RIGHT: int    = 657

# ── Attack data (from JS config) ─────────────────────────────────────
const ATTACKS: Dictionary = {
	"lightPunch":  { "startup": 3,  "active": 2, "recovery": 5,  "damage": 30,  "hitstun": 10, "blockstun": 6,  "pushback": 2, "type": "mid" },
	"heavyPunch":  { "startup": 6,  "active": 3, "recovery": 12, "damage": 80,  "hitstun": 16, "blockstun": 10, "pushback": 4, "type": "mid" },
	"lightKick":   { "startup": 4,  "active": 3, "recovery": 6,  "damage": 40,  "hitstun": 12, "blockstun": 7,  "pushback": 3, "type": "mid" },
	"heavyKick":   { "startup": 7,  "active": 4, "recovery": 14, "damage": 100, "hitstun": 20, "blockstun": 12, "pushback": 5, "type": "low", "knockdown": true },
}

const TEKNIUM_ATTACKS: Dictionary = {
	"heavyPunch":  { "startup": 3,  "active": 5, "recovery": 13, "damage": 80,  "hitstun": 16, "blockstun": 10, "pushback": 4, "type": "mid" },
	"lightKick":   { "startup": 2,  "active": 5, "recovery": 6,  "damage": 40,  "hitstun": 12, "blockstun": 7,  "pushback": 3, "type": "mid" },
}

# ── Animation speeds (JS frames per sprite-frame) ────────────────────
const ANIM_SPEED: Dictionary = {
	"idle":         8,
	"walking":      6,
	"jump":         5,
	"crouching":    4,
	"lightpunch":   4,
	"heavypunch":   5,
	"lightkick":    4,
	"heavykick":    5,
	"victory":      8,
	"victory_loop": 8,
	"abdomen_hit":  4,
	"head_hit":     4,
	"ko":           6,
}

# ── Hitbox/Hurtbox constants (from JS config, relative to position = feet center) ──
# JS hurtbox: { x: -20, y: -80, w: 40, h: 80 }
const HURTBOX := Rect2(-20, -80, 40, 80)

# JS attackHitbox: relative to fighter center-bottom, facing right
# Flipped horizontally when facing left
const ATTACK_HITBOX: Dictionary = {
	"lightPunch":  Rect2(20, -70, 40, 15),
	"heavyPunch":  Rect2(20, -65, 50, 20),
	"lightKick":   Rect2(15, -40, 45, 15),
	"heavyKick":   Rect2(10, -20, 55, 15),
}

const TEKNIUM_ATTACK_HITBOX: Dictionary = {
	"heavyPunch":  Rect2(8, -68, 68, 24),
	"lightKick":   Rect2(-6, -52, 78, 28),
	"heavyKick":   Rect2(-2, -34, 84, 26),
}

# ── Knockdown / getting up timings (from JS config) ──────────────────
const KNOCKDOWN_FRAMES: int    = 40
const GETTING_UP_FRAMES: int   = 20

# ── Exports ───────────────────────────────────────────────────────────
@export var player_index: int = 1
@export var character_name: String = "Teknium"
@export var facing_right: bool = true

const SHADOW_TEX_SIZE := Vector2i(128, 52)
const SHADOW_FEET_OFFSET_Y := -40.0
const SHADOW_GROUND_ALPHA := 0.72
const SHADOW_AIR_ALPHA := 0.34
const SHADOW_MIN_SCALE := 0.55

# ── Public state ──────────────────────────────────────────────────────
var health: int = MAX_HEALTH
var vel_x: float = 0.0
var vel_y: float = 0.0
var ground_y: float = 0.0  # set by Main on spawn
var just_landed: bool = false
var in_jump: bool = false
var stage_left_bound: float = STAGE_LEFT
var stage_right_bound: float = STAGE_RIGHT

# Attack state
var current_attack: String = ""
var attack_frame: int = 0
var has_hit: bool = false

# Hitstun / blockstun state
var hitstun_timer: int = 0
var blockstun_timer: int = 0
var is_in_hitstun: bool = false
var is_in_blockstun: bool = false
var pending_pushback: float = 0.0
var knockdown_timer: int = 0
var is_knocked_down: bool = false
var getting_up_timer: int = 0

# Block state
var is_blocking: bool = false
var block_type: String = ""  # "stand" or "crouch"

# Pushback (set by Main.gd combat processing)
var pushback_dir: float = 0.0  # 1.0 = push right, -1.0 = push left

# Other player reference (set by Main.gd in _ready)
var other_player: Player = null

# Optional AI override input (used for CPU-controlled P2)
var ai_input: Dictionary = {}
var _prev_ai_input: Dictionary = {}

# Round flow / freeze state (controlled by Main)
var control_enabled: bool = true
var hitstop_frames: int = 0

# Animation state (manual, matching JS)
var current_anim: String = "idle"
var anim_frame: int = 0
var anim_timer: int = 0

# Crouch sub-state
var crouch_phase: String = ""  # "entering", "holding", "exiting"

# ── Node refs ─────────────────────────────────────────────────────────
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var shadow_sprite: Sprite2D = null
var shadow_base_scale: Vector2 = Vector2.ONE

# Debug overlay — created programmatically
var debug_overlay: Label = null

# ── Signals ───────────────────────────────────────────────────────────
signal took_damage(amount: int)
signal died

func _ready() -> void:
	health = MAX_HEALTH
	_create_shadow()
	_apply_character_visuals()
	sprite.animation_finished.connect(_on_animation_finished)
	_update_shadow()

	# Create in-game debug overlay — hidden by default for player-facing view
	debug_overlay = Label.new()
	debug_overlay.position = Vector2(-80, -220)
	debug_overlay.add_theme_font_size_override("font_size", 10)
	debug_overlay.add_theme_color_override("font_color", Color.YELLOW)
	debug_overlay.z_index = 999
	debug_overlay.visible = false
	add_child(debug_overlay)

func _apply_character_visuals() -> void:
	var frames := SpriteLoader.build_character_frames(character_name)
	sprite.sprite_frames = frames
	if character_name.to_lower() == "teknium":
		sprite.scale = Vector2(0.78, 0.78)
		shadow_base_scale = Vector2(1.0, 0.62)
	else:
		sprite.scale = Vector2(1.33333, 1.33333)
		shadow_base_scale = Vector2(1.0, 0.62)
	if shadow_sprite:
		shadow_sprite.scale = shadow_base_scale
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle") and sprite.sprite_frames.get_frame_count("idle") > 0:
		sprite.play("idle")
	else:
		push_warning("Player %d: cannot play idle animation for '%s'!" % [player_index, character_name])

func set_character(value: String) -> void:
	character_name = value
	if sprite:
		_apply_character_visuals()
		_update_shadow()

func _create_shadow() -> void:
	shadow_sprite = Sprite2D.new()
	shadow_sprite.name = "ShadowSprite"
	shadow_sprite.centered = true
	shadow_sprite.z_index = 90
	shadow_sprite.texture = _build_shadow_texture()
	shadow_sprite.position = Vector2(0.0, SHADOW_FEET_OFFSET_Y)
	add_child(shadow_sprite)
	move_child(shadow_sprite, 0)

func _build_shadow_texture() -> ImageTexture:
	var image := Image.create(SHADOW_TEX_SIZE.x, SHADOW_TEX_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(float(SHADOW_TEX_SIZE.x) * 0.5, float(SHADOW_TEX_SIZE.y) * 0.5)
	var radius_x := float(SHADOW_TEX_SIZE.x) * 0.5
	var radius_y := float(SHADOW_TEX_SIZE.y) * 0.5
	for y in range(SHADOW_TEX_SIZE.y):
		for x in range(SHADOW_TEX_SIZE.x):
			var dx := (float(x) - center.x) / radius_x
			var dy := (float(y) - center.y) / radius_y
			var dist := sqrt(dx * dx + dy * dy)
			if dist >= 1.0:
				continue
			var alpha := pow(1.0 - dist, 1.8) * 0.82
			image.set_pixel(x, y, Color(0, 0, 0, alpha))
	return ImageTexture.create_from_image(image)

func _update_shadow() -> void:
	if not shadow_sprite:
		return
	var height_ratio := 0.0
	if ground_y > 0.0:
		height_ratio = clampf((ground_y - position.y) / 120.0, 0.0, 1.0)
	var scale_drop := lerpf(1.0, SHADOW_MIN_SCALE, height_ratio)
	shadow_sprite.scale = shadow_base_scale * scale_drop
	var grounded_shadow_y := ground_y - position.y + SHADOW_FEET_OFFSET_Y if ground_y > 0.0 else SHADOW_FEET_OFFSET_Y
	shadow_sprite.position = Vector2(0.0, grounded_shadow_y)
	shadow_sprite.modulate = Color(0.0, 0.0, 0.0, lerpf(SHADOW_GROUND_ALPHA, SHADOW_AIR_ALPHA, height_ratio))

func _physics_process(_delta: float) -> void:
	just_landed = false

	if hitstop_frames > 0:
		hitstop_frames -= 1
		_update_shadow()
		_update_debug_overlay()
		sprite.flip_h = not facing_right
		_save_prev_ai_input()
		return

	if not control_enabled:
		_update_shadow()
		_update_debug_overlay()
		sprite.flip_h = not facing_right
		_save_prev_ai_input()
		return

	# ── Hitstun: skip all input, just count down ──────────────────────
	if is_in_hitstun:
		hitstun_timer -= 1
		if hitstun_timer <= 0:
			is_in_hitstun = false
			_set_animation("idle")
		# Apply pending pushback during hitstun
		_apply_pushback()
		_update_shadow()
		_update_debug_overlay()
		sprite.flip_h = not facing_right
		_save_prev_ai_input()
		return

	# ── Blockstun: skip all input, just count down ────────────────────
	if is_in_blockstun:
		blockstun_timer -= 1
		if blockstun_timer <= 0:
			is_in_blockstun = false
			_set_animation("idle")
		_apply_pushback()
		_update_shadow()
		_update_debug_overlay()
		sprite.flip_h = not facing_right
		_save_prev_ai_input()
		return

	# ── Knockdown: skip all input, count down then get up ─────────────
	if is_knocked_down:
		knockdown_timer -= 1
		if knockdown_timer <= 0:
			# Start getting up phase
			getting_up_timer = GETTING_UP_FRAMES
			is_knocked_down = false
			_set_animation("idle")  # no "getting up" sprite, just go to idle
		_update_shadow()
		_update_debug_overlay()
		sprite.flip_h = not facing_right
		_save_prev_ai_input()
		return

	# ── Horizontal input ──────────────────────────────────────────────
	var wants_left := _get_input("left")
	var wants_right := _get_input("right")
	var wants_down := _get_input("down")

	# ── Check for block input (back + down = crouch block, back = stand block) ──
	# "Back" = away from opponent. Only blocks when the opponent is attacking.
	# Otherwise holding back = walking backwards normally.
	is_blocking = false
	block_type = ""
	if current_attack == "" and not in_jump:
		var wants_back := (facing_right and wants_left) or (not facing_right and wants_right)
		var opponent_attacking := other_player != null and other_player.current_attack != ""
		if wants_back and opponent_attacking:
			is_blocking = true
			if wants_down:
				block_type = "crouch"
			else:
				block_type = "stand"

	# ── Jump ──────────────────────────────────────────────────────────
	if _get_input_just("up") and not in_jump:
		in_jump = true
		vel_y = JUMP_VEL
		_set_animation("jump")
		anim_frame = 0

	# ── Attacks (only when standing on ground, not crouching) ──────────
	if current_attack == "" and not is_blocking and not in_jump and not wants_down:
		if _get_input_just("punch_light"):
			_start_attack("lightPunch")
		elif _get_input_just("punch_heavy"):
			_start_attack("heavyPunch")
		elif _get_input_just("kick_light"):
			_start_attack("lightKick")
		elif _get_input_just("kick_heavy"):
			_start_attack("heavyKick")

	# ── Horizontal movement ───────────────────────────────────────────
	vel_x = 0.0
	if current_attack == "" or in_jump:
		if not is_blocking and not wants_down:
			if wants_right and not wants_left:
				vel_x = WALK_SPEED
			elif wants_left and not wants_right:
				vel_x = -WALK_SPEED

	# ── Apply movement ────────────────────────────────────────────────
	position.x += vel_x
	position.x = clampf(position.x, stage_left_bound, stage_right_bound)

	# ── One-way wall: can't walk through the other fighter ───────────
	# Only stops THIS player. Never pushes the other.
	if other_player and vel_x != 0.0 and not in_jump:
		var dist := position.x - other_player.position.x
		if absf(dist) < 85.0:
			if dist > 0:
				position.x = other_player.position.x + 85.0
			else:
				position.x = other_player.position.x - 85.0
			position.x = clampf(position.x, stage_left_bound, stage_right_bound)

	# ── Jump physics ──────────────────────────────────────────────────
	if in_jump:
		position.y += vel_y
		vel_y += GRAVITY

		# Match JS jump visual: extended while rising/falling, tucked near apex.
		var jump_frame := 0
		if vel_y >= -2.0 and vel_y <= 2.0:
			jump_frame = 1
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("jump") and sprite.sprite_frames.get_frame_count("jump") > jump_frame:
			sprite.frame = jump_frame
			anim_frame = jump_frame

		if position.y >= ground_y:
			position.y = ground_y
			vel_y = 0.0
			in_jump = false
			just_landed = true
			SoundManager.play_landing()
			if current_attack != "":
				pass
			elif wants_down:
				_set_animation("crouching")
			elif vel_x != 0.0:
				_set_animation("walking")
			else:
				_set_animation("idle")

	# ── Attack timing ─────────────────────────────────────────────────
	if current_attack != "":
		attack_frame += 1
		var atk: Dictionary = get_attack_data(current_attack)
		var total_frames: int = atk.startup + atk.active + atk.recovery
		if attack_frame >= total_frames:
			current_attack = ""
			attack_frame = 0
			has_hit = false

	# ── Visual state selection ────────────────────────────────────────
	if current_attack != "":
		pass  # keep attack animation
	elif in_jump:
		pass  # jump frames managed manually above
	elif is_blocking:
		if block_type == "crouch":
			_set_animation("blocking_crouch")
		else:
			_set_animation("blocking_stand")
	elif wants_down:
		_set_animation("crouching")
	elif vel_x != 0.0:
		_set_animation("walking")
	else:
		_set_animation("idle")

	_update_shadow()

	# ── Animation update (not for jump — frames are manual) ───────────
	if not in_jump:
		_update_animation()

	# ── Apply pending pushback ────────────────────────────────────────
	_apply_pushback()

	_update_debug_overlay()
	sprite.flip_h = not facing_right
	_save_prev_ai_input()

# ── Input helpers ─────────────────────────────────────────────────────

func _save_prev_ai_input() -> void:
	_prev_ai_input = ai_input.duplicate()

func _get_input(action: String) -> bool:
	if not ai_input.is_empty() and ai_input.has(action):
		return ai_input[action]
	return Input.is_action_pressed("p%d_%s" % [player_index, action])

func _get_input_just(action: String) -> bool:
	if not ai_input.is_empty() and ai_input.has(action):
		var is_now: bool = ai_input[action]
		var was_before: bool = _prev_ai_input.get(action, false)
		return is_now and not was_before
	return Input.is_action_just_pressed("p%d_%s" % [player_index, action])

func reset_for_new_round(spawn_x: float, spawn_y: float, face_right: bool) -> void:
	health = MAX_HEALTH
	position = Vector2(spawn_x, spawn_y)
	ground_y = spawn_y
	vel_x = 0.0
	vel_y = 0.0
	hitstop_frames = 0
	in_jump = false
	just_landed = false
	current_attack = ""
	attack_frame = 0
	has_hit = false
	hitstun_timer = 0
	blockstun_timer = 0
	is_in_hitstun = false
	is_in_blockstun = false
	pending_pushback = 0.0
	knockdown_timer = 0
	is_knocked_down = false
	getting_up_timer = 0
	is_blocking = false
	block_type = ""
	pushback_dir = 0.0
	control_enabled = true
	ai_input = {}
	_prev_ai_input = {}
	facing_right = face_right
	_apply_character_visuals()
	_set_animation("idle")
	_update_shadow()

# ── Combat methods ────────────────────────────────────────────────────

## Returns true if the attack is in its "active" frames (can hit)
func is_attack_active() -> bool:
	if current_attack == "":
		return false
	var atk: Dictionary = get_attack_data(current_attack)
	var active_start: int = atk.startup
	var active_end: int = atk.startup + atk.active - 1
	return attack_frame >= active_start and attack_frame <= active_end

func get_attack_data(attack_name: String) -> Dictionary:
	if character_name.to_lower() == "teknium" and TEKNIUM_ATTACKS.has(attack_name):
		return TEKNIUM_ATTACKS[attack_name]
	return ATTACKS[attack_name]

func get_attack_hitbox_data(attack_name: String) -> Rect2:
	if character_name.to_lower() == "teknium" and TEKNIUM_ATTACK_HITBOX.has(attack_name):
		return TEKNIUM_ATTACK_HITBOX[attack_name]
	return ATTACK_HITBOX.get(attack_name, Rect2())

## Returns the attack hitbox in world coordinates
func get_attack_hitbox() -> Rect2:
	if current_attack == "":
		return Rect2()
	var base: Rect2 = get_attack_hitbox_data(current_attack)
	if base.size.x == 0:
		return Rect2()
	var dir: float = 1.0 if facing_right else -1.0
	# When facing left, mirror the hitbox: x offset becomes -(base.x + base.w)
	var offset_x: float = base.position.x if dir > 0 else -(base.position.x + base.size.x)
	return Rect2(position.x + offset_x, position.y + base.position.y, base.size.x, base.size.y)

## Returns the hurtbox in world coordinates
func get_hurtbox() -> Rect2:
	return Rect2(position.x + HURTBOX.position.x, position.y + HURTBOX.position.y, HURTBOX.size.x, HURTBOX.size.y)

func apply_hitstop(frames: int) -> void:
	hitstop_frames = maxi(hitstop_frames, frames)

## Called when this player gets hit by an attack
func apply_hit(damage: int, hitstun_frames: int, pushback: float, knockdown: bool) -> void:
	health = max(0, health - damage)
	has_hit = true  # mark attacker's hit as connected (set by caller, but safe to double-set)
	var was_fatal := health <= 0

	if knockdown:
		is_knocked_down = true
		knockdown_timer = KNOCKDOWN_FRAMES
		is_in_hitstun = false
		_set_animation("ko" if was_fatal else "abdomen_hit")
	else:
		is_in_hitstun = true
		hitstun_timer = hitstun_frames
		_set_animation("ko" if was_fatal else "abdomen_hit")

	pending_pushback = pushback

	if health <= 0:
		died.emit()

	took_damage.emit(damage)

## Called when this player blocks an attack
func apply_block(blockstun_frames: int, pushback: float) -> void:
	is_in_blockstun = true
	blockstun_timer = blockstun_frames
	pending_pushback = pushback

	# Show blocking animation
	if block_type == "crouch":
		_set_animation("blocking_crouch")
	else:
		_set_animation("blocking_stand")

## Apply pending pushback — called each physics frame during hitstun/blockstun
func _apply_pushback() -> void:
	if pending_pushback > 0.0 and pushback_dir != 0.0:
		position.x += pending_pushback * pushback_dir
		position.x = clampf(position.x, stage_left_bound, stage_right_bound)
		pending_pushback = 0.0
		pushback_dir = 0.0

# ── Attack helper ─────────────────────────────────────────────────────

func _start_attack(attack_name: String) -> void:
	current_attack = attack_name
	attack_frame = 0
	has_hit = false

	var anim_map: Dictionary = {
		"lightPunch": "lightpunch",
		"heavyPunch": "heavypunch",
		"lightKick":  "lightkick",
		"heavyKick":  "heavykick",
	}
	_set_animation(anim_map[attack_name])
	SoundManager.play_attack_swing(attack_name)

# ── Animation (manual frame advance, matching JS) ────────────────────

func _set_animation(anim_name: String) -> void:
	if current_anim != anim_name:
		current_anim = anim_name
		anim_frame = 0
		anim_timer = 0
		_safe_play(anim_name)

func _safe_play(anim_name: String) -> void:
	# Safely play an animation — guards against crashes from missing/empty anims
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name) and sprite.sprite_frames.get_frame_count(anim_name) > 0:
		sprite.play(anim_name)
		sprite.frame = 0
	else:
		push_warning("Player %d: tried to play missing/empty animation '%s'" % [player_index, anim_name])

func _update_animation() -> void:
	# Crouch holding/exiting don't advance frames (JS: crouchPhase check)
	if crouch_phase == "holding" or crouch_phase == "exiting":
		return
	# Hitstun/blockstun animations advance but don't loop
	if is_in_hitstun or is_in_blockstun:
		# Let the animation play out naturally via AnimatedSprite2D
		return

	var speed: int = ANIM_SPEED.get(current_anim, 6)
	anim_timer += 1
	if anim_timer >= speed:
		anim_timer = 0
		anim_frame += 1

	# For AnimatedSprite2D, let it auto-advance.
	# Sync the frame counter for debug overlay consistency.
	var looping_anims: Array = ["idle", "walking", "victory_loop"]
	if not looping_anims.has(current_anim):
		# Clamp to last frame for one-shot anims
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(current_anim):
			var frame_count: int = sprite.sprite_frames.get_frame_count(current_anim)
			if anim_frame >= frame_count:
				anim_frame = frame_count - 1

func _on_animation_finished() -> void:
	if current_anim == "victory" and sprite.sprite_frames and sprite.sprite_frames.has_animation("victory_loop") and sprite.sprite_frames.get_frame_count("victory_loop") > 0:
		_set_animation("victory_loop")
		return
	# One-shot animations end naturally — state handles transitions

# ── Debug overlay ─────────────────────────────────────────────────────

func _update_debug_overlay() -> void:
	if debug_overlay:
		var state_str: String = "idle"
		if is_in_hitstun:
			state_str = "HITSTUN(%d)" % hitstun_timer
		elif is_in_blockstun:
			state_str = "BLOCKSTUN(%d)" % blockstun_timer
		elif is_knocked_down:
			state_str = "KNOCKDOWN(%d)" % knockdown_timer
		elif current_attack != "":
			state_str = "ATK:%s[%d]" % [current_attack, attack_frame]
		elif in_jump:
			state_str = "JUMP"
		elif is_blocking:
			state_str = "BLOCK:%s" % block_type
		debug_overlay.text = "P%d hp=%d %s y=%.1f vy=%.2f anim=%s" % [player_index, health, state_str, position.y, vel_y, current_anim]
