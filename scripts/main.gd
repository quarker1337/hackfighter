extends Control

## Main game controller — Stoat Fighter 2 Godot port
## Coordinates game loop, camera, fighters, HUD, combat

@onready var p1: Player = %Player1
@onready var p2: Player = %Player2
@onready var camera: Camera2D = %Camera2D
@onready var debug_label: Label = $DebugLabel
@onready var stage: Node = %Stage
@onready var game_view: SubViewportContainer = $SubViewportContainer
@onready var game_root: Node2D = $SubViewportContainer/GameViewport/GameRoot

var ai: SimpleAI = null

enum AppState { MENU, FIGHTER_SELECT, CONTROLS, OPTIONS, GAME }
var app_state: AppState = AppState.MENU
var menu_index: int = 0
var fighter_select_index: int = 0
var option_difficulty_index: int = 1
const CPU_DIFFICULTIES := ["EASY", "NORMAL", "HARD"]
const FIGHTER_PLACEHOLDERS := ["TEKNIUM", "NOUSGIRL", "LOBSTER"]
var selected_fighter_name: String = "TEKNIUM"

enum RoundState { PLAYING, ROUND_OVER, MATCH_OVER }
var round_state: RoundState = RoundState.PLAYING
const ROUND_TIME: float = 99.0
const ROUNDS_TO_WIN: int = 2
const P1_SPAWN_X: float = 270.0
const P2_SPAWN_X: float = 550.0
var round_time_left: float = ROUND_TIME
var round_over_timer: float = 0.0
var intro_active: bool = false
var intro_token: int = 0
var current_round: int = 1
var p1_round_wins: int = 0
var p2_round_wins: int = 0

const HITSTOP_ON_HIT: int = 5
const HITSTOP_ON_BLOCK: int = 3

## HUD nodes (created programmatically)
## HealthBar.gd renders labels like P1 — TEKNIUM and AI — TEKNIUM.
const HEALTH_BAR_SCENE := preload("res://scenes/HealthBar.tscn")
const HUD_FONT := preload("res://fonts/DejaVuSansMono.ttf")
var hud_layer: CanvasLayer = null
var hud_root: Control = null
var p1_health_widget: Control = null
var p2_health_widget: Control = null
var timer_bg: TextureRect = null
var timer_label: Label = null
var timer_word_label: Label = null
var announcement_label: Label = null
var result_panel_bg: ColorRect = null
var result_panel_border: ColorRect = null
var result_title_label: Label = null
var result_status_label: Label = null
var result_winner_label: Label = null
var result_prompt_label: Label = null
var menu_overlay: ColorRect = null
var menu_panel_back: ColorRect = null
var menu_panel: ColorRect = null
var menu_scanlines: Array[ColorRect] = []
var menu_title_label: Label = null
var menu_subtitle_label: Label = null
var menu_body_label: Label = null
var menu_hint_label: Label = null
var fighter_card_backs: Array[ColorRect] = []
var fighter_card_fills: Array[ColorRect] = []
var fighter_card_labels: Array[Label] = []
var fighter_card_tags: Array[Label] = []
var fighter_select_desc_label: Label = null
var menu_fx_time: float = 0.0
var p1_round_dots: Array[ColorRect] = []
var p2_round_dots: Array[ColorRect] = []

## Camera config
const VIEW_ZOOM := 1.03
const CAMERA_ZOOM := Vector2(VIEW_ZOOM, VIEW_ZOOM)
const CAMERA_SMOOTHING := 8.0
const CAMERA_LEFT_MARGIN := 150.0
const CAMERA_RIGHT_MARGIN := 150.0
const CAMERA_PAN_SPEED := 6.0
const CAMERA_Y := 144.0
const MAX_FIGHTER_SEPARATION := 420.0
const SCREEN_WIDTH := 512.0
const SCREEN_HEIGHT := 288.0
const STAGE_FLOOR_WIDTH := 682.0
const VISIBLE_WIDTH := SCREEN_WIDTH / VIEW_ZOOM

## HUD config (from JS config)
const HUD_BAR_WIDTH: float = 180.0
const HUD_BAR_HEIGHT: float = 14.0
const HUD_BAR_Y: float = 16.0
const HUD_P1_BAR_X: float = 40.0
const HUD_P2_BAR_X: float = 292.0  # SCREEN_WIDTH - 40 - 180 = 292
const HUD_TIMER_X: float = 242.0
const HUD_TIMER_Y: float = 16.0
const HUD_DOT_Y: float = 36.0
const HUD_DOT_SPACING: float = 14.0
const HUD_DOT_SIZE: float = 8.0
const HEALTH_LAG_SPEED: float = 180.0
const CAMERA_SHAKE_DECAY: float = 10.0
const IMPACT_FLASH_DECAY: float = 8.0

var debug_timer := 0.0
var debug_ui_enabled := false
var debug_toggle_latch := false
var p1_display_health: float = 1000.0
var p2_display_health: float = 1000.0
var camera_shake_timer: float = 0.0
var camera_shake_strength: float = 0.0
var impact_flash: ColorRect = null
var impact_flash_alpha: float = 0.0
var fx_layer: Node2D = null
var active_hit_fx: Array[Dictionary] = []

const HIT_FX_LIGHT_DURATION: float = 0.12
const HIT_FX_HEAVY_DURATION: float = 0.18
const HIT_FX_BLOCK_DURATION: float = 0.10

