extends Node2D
class_name Player

## Player — 1:1 port of JS fighter.js
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

# ── Animation speeds (JS frames per sprite-frame) ────────────────────
const ANIM_SPEED: Dictionary = {
	"idle":       8,
	"walking":    6,
	"jump":       5,
	"crouching":  4,
	"lightpunch": 4,
	"heavypunch": 5,
	"lightkick":  4,
	"heavykick":  5,
	"victory":    8,
}

# ── Exports ───────────────────────────────────────────────────────────
@export var player_index: int = 1
@export var facing_right: bool = true

# ── Public state ──────────────────────────────────────────────────────
var health: int = MAX_HEALTH
var vel_x: float = 0.0
var vel_y: float = 0.0
var ground_y: float = 0.0  # set by Main on spawn
var just_landed: bool = false
var in_jump: bool = false

# Attack state
var current_attack: String = ""
var attack_frame: int = 0
var has_hit: bool = false

# Animation state (manual, matching JS)
var current_anim: String = "idle"
var anim_frame: int = 0
var anim_timer: int = 0

# Crouch sub-state
var crouch_phase: String = ""  # "entering", "holding", "exiting"

# ── Node refs ─────────────────────────────────────────────────────────
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: StateMachine = $StateMachine

# Debug overlay — created programmatically
var debug_overlay: Label = null

# ── Signals ───────────────────────────────────────────────────────────
signal took_damage(amount: int)
signal died

func _ready() -> void:
	health = MAX_HEALTH
	# Build sprite frames at runtime
	var frames := SpriteLoader.build_prototype_frames()
	sprite.sprite_frames = frames
	print("Player %d _ready: frames has %d anims, names=%s" % [player_index, frames.get_animation_names().size(), str(frames.get_animation_names())])
	print("Player %d _ready: idle frame_count=%d" % [player_index, frames.get_frame_count("idle")])
	if frames.get_frame_count("idle") > 0:
		var tex = frames.get_frame_texture("idle", 0)
		print("Player %d _ready: idle[0] texture=%s size=%s" % [player_index, str(tex), str(tex.get_size()) if tex else "NULL"])
	sprite.play("idle")
	sprite.animation_finished.connect(_on_animation_finished)
	print("Player %d _ready: pos=%s ground_y=%s state=%d vel_y=%s" % [player_index, str(position), str(ground_y), state_machine.current_state, str(vel_y)])
	
	# Create in-game debug overlay — as child of PLAYER, not sprite
	# So it survives sprite visibility issues
	debug_overlay = Label.new()
	debug_overlay.position = Vector2(-80, -220)
	debug_overlay.add_theme_font_size_override("font_size", 10)
	debug_overlay.add_theme_color_override("font_color", Color.YELLOW)
	debug_overlay.z_index = 999
	add_child(debug_overlay)

func _physics_process(_delta: float) -> void:
	just_landed = false

	# Horizontal input is allowed unless a grounded attack locks us in place.
	var wants_left := Input.is_action_pressed("p%d_left" % player_index)
	var wants_right := Input.is_action_pressed("p%d_right" % player_index)
	var wants_down := Input.is_action_pressed("p%d_down" % player_index)

	# Start jump from grounded state only. Keep the known-good safe jump physics.
	if Input.is_action_just_pressed("p%d_up" % player_index) and not in_jump:
		in_jump = true
		vel_y = JUMP_VEL
		_set_animation("jump")
		anim_frame = 0
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("jump") and sprite.sprite_frames.get_frame_count("jump") > 0:
			sprite.play("jump")
			sprite.frame = 0

	# Start attacks only when not already attacking.
	if current_attack == "":
		if Input.is_action_just_pressed("p%d_punch_light" % player_index):
			current_attack = "lightPunch"
			attack_frame = 0
			has_hit = false
			_set_animation("lightpunch")
		elif Input.is_action_just_pressed("p%d_punch_heavy" % player_index):
			current_attack = "heavyPunch"
			attack_frame = 0
			has_hit = false
			_set_animation("heavypunch")
		elif Input.is_action_just_pressed("p%d_kick_light" % player_index):
			current_attack = "lightKick"
			attack_frame = 0
			has_hit = false
			_set_animation("lightkick")
		elif Input.is_action_just_pressed("p%d_kick_heavy" % player_index):
			current_attack = "heavyKick"
			attack_frame = 0
			has_hit = false
			_set_animation("heavykick")

	# Horizontal movement.
	vel_x = 0.0
	if current_attack == "" or in_jump:
		if wants_right and not wants_left:
			vel_x = WALK_SPEED
			facing_right = true
		elif wants_left and not wants_right:
			vel_x = -WALK_SPEED
			facing_right = false

	# Apply movement.
	position.x += vel_x
	position.x = clampf(position.x, STAGE_LEFT, STAGE_RIGHT)

	# Safe jump physics.
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
			# Return to whatever grounded visual is appropriate.
			if current_attack != "":
				pass
			elif wants_down:
				_set_animation("crouching")
			elif vel_x != 0.0:
				_set_animation("walking")
			else:
				_set_animation("idle")

	# Attack timing.
	if current_attack != "":
		attack_frame += 1
		var atk: Dictionary = ATTACKS[current_attack]
		var total_frames: int = atk.startup + atk.active + atk.recovery
		if attack_frame >= total_frames:
			current_attack = ""
			attack_frame = 0
			has_hit = false

	# Visual state selection. Do NOT play jump animation yet — that was the crash path.
	if current_attack != "":
		pass # keep whichever attack animation was started
	elif in_jump:
		pass # keep current grounded anim for now; jump visuals will return next step
	elif wants_down:
		_set_animation("crouching")
	elif vel_x != 0.0:
		_set_animation("walking")
	else:
		_set_animation("idle")

	# Keep attack/grounded anims advancing; jump frames are controlled manually above.
	if not in_jump:
		_update_animation()

	# Keep debug visible with raw physics values.
	if debug_overlay:
		debug_overlay.text = "P%d y=%.1f vy=%.2f jump=%s atk=%s anim=%s" % [player_index, position.y, vel_y, str(in_jump), current_attack, current_anim]

	sprite.flip_h = not facing_right

