extends Control

## Main game controller — Stoat Fighter 2 Godot port
## Coordinates game loop, camera, fighters, HUD, combat

@onready var p1: Player = %Player1
@onready var p2: Player = %Player2
@onready var camera: Camera2D = %Camera2D
@onready var debug_label: Label = %DebugLabel

## HUD nodes (created programmatically)
var p1_health_bar: ColorRect = null
var p2_health_bar: ColorRect = null
var p1_health_bg: ColorRect = null
var p2_health_bg: ColorRect = null
var p1_health_border: ColorRect = null
var p2_health_border: ColorRect = null
var p1_health_label: Label = null
var p2_health_label: Label = null

## Camera config
const CAMERA_ZOOM := Vector2(1.0, 1.0)
const CAMERA_SMOOTHING := 8.0
const CAMERA_Y := 144.0

## HUD config (from JS config)
const HUD_BAR_WIDTH: float = 180.0
const HUD_BAR_HEIGHT: float = 14.0
const HUD_BAR_Y: float = 16.0
const HUD_P1_BAR_X: float = 40.0
const HUD_P2_BAR_X: float = 292.0  # SCREEN_WIDTH - 40 - 180 = 292

## Body collision minimum distance (from JS: minDist=55)
const MIN_BODY_DIST: float = 55.0

var debug_timer := 0.0

func _ready() -> void:
	print("Stoat Fighter 2 — Godot port initialized")
	# Set ground_y on players
	if p1:
		p1.ground_y = p1.position.y
		print("Main: p1.ground_y set to %.1f" % p1.ground_y)
	if p2:
		p2.ground_y = p2.position.y
		print("Main: p2.ground_y set to %.1f" % p2.ground_y)

	# Configure camera
	camera.zoom = CAMERA_ZOOM
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = CAMERA_SMOOTHING
	camera.make_current()

	# Create HUD
	_create_hud()

	# Show debug info for 3 seconds
	if debug_label:
		debug_timer = 3.0

func _process(delta: float) -> void:
	# Combat processing
	if p1 and p2:
		_process_combat(p1, p2)
		_process_combat(p2, p1)

	# Auto-facing: players always face each other
	if p1 and p2:
		if p1.position.x < p2.position.x:
			p1.facing_right = true
			p2.facing_right = false
		else:
			p1.facing_right = false
			p2.facing_right = true

	# Body collision push-apart
	if p1 and p2:
		_push_apart_bodies()

	# Camera tracking (midpoint between fighters)
	if p1 and p2:
		var mid_x := (p1.position.x + p2.position.x) / 2.0
		camera.position.x = clampf(mid_x, 140.0 + 256.0, 682.0 - 256.0)
		camera.position.y = CAMERA_Y

	# Update HUD
	_update_hud()

	# Debug label
	_update_debug_label()
	if debug_timer > 0:
		debug_timer -= delta
		if debug_timer <= 0 and debug_label:
			debug_label.visible = false

# ── Combat processing (port of JS combat.js) ──────────────────────────

func _process_combat(attacker: Player, defender: Player) -> void:
	if not attacker.is_attack_active():
		return
	if attacker.has_hit:
		return

	var atk_hitbox: Rect2 = attacker.get_attack_hitbox()
	var def_hurtbox: Rect2 = defender.get_hurtbox()

	if not _box_overlap(atk_hitbox, def_hurtbox):
		return

	var atk_data: Dictionary = attacker.ATTACKS[attacker.current_attack]
	attacker.has_hit = true

	# Pushback direction: defender pushed AWAY from attacker
	var push_dir: float = 1.0 if defender.position.x > attacker.position.x else -1.0

	# Check if defender is blocking
	var blocked := false
	if defender.is_blocking:
		if defender.block_type == "stand" and atk_data.type == "low":
			blocked = false  # Low attack goes under standing block
		elif defender.block_type == "crouch" and atk_data.get("type", "mid") == "high":
			blocked = false  # High attack hits crouching (future-proof)
		else:
			blocked = true

	if blocked:
		# Blocked hit — reduced pushback
		defender.pushback_dir = push_dir
		defender.apply_block(atk_data.blockstun, int(atk_data.pushback * 0.5))
	else:
		# Clean hit
		var knockdown: bool = atk_data.get("knockdown", false)
		defender.pushback_dir = push_dir
		defender.apply_hit(atk_data.damage, atk_data.hitstun, atk_data.pushback, knockdown)