func _ready() -> void:
	print("Stoat Fighter 2 — Godot port initialized")
	ai = SimpleAI.new()
	# Set ground_y on players and cross-reference each other
	if p1:
		p1.ground_y = p1.position.y
		print("Main: p1.ground_y set to %.1f" % p1.ground_y)
	if p2:
		p2.ground_y = p2.position.y
		print("Main: p2.ground_y set to %.1f" % p2.ground_y)
	if p1 and p2:
		p1.other_player = p2
		p2.other_player = p1

	# Configure camera
	camera.zoom = CAMERA_ZOOM
	camera.position_smoothing_enabled = false
	camera.position_smoothing_speed = CAMERA_SMOOTHING
	camera.make_current()

	# Keep gameplay pixel-art inside the low-res SubViewport, while the root
	# CanvasLayer/HUDRoot can render at the higher window/canvas resolution.
	# Do not manually resize/center it: previous manual native layout caused
	# floating-box/ghost-render regressions.
	if game_view:
		game_view.stretch = true
		game_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Create UI/HUD layer, then HUD/menu contents.
	_ensure_hud_layer()
	_create_fx_layer()
	_create_hud()
	_create_menu_ui()
	_enter_menu()

	# No normal player-facing debug spam by default
	_set_debug_ui_enabled(false)

func _process(delta: float) -> void:
	_handle_debug_toggle()
	_update_camera_fx(delta)
	_update_impact_flash(delta)
	_update_hit_fx(delta)
	if app_state != AppState.GAME:
		menu_fx_time += delta
		_process_menu_input()
		_update_menu_ui()
		_animate_menu_ui()
		_update_debug_label()
		if debug_timer > 0:
			debug_timer -= delta
			if debug_timer <= 0 and debug_label:
				debug_label.visible = false
		return

	if p2:
		p2.ai_input = {}

	if round_state == RoundState.PLAYING:
		if not intro_active:
			# Temporary dummy CPU: P2 stands still for manual testing.
			if p2:
				p2.ai_input = {}

			# Combat processing
			if p1 and p2:
				_process_combat(p1, p2)
				_process_combat(p2, p1)

			# Round timer / win conditions
			round_time_left = maxf(0.0, round_time_left - delta)
			if p1 and p2:
				if p1.health <= 0:
					_finish_round(2, true)
				elif p2.health <= 0:
					_finish_round(1, true)
				elif round_time_left <= 0.0:
					if p1.health > p2.health:
						_finish_round(1, false)
					elif p2.health > p1.health:
						_finish_round(2, false)
					else:
						_finish_round(0, false)
	elif round_state == RoundState.ROUND_OVER:
		round_over_timer -= delta
		if round_over_timer <= 0.0:
			if p1_round_wins >= ROUNDS_TO_WIN or p2_round_wins >= ROUNDS_TO_WIN:
				round_state = RoundState.MATCH_OVER
				if announcement_label:
					announcement_label.visible = false
				_show_result_panel(1 if p1_round_wins >= ROUNDS_TO_WIN else 2)
				SoundManager.play("you_win", 0.75)
			else:
				_start_next_round()
	elif round_state == RoundState.MATCH_OVER:
		if Input.is_action_just_pressed("p1_start"):
			_enter_menu()

	# Auto-facing: players always face each other
	if p1 and p2:
		if p1.position.x < p2.position.x:
			p1.facing_right = true
			p2.facing_right = false
		else:
			p1.facing_right = false
			p2.facing_right = true
		_enforce_fighter_separation()

	# Camera tracking (midpoint between fighters)
	_apply_camera_tracking(false)

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

	var atk_data: Dictionary = attacker.get_attack_data(attacker.current_attack)
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
		attacker.apply_hitstop(HITSTOP_ON_BLOCK)
		defender.apply_hitstop(HITSTOP_ON_BLOCK)
		SoundManager.play_block_sound()
		_spawn_hit_fx(_impact_position(attacker, defender), true, false)
		_trigger_impact_flash(Color(0.85, 0.92, 1.0, 1.0), 0.10)
	else:
		# Clean hit
		var knockdown: bool = atk_data.get("knockdown", false)
		defender.pushback_dir = push_dir
		defender.apply_hit(atk_data.damage, atk_data.hitstun, atk_data.pushback, knockdown)
		_notify_health_damage(defender, atk_data.damage)
		attacker.apply_hitstop(HITSTOP_ON_HIT)
		defender.apply_hitstop(HITSTOP_ON_HIT)
		SoundManager.play_hit_sound(attacker.current_attack)
		var heavy_hit := attacker.current_attack == "heavyPunch" or attacker.current_attack == "heavyKick"
		var fatal_hit := defender.health <= 0
		var impact_pos := _impact_position(attacker, defender)
		_spawn_hit_fx(impact_pos, false, heavy_hit or fatal_hit)
		if fatal_hit:
			_spawn_hit_fx(impact_pos + Vector2(push_dir * -8.0, -10.0), false, true)
			_trigger_camera_shake(0.26, 7.0)
			_trigger_impact_flash(Color(1.0, 0.98, 0.92, 1.0), 0.22)
		elif heavy_hit:
			_trigger_camera_shake(0.18, 5.0 if attacker.current_attack == "heavyKick" else 4.0)
			_trigger_impact_flash(Color(1.0, 0.96, 0.90, 1.0), 0.16)
		else:
			_trigger_impact_flash(Color(1.0, 1.0, 1.0, 1.0), 0.08)
		if defender.health <= 0:
			SoundManager.play_ko()

func _notify_health_damage(defender: Player, amount: int) -> void:
	var widget := p1_health_widget if defender == p1 else p2_health_widget
	if widget and widget.has_method("take_damage"):
		widget.take_damage(amount)