# ── State update methods (matching JS fighter.js) ────────────────────

func _update_idle() -> void:
	vel_x = 0

	# Attacks take priority
	if _check_attacks():
		return

	# Jump (just-pressed, matching JS: this.justPressed('up'))
	if Input.is_action_just_pressed("p%d_up" % player_index):
		vel_y = JUMP_VEL
		# Bypass state machine entirely — set state directly
		state_machine.current_state = StateMachine.State.JUMP
		state_machine.state_frame = 0
		current_anim = "jump"
		anim_frame = 0
		return

	# Crouch
	if Input.is_action_pressed("p%d_down" % player_index):
		_set_state(StateMachine.State.CROUCH)
		crouch_phase = "entering"
		anim_frame = 0
		anim_timer = 0
		return

	# Walk
	if Input.is_action_pressed("p%d_right" % player_index):
		vel_x = WALK_SPEED
		facing_right = true
		_set_state(StateMachine.State.WALK_RIGHT)
		return
	if Input.is_action_pressed("p%d_left" % player_index):
		vel_x = -WALK_SPEED
		facing_right = false
		_set_state(StateMachine.State.WALK_LEFT)
		return


func _update_walk_right() -> void:
	if _check_attacks():
		vel_x = 0
		return

	if Input.is_action_just_pressed("p%d_up" % player_index):
		vel_y = JUMP_VEL
		vel_x = -WALK_SPEED if Input.is_action_pressed("p%d_left" % player_index) else WALK_SPEED
		_set_state(StateMachine.State.JUMP)
		anim_frame = 0
		return

	if Input.is_action_pressed("p%d_down" % player_index):
		vel_x = 0
		_set_state(StateMachine.State.CROUCH)
		crouch_phase = "entering"
		anim_frame = 0
		anim_timer = 0
		return

	if Input.is_action_pressed("p%d_right" % player_index):
		vel_x = WALK_SPEED
		facing_right = true
		return
	if Input.is_action_pressed("p%d_left" % player_index):
		vel_x = -WALK_SPEED
		facing_right = false
		_set_state(StateMachine.State.WALK_LEFT)
		return

	vel_x = 0
	_set_state(StateMachine.State.IDLE)


func _update_walk_left() -> void:
	if _check_attacks():
		vel_x = 0
		return

	if Input.is_action_just_pressed("p%d_up" % player_index):
		vel_y = JUMP_VEL
		vel_x = WALK_SPEED if Input.is_action_pressed("p%d_right" % player_index) else -WALK_SPEED
		_set_state(StateMachine.State.JUMP)
		anim_frame = 0
		return

	if Input.is_action_pressed("p%d_down" % player_index):
		vel_x = 0
		_set_state(StateMachine.State.CROUCH)
		crouch_phase = "entering"
		anim_frame = 0
		anim_timer = 0
		return

	if Input.is_action_pressed("p%d_left" % player_index):
		vel_x = -WALK_SPEED
		facing_right = false
		return
	if Input.is_action_pressed("p%d_right" % player_index):
		vel_x = WALK_SPEED
		facing_right = true
		_set_state(StateMachine.State.WALK_RIGHT)
		return

	vel_x = 0
	_set_state(StateMachine.State.IDLE)