func _box_overlap(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.position.x + b.size.x and \
	       a.position.x + a.size.x > b.position.x and \
	       a.position.y < b.position.y + b.size.y and \
	       a.position.y + a.size.y > b.position.y

# ── Body collision push-apart (from JS main.js) ──────────────────────

func _push_apart_bodies() -> void:
	var p1_on_ground: bool = p1.position.y >= p1.ground_y
	var p2_on_ground: bool = p2.position.y >= p2.ground_y
	if not (p1_on_ground and p2_on_ground):
		return

	var dist: float = absf(p1.position.x - p2.position.x)
	if dist < MIN_BODY_DIST:
		var overlap: float = MIN_BODY_DIST - dist
		var dir: float = -1.0 if p1.position.x < p2.position.x else 1.0
		p1.position.x += dir * overlap * 0.5
		p2.position.x -= dir * overlap * 0.5
		# Clamp both to stage bounds
		p1.position.x = clampf(p1.position.x, p1.STAGE_LEFT, p1.STAGE_RIGHT)
		p2.position.x = clampf(p2.position.x, p2.STAGE_LEFT, p2.STAGE_RIGHT)

# ── HUD ───────────────────────────────────────────────────────────────

func _create_hud() -> void:
	# We create HUD as children of the root Control (outside SubViewport)
	# so it's always visible at screen coordinates, not world coordinates.
	# This matches the JS approach where HUD draws on the canvas directly.

	# Health bar backgrounds
	p1_health_bg = ColorRect.new()
	p1_health_bg.position = Vector2(HUD_P1_BAR_X, HUD_BAR_Y)
	p1_health_bg.size = Vector2(HUD_BAR_WIDTH, HUD_BAR_HEIGHT)
	p1_health_bg.color = Color(0.25, 0.25, 0.25)
	add_child(p1_health_bg)

	p2_health_bg = ColorRect.new()
	p2_health_bg.position = Vector2(HUD_P2_BAR_X, HUD_BAR_Y)
	p2_health_bg.size = Vector2(HUD_BAR_WIDTH, HUD_BAR_HEIGHT)
	p2_health_bg.color = Color(0.25, 0.25, 0.25)
	add_child(p2_health_bg)

	# Health bar fills
	p1_health_bar = ColorRect.new()
	p1_health_bar.position = Vector2(HUD_P1_BAR_X, HUD_BAR_Y)
	p1_health_bar.size = Vector2(HUD_BAR_WIDTH, HUD_BAR_HEIGHT)
	p1_health_bar.color = Color.GREEN
	add_child(p1_health_bar)

	p2_health_bar = ColorRect.new()
	p2_health_bar.position = Vector2(HUD_P2_BAR_X, HUD_BAR_Y)
	p2_health_bar.size = Vector2(HUD_BAR_WIDTH, HUD_BAR_HEIGHT)
	p2_health_bar.color = Color.GREEN
	add_child(p2_health_bar)

	# Health text labels
	p1_health_label = Label.new()
	p1_health_label.position = Vector2(HUD_P1_BAR_X, HUD_BAR_Y + HUD_BAR_HEIGHT + 2)
	p1_health_label.add_theme_font_size_override("font_size", 10)
	p1_health_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(p1_health_label)

	p2_health_label = Label.new()
	p2_health_label.position = Vector2(HUD_P2_BAR_X, HUD_BAR_Y + HUD_BAR_HEIGHT + 2)
	p2_health_label.add_theme_font_size_override("font_size", 10)
	p2_health_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(p2_health_label)

func _update_hud() -> void:
	if not p1 or not p2:
		return

	# P1 health bar (fills left to right)
	var p1_ratio: float = float(p1.health) / float(p1.MAX_HEALTH)
	p1_health_bar.size.x = HUD_BAR_WIDTH * p1_ratio
	p1_health_bar.color = _health_color(p1_ratio)
	p1_health_label.text = "P1: %d" % p1.health

	# P2 health bar (fills right to left — standard fighting game convention)
	var p2_ratio: float = float(p2.health) / float(p2.MAX_HEALTH)
	p2_health_bar.size.x = HUD_BAR_WIDTH * p2_ratio
	# P2 bar anchors from the right
	p2_health_bar.position.x = HUD_P2_BAR_X + HUD_BAR_WIDTH * (1.0 - p2_ratio)
	p2_health_bar.color = _health_color(p2_ratio)
	p2_health_label.text = "P2: %d" % p2.health

func _health_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color.GREEN
	elif ratio > 0.25:
		return Color.YELLOW
	else:
		return Color.RED

# ── Debug ─────────────────────────────────────────────────────────────

func _update_debug_label() -> void:
	if not debug_label:
		return
	var lines: Array[String] = []
	if p1:
		var sprite1 := p1.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		lines.append("P1 pos=(%.0f, %.0f) hp=%d atk=%s hitstun=%s block=%s" % [
			p1.position.x, p1.position.y, p1.health,
			p1.current_attack if p1.current_attack else "-",
			str(p1.hitstun_timer) if p1.is_in_hitstun else "-",
			p1.block_type if p1.is_blocking else "-"])
	else:
		lines.append("P1 node=NULL")
	if p2:
		var sprite2 := p2.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		lines.append("P2 pos=(%.0f, %.0f) hp=%d atk=%s hitstun=%s block=%s" % [
			p2.position.x, p2.position.y, p2.health,
			p2.current_attack if p2.current_attack else "-",
			str(p2.hitstun_timer) if p2.is_in_hitstun else "-",
			p2.block_type if p2.is_blocking else "-"])
	else:
		lines.append("P2 node=NULL")
	debug_label.visible = true
	debug_label.text = "\n".join(lines)