func _box_overlap(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.position.x + b.size.x and \
	       a.position.x + a.size.x > b.position.x and \
	       a.position.y < b.position.y + b.size.y and \
	       a.position.y + a.size.y > b.position.y

func _apply_camera_tracking(force_snap: bool = false) -> void:
	if not (p1 and p2 and camera):
		return
	var stage_width: float = stage.get_stage_width() if stage and stage.has_method("get_stage_width") else STAGE_FLOOR_WIDTH
	var stage_left_min: float = stage.get_camera_left_min() if stage and stage.has_method("get_camera_left_min") else 160.0
	var max_left: float = stage.get_max_scroll() if stage and stage.has_method("get_max_scroll") else stage_width - VISIBLE_WIDTH
	var current_cam_left := clampf(camera.position.x - VISIBLE_WIDTH / 2.0, stage_left_min, max_left)
	var fighter_left := minf(p1.position.x, p2.position.x)
	var fighter_right := maxf(p1.position.x, p2.position.x)
	var desired_cam_left := current_cam_left
	var min_cam_left := fighter_right - (VISIBLE_WIDTH - CAMERA_RIGHT_MARGIN)
	var max_cam_left_for_left_margin := fighter_left - CAMERA_LEFT_MARGIN
	if min_cam_left <= max_cam_left_for_left_margin:
		desired_cam_left = clampf(current_cam_left, min_cam_left, max_cam_left_for_left_margin)
	else:
		var fighter_center := (fighter_left + fighter_right) * 0.5
		desired_cam_left = fighter_center - VISIBLE_WIDTH * 0.5
	desired_cam_left = clampf(desired_cam_left, stage_left_min, max_left)
	var effective_cam_left := desired_cam_left if force_snap else lerpf(current_cam_left, desired_cam_left, CAMERA_PAN_SPEED * (1.0 / 60.0))
	effective_cam_left = clampf(effective_cam_left, stage_left_min, max_left)
	var shake_offset := _get_camera_shake_offset() if not force_snap else Vector2.ZERO
	camera.position.x = effective_cam_left + VISIBLE_WIDTH / 2.0 + shake_offset.x
	camera.position.y = CAMERA_Y + shake_offset.y
	if stage and stage.has_method("set_camera_left"):
		stage.set_camera_left(effective_cam_left)

func _trigger_camera_shake(duration: float, strength: float) -> void:
	camera_shake_timer = maxf(camera_shake_timer, duration)
	camera_shake_strength = maxf(camera_shake_strength, strength)

func _update_camera_fx(delta: float) -> void:
	if camera_shake_timer > 0.0:
		camera_shake_timer = maxf(0.0, camera_shake_timer - delta)
	camera_shake_strength = move_toward(camera_shake_strength, 0.0, CAMERA_SHAKE_DECAY * delta)

func _get_camera_shake_offset() -> Vector2:
	if camera_shake_timer <= 0.0 or camera_shake_strength <= 0.01:
		return Vector2.ZERO
	var t := Time.get_ticks_msec() * 0.001
	return Vector2(sin(t * 83.0), cos(t * 61.0)) * camera_shake_strength

func _trigger_impact_flash(color: Color, alpha: float) -> void:
	if not impact_flash:
		return
	impact_flash.color = Color(color.r, color.g, color.b, maxf(impact_flash_alpha, alpha))
	impact_flash_alpha = maxf(impact_flash_alpha, alpha)
	impact_flash.visible = true

func _update_impact_flash(delta: float) -> void:
	if not impact_flash:
		return
	if impact_flash_alpha <= 0.0:
		impact_flash.visible = false
		return
	impact_flash_alpha = maxf(0.0, impact_flash_alpha - IMPACT_FLASH_DECAY * delta)
	impact_flash.color.a = impact_flash_alpha
	impact_flash.visible = impact_flash_alpha > 0.0

func _create_fx_layer() -> void:
	if fx_layer or not game_root:
		return
	fx_layer = Node2D.new()
	fx_layer.name = "FxLayer"
	fx_layer.z_index = 500
	game_root.add_child(fx_layer)

func _impact_visual_y_offset(attack_name: String) -> float:
	match attack_name:
		"lightPunch":
			return 92.0
		"heavyPunch":
			return 106.0
		"lightKick":
			return 72.0
		"heavyKick":
			return 92.0
		_:
			return 84.0

func _impact_position(attacker: Player, defender: Player) -> Vector2:
	var atk := attacker.get_attack_hitbox()
	var hurt := defender.get_hurtbox()
	var left := maxf(atk.position.x, hurt.position.x)
	var right := minf(atk.position.x + atk.size.x, hurt.position.x + hurt.size.x)
	var visual_y := defender.position.y - _impact_visual_y_offset(attacker.current_attack)
	if right > left:
		return Vector2((left + right) * 0.5, visual_y)
	return defender.position + Vector2(0.0, -_impact_visual_y_offset(attacker.current_attack))

func _spawn_hit_fx(world_pos: Vector2, blocked: bool, heavy: bool) -> void:
	if not fx_layer:
		return
	var fx_root := Node2D.new()
	fx_root.position = world_pos
	fx_root.z_index = 500
	var colors := _hit_fx_colors(blocked, heavy)
	var duration := HIT_FX_BLOCK_DURATION if blocked else (HIT_FX_HEAVY_DURATION if heavy else HIT_FX_LIGHT_DURATION)
	var scale_mul := 0.85 if blocked else (1.45 if heavy else 1.0)
	var ring := Polygon2D.new()
	ring.polygon = _star_points(12.0 * scale_mul, 34.0 * scale_mul, 8)
	ring.color = colors[0]
	fx_root.add_child(ring)
	var core := Polygon2D.new()
	core.polygon = _star_points(5.0 * scale_mul, 15.0 * scale_mul, 6)
	core.color = colors[1]
	fx_root.add_child(core)
	for i in range(3 if blocked else (6 if heavy else 4)):
		var shard := Line2D.new()
		shard.width = 2.0 if heavy else 1.5
		shard.default_color = colors[2]
		var angle := randf() * TAU
		var dir := Vector2.RIGHT.rotated(angle)
		var inner := dir * (7.0 * scale_mul)
		var outer := dir * (26.0 * scale_mul + randf() * 10.0 * scale_mul)
		shard.points = PackedVector2Array([inner, outer])
		fx_root.add_child(shard)
	fx_layer.add_child(fx_root)
	active_hit_fx.append({
		"node": fx_root,
		"age": 0.0,
		"duration": duration,
		"blocked": blocked,
		"heavy": heavy,
	})

func _update_hit_fx(delta: float) -> void:
	if active_hit_fx.is_empty():
		return
	for i in range(active_hit_fx.size() - 1, -1, -1):
		var fx: Dictionary = active_hit_fx[i]
		var node := fx.get("node") as Node2D
		if node == null or not is_instance_valid(node):
			active_hit_fx.remove_at(i)
			continue
		var age: float = fx.get("age", 0.0) + delta
		var duration: float = fx.get("duration", 0.12)
		var t := clampf(age / duration, 0.0, 1.0)
		fx["age"] = age
		node.scale = Vector2.ONE * (1.0 + t * (0.35 if fx.get("blocked", false) else 0.55))
		node.rotation += delta * (6.0 if fx.get("heavy", false) else 4.0)
		node.modulate.a = 1.0 - t
		if age >= duration:
			node.queue_free()
			active_hit_fx.remove_at(i)
		else:
			active_hit_fx[i] = fx

func _hit_fx_colors(blocked: bool, heavy: bool) -> Array[Color]:
	if blocked:
		return [Color(0.15, 1.0, 0.78, 0.92), Color(0.92, 1.0, 1.0, 0.95), Color(0.12, 0.88, 0.98, 0.92)]
	if heavy:
		return [Color(0.35, 1.0, 0.35, 0.94), Color(1.0, 1.0, 1.0, 0.98), Color(0.95, 1.0, 0.25, 0.92)]
	return [Color(0.18, 1.0, 0.28, 0.92), Color(1.0, 1.0, 1.0, 0.95), Color(0.58, 1.0, 0.78, 0.88)]

func _star_points(inner_radius: float, outer_radius: float, spikes: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(spikes * 2):
		var angle := (TAU * float(i) / float(spikes * 2)) - PI * 0.5
		var radius := outer_radius if i % 2 == 0 else inner_radius
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts

func _enforce_fighter_separation() -> void:
	if not (p1 and p2):
		return
	var left_fighter: Player = p1 if p1.position.x <= p2.position.x else p2
	var right_fighter: Player = p2 if left_fighter == p1 else p1
	var distance := right_fighter.position.x - left_fighter.position.x
	if distance <= MAX_FIGHTER_SEPARATION:
		return
	var excess := distance - MAX_FIGHTER_SEPARATION
	var left_moving_away := left_fighter.vel_x < 0.0
	var right_moving_away := right_fighter.vel_x > 0.0
	if left_moving_away and right_moving_away:
		left_fighter.position.x += excess * 0.5
		right_fighter.position.x -= excess * 0.5
	elif left_moving_away:
		left_fighter.position.x += excess
	elif right_moving_away:
		right_fighter.position.x -= excess
	else:
		left_fighter.position.x += excess * 0.5
		right_fighter.position.x -= excess * 0.5
	left_fighter.position.x = clampf(left_fighter.position.x, left_fighter.stage_left_bound, left_fighter.stage_right_bound)
	right_fighter.position.x = clampf(right_fighter.position.x, right_fighter.stage_left_bound, right_fighter.stage_right_bound)

func _start_match() -> void:
	app_state = AppState.GAME
	menu_index = 0
	if game_view:
		game_view.visible = true
	if stage and stage.has_method("set_stage_theme"):
		stage.set_stage_theme("city")
	_hide_result_panel()
	_set_game_hud_visible(true)
	# Temporary roster shell: backend still uses current default real build, with SF kept as easter egg.
	if p1:
		p1.set_character("Teknium")
	if p2:
		p2.set_character("Teknium")
	if p1_health_widget and p1_health_widget.has_method("configure"):
		p1_health_widget.configure(selected_fighter_name, "P1")
	if p2_health_widget and p2_health_widget.has_method("configure"):
		p2_health_widget.configure("TEKNIUM", "AI")
	current_round = 1
	p1_round_wins = 0
	p2_round_wins = 0
	if ai:
		ai.set_difficulty(CPU_DIFFICULTIES[option_difficulty_index])
		ai.reset()
	_update_round_dots()
	_start_next_round(true)

func _hide_result_panel() -> void:
	if result_panel_bg:
		result_panel_bg.visible = false
	if result_panel_border:
		result_panel_border.visible = false
	if result_title_label:
		result_title_label.visible = false
	if result_status_label:
		result_status_label.visible = false
	if result_winner_label:
		result_winner_label.visible = false
	if result_prompt_label:
		result_prompt_label.visible = false

func _show_result_panel(winner: int) -> void:
	if not result_panel_bg:
		return
	result_panel_bg.visible = true
	result_panel_border.visible = true
	result_title_label.visible = true
	result_status_label.visible = true
	result_winner_label.visible = true
	result_prompt_label.visible = true
	result_title_label.text = "SIMULATION RESULT"
	result_status_label.text = "SIMULATION COMPLETE"
	result_winner_label.text = "P%d DOMINANT" % winner
	result_prompt_label.text = "PRESS ENTER FOR MENU"

func _enter_menu() -> void:
	app_state = AppState.MENU
	menu_index = 0
	fighter_select_index = 0
	intro_active = false
	intro_token += 1
	if game_view:
		game_view.visible = false
	_hide_result_panel()
	if announcement_label:
		announcement_label.visible = false
	_set_game_hud_visible(false)
	if p1:
		p1.control_enabled = false
		p1.ai_input = {}
		p1._set_animation("idle")
	if p2:
		p2.control_enabled = false
		p2.ai_input = {}
		p2._set_animation("idle")
	_update_menu_ui()

func _process_menu_input() -> void:
	match app_state:
		AppState.MENU:
			if Input.is_action_just_pressed("p1_up"):
				menu_index = posmod(menu_index - 1, 3)
			elif Input.is_action_just_pressed("p1_down"):
				menu_index = posmod(menu_index + 1, 3)
			elif Input.is_action_just_pressed("p1_start"):
				match menu_index:
					0:
						app_state = AppState.FIGHTER_SELECT
					1:
						app_state = AppState.CONTROLS
					2:
						app_state = AppState.OPTIONS
		AppState.FIGHTER_SELECT:
			if Input.is_action_just_pressed("p1_up"):
				fighter_select_index = posmod(fighter_select_index - 1, FIGHTER_PLACEHOLDERS.size())
			elif Input.is_action_just_pressed("p1_down"):
				fighter_select_index = posmod(fighter_select_index + 1, FIGHTER_PLACEHOLDERS.size())
			elif Input.is_action_just_pressed("p1_start"):
				selected_fighter_name = FIGHTER_PLACEHOLDERS[fighter_select_index]
				_start_match()
			elif Input.is_action_just_pressed("p1_punch_light"):
				app_state = AppState.MENU
		AppState.CONTROLS:
			if Input.is_action_just_pressed("p1_start") or Input.is_action_just_pressed("p1_punch_light"):
				app_state = AppState.MENU
		AppState.OPTIONS:
			if Input.is_action_just_pressed("p1_left"):
				option_difficulty_index = posmod(option_difficulty_index - 1, CPU_DIFFICULTIES.size())
			elif Input.is_action_just_pressed("p1_right"):
				option_difficulty_index = posmod(option_difficulty_index + 1, CPU_DIFFICULTIES.size())
			elif Input.is_action_just_pressed("p1_start") or Input.is_action_just_pressed("p1_punch_light"):
				app_state = AppState.MENU

func _ensure_hud_layer() -> void:
	if hud_layer:
		return
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	hud_layer.layer = 10
	hud_layer.follow_viewport_enabled = false
	add_child(hud_layer)

	hud_root = Control.new()
	hud_root.name = "HUD"
	hud_root.position = Vector2.ZERO
	hud_root.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)

func _ui_add_child(node: Node) -> void:
	if not hud_root:
		_ensure_hud_layer()
	hud_root.add_child(node)

func _create_menu_ui() -> void:
	menu_overlay = ColorRect.new()
	menu_overlay.position = Vector2.ZERO
	menu_overlay.size = Vector2(SCREEN_WIDTH, 288)
	menu_overlay.color = Color(0.01, 0.02, 0.03, 1.0)
	_ui_add_child(menu_overlay)

	menu_panel_back = ColorRect.new()
	menu_panel_back.position = Vector2(56, 26)
	menu_panel_back.size = Vector2(400, 232)
	menu_panel_back.color = Color(0.0, 0.85, 0.72, 0.28)
	_ui_add_child(menu_panel_back)

	menu_panel = ColorRect.new()
	menu_panel.position = Vector2(58, 28)
	menu_panel.size = Vector2(396, 228)
	menu_panel.color = Color(0.03, 0.05, 0.08, 0.96)
	_ui_add_child(menu_panel)

	menu_title_label = Label.new()
	menu_title_label.position = Vector2(84, 40)
	menu_title_label.size = Vector2(344, 34)
	menu_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title_label.add_theme_font_size_override("font_size", 24)
	menu_title_label.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
	_ui_add_child(menu_title_label)

	menu_subtitle_label = Label.new()
	menu_subtitle_label.position = Vector2(84, 68)
	menu_subtitle_label.size = Vector2(344, 20)
	menu_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_subtitle_label.add_theme_font_size_override("font_size", 11)
	menu_subtitle_label.add_theme_color_override("font_color", Color(0.28, 0.95, 0.85))
	_ui_add_child(menu_subtitle_label)

	menu_body_label = Label.new()
	menu_body_label.position = Vector2(92, 102)
	menu_body_label.size = Vector2(328, 106)
	menu_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	menu_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	menu_body_label.add_theme_font_size_override("font_size", 15)
	menu_body_label.add_theme_color_override("font_color", Color(0.86, 0.94, 0.98))
	_ui_add_child(menu_body_label)

	for i in range(FIGHTER_PLACEHOLDERS.size()):
		var x := 82 + i * 116
		var back := ColorRect.new()
		back.position = Vector2(x, 102)
		back.size = Vector2(104, 86)
		back.color = Color(0.0, 0.85, 0.72, 0.22)
		_ui_add_child(back)
		fighter_card_backs.append(back)

		var fill := ColorRect.new()
		fill.position = Vector2(x + 2, 104)
		fill.size = Vector2(100, 82)
		fill.color = Color(0.06, 0.09, 0.13, 0.98)
		_ui_add_child(fill)
		fighter_card_fills.append(fill)

		var label := Label.new()
		label.position = Vector2(x + 8, 116)
		label.size = Vector2(88, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.90, 0.98, 1.0))
		label.text = FIGHTER_PLACEHOLDERS[i]
		_ui_add_child(label)
		fighter_card_labels.append(label)

		var tag := Label.new()
		tag.position = Vector2(x + 8, 145)
		tag.size = Vector2(88, 26)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 10)
		tag.add_theme_color_override("font_color", Color(0.45, 0.75, 0.82))
		tag.text = "PLACEHOLDER\nASSET SLOT"
		_ui_add_child(tag)
		fighter_card_tags.append(tag)

	fighter_select_desc_label = Label.new()
	fighter_select_desc_label.position = Vector2(90, 196)
	fighter_select_desc_label.size = Vector2(332, 30)
	fighter_select_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fighter_select_desc_label.add_theme_font_size_override("font_size", 10)
	fighter_select_desc_label.add_theme_color_override("font_color", Color(0.45, 0.75, 0.82))
	_ui_add_child(fighter_select_desc_label)

	menu_hint_label = Label.new()
	menu_hint_label.position = Vector2(82, 222)
	menu_hint_label.size = Vector2(348, 22)
	menu_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_hint_label.add_theme_font_size_override("font_size", 11)
	menu_hint_label.add_theme_color_override("font_color", Color(0.45, 0.75, 0.82))
	_ui_add_child(menu_hint_label)

	for i in range(18):
		var line := ColorRect.new()
		line.position = Vector2(70, 34 + i * 12)
		line.size = Vector2(372, 1)
		line.color = Color(0.45, 0.95, 0.95, 0.06)
		_ui_add_child(line)
		menu_scanlines.append(line)