func _update_crouch() -> void:
	vel_x = 0

	if crouch_phase == "entering":
		if anim_frame >= 1:
			crouch_phase = "holding"
			anim_frame = 1
			anim_timer = 0
	elif crouch_phase == "holding":
		if not Input.is_action_pressed("p%d_down" % player_index):
			crouch_phase = "exiting"
			state_machine.state_frame = 0
			anim_frame = 0
	elif crouch_phase == "exiting":
		if state_machine.state_frame >= ANIM_SPEED.crouching:
			crouch_phase = ""
			_set_state(StateMachine.State.IDLE)


func _update_jump() -> void:
	# Allow horizontal movement during jump
	if Input.is_action_pressed("p%d_right" % player_index):
		vel_x = WALK_SPEED
		facing_right = true
	elif Input.is_action_pressed("p%d_left" % player_index):
		vel_x = -WALK_SPEED
		facing_right = false
	# Air attacks could go here in future


func _update_attack() -> void:
	if position.y >= ground_y:
		vel_x = 0
	attack_frame += 1

	var atk: Dictionary = ATTACKS[current_attack]
	var total_frames: int = atk.startup + atk.active + atk.recovery

	if attack_frame >= total_frames:
		current_attack = ""
		attack_frame = 0
		has_hit = false
		if position.y < ground_y:
			_set_state(StateMachine.State.JUMP)
			state_machine.state_frame = 0
		else:
			_set_state(StateMachine.State.IDLE)


# ── Helper: check attack inputs ──────────────────────────────────────
func _check_attacks() -> bool:
	if Input.is_action_just_pressed("p%d_punch_light" % player_index):
		_start_attack("lightPunch")
		return true
	if Input.is_action_just_pressed("p%d_punch_heavy" % player_index):
		_start_attack("heavyPunch")
		return true
	if Input.is_action_just_pressed("p%d_kick_light" % player_index):
		_start_attack("lightKick")
		return true
	if Input.is_action_just_pressed("p%d_kick_heavy" % player_index):
		_start_attack("heavyKick")
		return true
	return false


func _start_attack(attack_name: String) -> void:
	state_machine.transition_to(StateMachine.State.ATTACK)
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


# ── State transition ─────────────────────────────────────────────────
func _set_state(new_state: StateMachine.State) -> void:
	state_machine.transition_to(new_state)

	# JS setState anim mapping
	var anim_map: Dictionary = {
		StateMachine.State.IDLE:       "idle",
		StateMachine.State.WALK_RIGHT: "walking",
		StateMachine.State.WALK_LEFT:  "walking",
		StateMachine.State.CROUCH:     "crouching",
		StateMachine.State.JUMP:       "jump",
	}
	if anim_map.has(new_state):
		_set_animation(anim_map[new_state])


# ── Animation (manual frame advance, matching JS) ────────────────────
func _set_animation(anim_name: String) -> void:
	if current_anim != anim_name:
		current_anim = anim_name
		anim_frame = 0
		anim_timer = 0
		# Safety: only play if animation exists and has frames
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name) and sprite.sprite_frames.get_frame_count(anim_name) > 0:
			sprite.play(anim_name)
			sprite.frame = 0
		else:
			push_warning("Player %d: tried to play missing/empty animation '%s'" % [player_index, anim_name])


func _update_animation() -> void:
	# Crouch holding/exiting don't advance frames (JS: crouchPhase check)
	if state_machine.current_state == StateMachine.State.CROUCH and \
	   (crouch_phase == "holding" or crouch_phase == "exiting"):
		return

	var speed: int = ANIM_SPEED.get(current_anim, 6)
	anim_timer += 1
	if anim_timer >= speed:
		anim_timer = 0
		anim_frame += 1

	# For AnimatedSprite2D, just let it auto-advance —
	# but sync the frame counter for debug overlay consistency.
	# We also need to handle looping vs clamping:
	var looping_anims: Array = ["idle", "walking"]
	if looping_anims.has(current_anim):
		# Let AnimatedSprite2D loop naturally
		pass
	else:
		# Clamp to last frame for one-shot anims (JS: Math.min)
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(current_anim):
			var frame_count: int = sprite.sprite_frames.get_frame_count(current_anim)
			if anim_frame >= frame_count:
				anim_frame = frame_count - 1


func _on_animation_finished() -> void:
	# One-shot animations end naturally — state machine handles transitions
	pass