func _update_menu_ui() -> void:
	var visible := app_state != AppState.GAME
	if menu_overlay: menu_overlay.visible = visible
	if menu_panel_back: menu_panel_back.visible = visible
	if menu_panel: menu_panel.visible = visible
	for line in menu_scanlines:
		if line: line.visible = visible
	if menu_title_label: menu_title_label.visible = visible
	if menu_subtitle_label: menu_subtitle_label.visible = visible
	if menu_body_label: menu_body_label.visible = visible
	if menu_hint_label: menu_hint_label.visible = visible
	if fighter_select_desc_label: fighter_select_desc_label.visible = visible and app_state == AppState.FIGHTER_SELECT
	for node in fighter_card_backs:
		if node: node.visible = visible and app_state == AppState.FIGHTER_SELECT
	for node in fighter_card_fills:
		if node: node.visible = visible and app_state == AppState.FIGHTER_SELECT
	for node in fighter_card_labels:
		if node: node.visible = visible and app_state == AppState.FIGHTER_SELECT
	for node in fighter_card_tags:
		if node: node.visible = visible and app_state == AppState.FIGHTER_SELECT
	if not visible:
		return
	menu_subtitle_label.text = "teknium // nous research // combat sandbox"
	match app_state:
		AppState.MENU:
			menu_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			menu_title_label.text = "HACKFIGHTER"
			var items := ["START SIMULATION", "CONTROL MAP", "SYSTEM OPTIONS"]
			var lines: Array[String] = []
			for i in range(items.size()):
				lines.append(("[>] " if i == menu_index else "[ ] ") + items[i])
			menu_body_label.text = "\n".join(lines)
			menu_hint_label.text = "NAV: W/S   CONFIRM: ENTER"
		AppState.FIGHTER_SELECT:
			menu_title_label.text = "FIGHTER SELECT"
			menu_body_label.text = ""
			fighter_select_desc_label.text = "Select a placeholder operative. Current live backend remains the hidden easter-egg build."
			for i in range(FIGHTER_PLACEHOLDERS.size()):
				var selected := i == fighter_select_index
				fighter_card_backs[i].color = Color(0.0, 0.85, 0.72, 0.36 if selected else 0.18)
				fighter_card_fills[i].color = Color(0.08, 0.13, 0.18, 1.0) if selected else Color(0.05, 0.08, 0.11, 0.98)
				fighter_card_labels[i].modulate = Color(0.98, 1.0, 1.0, 1.0) if selected else Color(0.82, 0.9, 0.95, 0.92)
				fighter_card_tags[i].modulate = Color(0.55, 0.92, 0.88, 1.0) if selected else Color(0.40, 0.68, 0.76, 0.88)
			menu_hint_label.text = "NAV: W/S   CONFIRM: ENTER   BACK: U/J"
		AppState.CONTROLS:
			menu_title_label.text = "CONTROL MAP"
			menu_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			menu_body_label.text = "MOVE      A / D\nJUMP      W\nCROUCH    S\nLP        U or J\nHP        I or K\nLK        O or L\nHK        P or ;"
			menu_hint_label.text = "RETURN: ENTER OR U/J"
		AppState.OPTIONS:
			menu_title_label.text = "SYSTEM OPTIONS"
			menu_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			menu_body_label.text = "CPU PROFILE\n\n<  %s  >\n\nSelect how aggressive the rival model behaves." % CPU_DIFFICULTIES[option_difficulty_index]
			menu_hint_label.text = "CHANGE: A/D   RETURN: ENTER OR U/J"

func _animate_menu_ui() -> void:
	var pulse := 0.22 + 0.06 * sin(menu_fx_time * 1.9)
	if menu_panel_back:
		menu_panel_back.color = Color(0.0, 0.85, 0.72, pulse)
	if menu_title_label:
		var glow := 0.92 + 0.08 * sin(menu_fx_time * 2.7)
		menu_title_label.modulate = Color(glow, glow + 0.03, glow + 0.05, 1.0)
	if menu_subtitle_label:
		menu_subtitle_label.modulate = Color(0.28, 0.95, 0.85, 0.78 + 0.16 * sin(menu_fx_time * 1.3))
	if menu_hint_label:
		menu_hint_label.modulate = Color(0.45, 0.75, 0.82, 0.72 + 0.12 * sin(menu_fx_time * 2.1))
	for i in range(menu_scanlines.size()):
		var line := menu_scanlines[i]
		if line:
			line.modulate.a = 0.025 + 0.035 * (0.5 + 0.5 * sin(menu_fx_time * 3.2 + float(i) * 0.45))

func _set_game_hud_visible(vis: bool) -> void:
	var nodes = [
		impact_flash,
		p1_health_widget, p2_health_widget,
		timer_bg, timer_label, timer_word_label,
	]
	for node in nodes:
		if node:
			node.visible = vis

func _start_next_round(first_round: bool = false) -> void:
	round_state = RoundState.PLAYING
	intro_active = true
	intro_token += 1
	var this_intro: int = intro_token
	round_time_left = ROUND_TIME
	var p1_spawn_x := P1_SPAWN_X
	var p2_spawn_x := P2_SPAWN_X
	if stage:
		if stage.has_method("get_p1_spawn_x"):
			p1_spawn_x = stage.get_p1_spawn_x()
		if stage.has_method("get_p2_spawn_x"):
			p2_spawn_x = stage.get_p2_spawn_x()
	if p1:
		p1.reset_for_new_round(p1_spawn_x, p1.ground_y if p1.ground_y > 0 else 315.0, true)
		p1.control_enabled = false
	if p2:
		p2.reset_for_new_round(p2_spawn_x, p2.ground_y if p2.ground_y > 0 else 315.0, false)
		p2.control_enabled = false
	if p1 and p2:
		p1.other_player = p2
		p2.other_player = p1
		if stage:
			if stage.has_method("get_player_left_bound"):
				var left_bound = stage.get_player_left_bound()
				p1.stage_left_bound = left_bound
				p2.stage_left_bound = left_bound
			if stage.has_method("get_player_right_bound"):
				var right_bound = stage.get_player_right_bound()
				p1.stage_right_bound = right_bound
				p2.stage_right_bound = right_bound
	if ai:
		ai.reset()
	_apply_camera_tracking(true)
	if announcement_label:
		announcement_label.visible = true
		announcement_label.text = "ROUND %d INITIALIZING" % current_round
	SoundManager.play("round", 0.7)
	await get_tree().create_timer(0.35).timeout
	if this_intro != intro_token:
		return
	match current_round:
		1:
			SoundManager.play("one", 0.7)
		2:
			SoundManager.play("two", 0.7)
		3:
			SoundManager.play("three", 0.7)
		_:
			SoundManager.play("final", 0.7)
	await get_tree().create_timer(0.75).timeout
	if this_intro != intro_token:
		return
	if announcement_label:
		announcement_label.text = "ENGAGE"
	SoundManager.play("fight", 0.8)
	await get_tree().create_timer(0.45).timeout
	if this_intro != intro_token:
		return
	if announcement_label:
		announcement_label.visible = false
	if p1:
		p1.control_enabled = true
	if p2:
		p2.control_enabled = true
	intro_active = false

func _freeze_players() -> void:
	if p1:
		p1.control_enabled = false
		p1.ai_input = {}
	if p2:
		p2.control_enabled = false
		p2.ai_input = {}
	intro_active = false
	intro_token += 1

func _finish_round(winner: int, by_ko: bool) -> void:
	if round_state != RoundState.PLAYING:
		return
	round_state = RoundState.ROUND_OVER
	round_over_timer = 1.8
	_freeze_players()

	# Put the winner into victory pose before the round transition.
	if winner == 1:
		p1_round_wins += 1
		if p1:
			p1._set_animation("victory")
	elif winner == 2:
		p2_round_wins += 1
		if p2:
			p2._set_animation("victory")

	_update_round_dots()
	if announcement_label:
		if winner == 0:
			announcement_label.text = "TIME LIMIT\nNO CLEAR WINNER"
		elif by_ko:
			announcement_label.text = "TARGET DOWN\nP%d TAKES ROUND %d" % [winner, current_round]
		else:
			announcement_label.text = "TIME LIMIT\nP%d TAKES ROUND %d" % [winner, current_round]
		announcement_label.visible = true
	current_round += 1

# ── HUD ───────────────────────────────────────────────────────────────

func _create_hud() -> void:
	# We create match HUD inside HUDRoot on a CanvasLayer outside SubViewport.
	# The root is scaled at native window resolution, avoiding viewport-stretched HUD pixels.

	impact_flash = ColorRect.new()
	impact_flash.position = Vector2.ZERO
	impact_flash.size = Vector2(SCREEN_WIDTH, 288)
	impact_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	impact_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	impact_flash.visible = false
	_ui_add_child(impact_flash)

	p1_health_widget = HEALTH_BAR_SCENE.instantiate()
	p1_health_widget.position = Vector2(8, 4)
	p1_health_widget.hero_name = "TEKNIUM"
	p1_health_widget.slot = "P1"
	_ui_add_child(p1_health_widget)

	p2_health_widget = HEALTH_BAR_SCENE.instantiate()
	p2_health_widget.position = Vector2(292, 4)
	p2_health_widget.hero_name = "TEKNIUM"
	p2_health_widget.slot = "AI"
	_ui_add_child(p2_health_widget)

	timer_bg = TextureRect.new()
	timer_bg.texture = load("res://assets/ui/timer_frame.png")
	timer_bg.position = Vector2(220, 7)
	timer_bg.size = Vector2(72, 56)
	timer_bg.modulate = Color(0.30, 1.25, 1.12)
	timer_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	timer_bg.stretch_mode = TextureRect.STRETCH_SCALE
	timer_bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ui_add_child(timer_bg)

	timer_label = Label.new()
	timer_label.position = Vector2(232, 13)
	timer_label.size = Vector2(48, 24)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_override("font", HUD_FONT)
	timer_label.add_theme_font_size_override("font_size", 18)
	timer_label.add_theme_color_override("font_color", Color(0.34, 1.25, 1.05))
	_ui_add_child(timer_label)

	timer_word_label = Label.new()
	timer_word_label.position = Vector2(232, 36)
	timer_word_label.size = Vector2(48, 12)
	timer_word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_word_label.text = "TIME"
	timer_word_label.add_theme_font_override("font", HUD_FONT)
	timer_word_label.add_theme_font_size_override("font_size", 8)
	timer_word_label.add_theme_color_override("font_color", Color(0.70, 0.96, 1.0))
	_ui_add_child(timer_word_label)

	p1_display_health = p1.MAX_HEALTH if p1 else 1000.0
	p2_display_health = p2.MAX_HEALTH if p2 else 1000.0

	announcement_label = Label.new()
	announcement_label.position = Vector2(92, 92)
	announcement_label.size = Vector2(328, 96)
	announcement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcement_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	announcement_label.add_theme_font_size_override("font_size", 17)
	announcement_label.add_theme_color_override("font_color", Color(0.90, 0.98, 1.0))
	announcement_label.visible = false
	_ui_add_child(announcement_label)

	result_panel_border = ColorRect.new()
	result_panel_border.position = Vector2(130, 52)
	result_panel_border.size = Vector2(252, 98)
	result_panel_border.color = Color(0.0, 0.92, 0.82, 0.95)
	result_panel_border.visible = false
	_ui_add_child(result_panel_border)

	result_panel_bg = ColorRect.new()
	result_panel_bg.position = Vector2(133, 55)
	result_panel_bg.size = Vector2(246, 92)
	result_panel_bg.color = Color(0.02, 0.05, 0.08, 0.86)
	result_panel_bg.visible = false
	_ui_add_child(result_panel_bg)

	result_title_label = Label.new()
	result_title_label.position = Vector2(145, 64)
	result_title_label.size = Vector2(222, 16)
	result_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title_label.add_theme_font_size_override("font_size", 12)
	result_title_label.add_theme_color_override("font_color", Color(0.98, 1.0, 1.0))
	result_title_label.visible = false
	_ui_add_child(result_title_label)

	result_status_label = Label.new()
	result_status_label.position = Vector2(145, 82)
	result_status_label.size = Vector2(222, 16)
	result_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_status_label.add_theme_font_size_override("font_size", 12)
	result_status_label.add_theme_color_override("font_color", Color(0.86, 0.98, 1.0))
	result_status_label.visible = false
	_ui_add_child(result_status_label)

	result_winner_label = Label.new()
	result_winner_label.position = Vector2(145, 102)
	result_winner_label.size = Vector2(222, 18)
	result_winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_winner_label.add_theme_font_size_override("font_size", 15)
	result_winner_label.add_theme_color_override("font_color", Color(0.20, 1.0, 0.52))
	result_winner_label.visible = false
	_ui_add_child(result_winner_label)

	result_prompt_label = Label.new()
	result_prompt_label.position = Vector2(145, 122)
	result_prompt_label.size = Vector2(222, 16)
	result_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_prompt_label.add_theme_font_size_override("font_size", 11)
	result_prompt_label.add_theme_color_override("font_color", Color(0.70, 0.92, 1.0))
	result_prompt_label.visible = false
	_ui_add_child(result_prompt_label)

func _update_hud() -> void:
	if not p1 or not p2:
		return

	p1_display_health = maxf(float(p1.health), move_toward(p1_display_health, float(p1.health), HEALTH_LAG_SPEED * get_process_delta_time()))
	p2_display_health = maxf(float(p2.health), move_toward(p2_display_health, float(p2.health), HEALTH_LAG_SPEED * get_process_delta_time()))

	# Health bars
	if p1_health_widget and p1_health_widget.has_method("set_health"):
		p1_health_widget.set_health(p1.health)
	if p2_health_widget and p2_health_widget.has_method("set_health"):
		p2_health_widget.set_health(p2.health)

	timer_label.text = "%02d" % int(ceil(round_time_left))
	if round_time_left <= 10.0 and not intro_active:
		timer_label.add_theme_color_override("font_color", Color(1.25, 0.34, 0.40))
		timer_bg.modulate = Color(1.25, 0.34, 0.40)
	else:
		timer_label.add_theme_color_override("font_color", Color(0.34, 1.25, 1.05))
		timer_bg.modulate = Color(0.30, 1.25, 1.12)
	if intro_active:
		timer_label.modulate.a = 0.7
		timer_word_label.modulate.a = 0.7
		timer_bg.modulate.a = 0.78
	else:
		timer_label.modulate.a = 1.0
		timer_word_label.modulate.a = 1.0
		timer_bg.modulate.a = 1.0

func _update_round_dots() -> void:
	# Round-win pips were removed from the healthbar area in round 3 because they
	# read as stray yellow square artifacts beside the portraits.
	return

# ── Debug ─────────────────────────────────────────────────────────────

func _update_debug_label() -> void:
	if not debug_label:
		return
	var lines: Array[String] = []
	lines.append("App=%s game_view=%s menu=%d fighter=%d" % [AppState.keys()[app_state], str(game_view.visible) if game_view else "null", menu_index, fighter_select_index])
	if p1:
		var sprite1 := p1.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		lines.append("Round=%d %s T=%.0f P1w=%d P2w=%d" % [current_round, RoundState.keys()[round_state], round_time_left, p1_round_wins, p2_round_wins])
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
	if stage and stage.has_method("get_camera_left") and stage.has_method("get_max_scroll"):
		var left_bound := p1.stage_left_bound if p1 else -1.0
		var right_bound := p1.stage_right_bound if p1 else -1.0
		lines.append("Cam x=%.1f left=%.1f/%.1f bounds=%.0f..%.0f" % [camera.position.x, stage.get_camera_left(), stage.get_max_scroll(), left_bound, right_bound])
	debug_label.visible = debug_ui_enabled or debug_timer > 0.0
	debug_label.text = "\n".join(lines)

func _handle_debug_toggle() -> void:
	var pressed := Input.is_physical_key_pressed(KEY_F9)
	if pressed and not debug_toggle_latch:
		_set_debug_ui_enabled(not debug_ui_enabled)
	debug_toggle_latch = pressed

func _set_debug_ui_enabled(enabled: bool) -> void:
	debug_ui_enabled = enabled
	debug_timer = 0.0
	if debug_label:
		debug_label.visible = enabled
	if p1 and p1.has_method("set_debug_overlay_enabled"):
		p1.set_debug_overlay_enabled(enabled)
	if p2 and p2.has_method("set_debug_overlay_enabled"):
		p2.set_debug_overlay_enabled(enabled)
