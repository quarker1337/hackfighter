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
var fighter_select_side: int = 0  # 0 = P1, 1 = CPU/P2
var option_index: int = 0
var option_difficulty_index: int = 1
var option_sfx_volume: int = 60
var option_music_volume: int = 70
var option_radio_index: int = 0
const CPU_DIFFICULTIES := ["EASY", "NORMAL", "HARD"]
const OPTION_COUNT := 4
const FIGHTER_PLACEHOLDERS := ["TEKNIUM", "NOUSGIRL", "LOBSTER"]
const LOCKED_FIGHTERS := ["NOUSGIRL"]
var selected_p1_fighter_name: String = "TEKNIUM"
var selected_p2_fighter_name: String = "TEKNIUM"

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
const JP_UI_FONT := preload("res://fonts/IPAGothic.ttf")
var hud_layer: CanvasLayer = null
var hud_root: Control = null
var p1_health_widget: Control = null
var p2_health_widget: Control = null
var timer_backplate: ColorRect = null
var timer_bg: NinePatchRect = null
var timer_label: Label = null
var timer_word_label: Label = null
var announcement_label: Label = null
var combat_overlay_back: Panel = null
var combat_overlay_panel: Panel = null
var combat_overlay_title_label: Label = null
var combat_overlay_detail_label: Label = null
var combat_overlay_timer: float = 0.0
var combat_overlay_accent: Color = Color(0.0, 0.95, 0.82, 1.0)
var result_panel_bg: ColorRect = null
var result_panel_border: ColorRect = null
var result_title_label: Label = null
var result_status_label: Label = null
var result_winner_label: Label = null
var result_prompt_label: Label = null
var menu_overlay: ColorRect = null
var menu_panel_back: Panel = null
var menu_panel: Panel = null
var menu_scanlines: Array[ColorRect] = []
var menu_global_scanlines: Array[ColorRect] = []
var menu_crt_overlay: ColorRect = null
var gameplay_pixel_shift_overlay: ColorRect = null
var crt_vignette_overlay: ColorRect = null
var gameplay_pixel_shift_time: float = 0.0
var signal_glitch_visibility: float = 1.0
var signal_glitch_suppress_timer: float = 0.0
var signal_hit_glitch_timer: float = 0.0
var signal_hit_glitch_strength: float = 0.0
var menu_title_label: Label = null
var menu_subtitle_label: Label = null
var menu_body_label: Label = null
var menu_hint_label: Label = null
var fighter_card_backs: Array[Panel] = []
var fighter_card_fills: Array[Panel] = []
var fighter_card_portrait_frames: Array[Panel] = []
var fighter_card_portraits: Array[TextureRect] = []
var fighter_card_labels: Array[Label] = []
var fighter_card_tags: Array[Label] = []
var fighter_select_desc_label: Label = null
var start_banner_panel: Panel = null
var start_banner_label: Label = null
var start_banner_timer: float = 0.0
var menu_fx_time: float = 0.0
var boot_intro_active: bool = false
var boot_intro_seen: bool = false
var boot_intro_time: float = 0.0
const BOOT_INTRO_DURATION: float = 3.35
var boot_overlay: ColorRect = null
var boot_logo_label: Label = null
var boot_subtitle_label: Label = null
var boot_status_label: Label = null
var boot_progress_panel: Panel = null
var boot_progress_fill: ColorRect = null
var boot_code_labels: Array[Label] = []
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
	_create_boot_intro_ui()
	# Keep the LCD proof overlay as the final UI child so it affects menus/select/game,
	# not just gameplay behind the menu panels.
	_create_gameplay_pixel_shift_overlay()
	# Keep the vignette as a plain alpha overlay above the screen-reading glitch shader;
	# this avoids SCREEN_UV/SubViewport/camera-space mismatches hiding the CRT border.
	_create_crt_vignette_overlay()
	SoundManager.set_sfx_volume_percent(option_sfx_volume)
	SoundManager.set_music_volume_percent(option_music_volume)
	SoundManager.set_radio_channel(option_radio_index)
	_enter_menu()

	# No normal player-facing debug spam by default
	_set_debug_ui_enabled(false)

func _process(delta: float) -> void:
	_handle_debug_toggle()
	_update_camera_fx(delta)
	_update_impact_flash(delta)
	_update_hit_fx(delta)
	_update_gameplay_pixel_shift_overlay(delta)
	_update_start_banner(delta)
	_update_combat_overlay(delta)
	_update_boot_intro(delta)
	if app_state != AppState.GAME:
		menu_fx_time += delta
		if not boot_intro_active:
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

			# Ensure combat uses this frame's facing, not a stale pre-contact direction.
			_update_fighter_facing_and_spacing()

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
				_hide_combat_overlay()
				if announcement_label:
					announcement_label.visible = false
				var match_winner := 1 if p1_round_wins >= ROUNDS_TO_WIN else 2
				_show_result_panel(match_winner)
				SoundManager.play_match_result(match_winner, 0.75)
			else:
				_start_next_round()
	elif round_state == RoundState.MATCH_OVER:
		if Input.is_action_just_pressed("p1_start"):
			_enter_menu()

	# Auto-facing: players always face each other
	_update_fighter_facing_and_spacing()

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

func _update_fighter_facing_and_spacing() -> void:
	if not (p1 and p2):
		return
	if p1.position.x < p2.position.x:
		p1.facing_right = true
		p2.facing_right = false
	else:
		p1.facing_right = false
		p2.facing_right = true
	_enforce_fighter_separation()

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
	# Hackathon-video polish: Lobster's giant heavy claw should visibly hurt,
	# not get quietly swallowed by CPU auto-block while recording B-roll.
	if attacker.character_name.to_lower() == "lobster" and attacker.current_attack == "heavyPunch":
		blocked = false
	elif defender.is_blocking:
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
		_spawn_hit_fx(_impact_position(attacker, defender), true, false, attacker)
		_trigger_signal_hit_glitch(0.45, 0.12)
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
		_spawn_hit_fx(impact_pos, false, heavy_hit or fatal_hit, attacker)
		_trigger_signal_hit_glitch(1.0 if fatal_hit else (0.78 if heavy_hit else 0.56), 0.18 if fatal_hit else (0.15 if heavy_hit else 0.10))
		if fatal_hit:
			_spawn_hit_fx(impact_pos + Vector2(push_dir * -8.0, -10.0), false, true, attacker)
			_trigger_camera_shake(0.26, 7.0)
			var flash_color := Color(1.0, 0.58, 0.28, 1.0) if attacker.character_name.to_lower() == "lobster" else Color(1.0, 0.98, 0.92, 1.0)
			_trigger_impact_flash(flash_color, 0.22)
		elif heavy_hit:
			_trigger_camera_shake(0.18, 5.0 if attacker.current_attack == "heavyKick" else 4.0)
			var flash_color := Color(1.0, 0.42, 0.18, 1.0) if attacker.character_name.to_lower() == "lobster" else Color(1.0, 0.96, 0.90, 1.0)
			_trigger_impact_flash(flash_color, 0.16)
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
	var camera_pan_delta := absf(effective_cam_left - current_cam_left)
	var shake_offset := _get_camera_shake_offset() if not force_snap else Vector2.ZERO
	camera.position.x = effective_cam_left + VISIBLE_WIDTH / 2.0 + shake_offset.x
	camera.position.y = CAMERA_Y + shake_offset.y
	if not force_snap and (camera_pan_delta > 0.08 or camera_shake_timer > 0.0 or camera_shake_strength > 0.10):
		signal_glitch_suppress_timer = maxf(signal_glitch_suppress_timer, 0.28)
	if stage and stage.has_method("set_camera_left"):
		stage.set_camera_left(effective_cam_left)

func _trigger_signal_hit_glitch(strength: float, duration: float) -> void:
	signal_hit_glitch_strength = maxf(signal_hit_glitch_strength, strength)
	signal_hit_glitch_timer = maxf(signal_hit_glitch_timer, duration)

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

func _spawn_hit_fx(world_pos: Vector2, blocked: bool, heavy: bool, attacker: Player = null) -> void:
	if not fx_layer:
		return
	var fx_root := Node2D.new()
	fx_root.position = world_pos
	fx_root.z_index = 500
	var attacker_name := attacker.character_name if attacker else ""
	var colors := _hit_fx_colors(blocked, heavy, attacker_name)
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

func _hit_fx_colors(blocked: bool, heavy: bool, attacker_name: String = "") -> Array[Color]:
	if attacker_name.to_lower() == "lobster":
		# Lobster hits should read as red/orange shell-and-claw impact, not Teknium green.
		if blocked:
			return [Color(1.0, 0.24, 0.08, 0.92), Color(1.0, 0.94, 0.78, 0.95), Color(1.0, 0.50, 0.12, 0.92)]
		if heavy:
			return [Color(1.0, 0.08, 0.02, 0.98), Color(1.0, 0.86, 0.54, 1.0), Color(1.0, 0.34, 0.02, 0.96)]
		return [Color(0.95, 0.12, 0.08, 0.92), Color(1.0, 0.86, 0.68, 0.95), Color(1.0, 0.38, 0.08, 0.88)]
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
	SoundManager.stop_music()
	app_state = AppState.GAME
	menu_index = 0
	if game_view:
		game_view.visible = true
	if stage and stage.has_method("set_stage_theme"):
		stage.set_stage_theme("city")
	_hide_result_panel()
	_hide_combat_overlay()
	_set_game_hud_visible(true)
	if p1:
		p1.set_character(selected_p1_fighter_name)
	if p2:
		p2.set_character(selected_p2_fighter_name)
	if p1_health_widget and p1_health_widget.has_method("configure"):
		p1_health_widget.configure(selected_p1_fighter_name, "P1")
	if p2_health_widget and p2_health_widget.has_method("configure"):
		p2_health_widget.configure(selected_p2_fighter_name, "AI")
	current_round = 1
	p1_round_wins = 0
	p2_round_wins = 0
	if ai:
		ai.set_difficulty(CPU_DIFFICULTIES[option_difficulty_index])
		ai.reset()
	_update_round_dots()
	# Round-start presentation is handled by _show_combat_overlay() in
	# _start_next_round(); keep the old sliding start banner off gameplay.
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
	# Match-end presentation now uses the same polished combat overlay system as
	# round start / round over. Keep the legacy result-panel nodes hidden so the
	# old boxed result card cannot stack behind the new overlay.
	_hide_result_panel()
	var accent := Color(0.20, 1.0, 0.52) if winner == 1 else Color(1.0, 0.34, 0.58)
	_show_combat_overlay("SIMULATION RESULT", "P%d DOMINANT // ENTER FOR MENU" % winner, accent, 0.0)

func _enter_menu() -> void:
	app_state = AppState.MENU
	menu_index = 0
	fighter_select_index = 0
	fighter_select_side = 0
	option_index = 0
	intro_active = false
	intro_token += 1
	if game_view:
		game_view.visible = false
	_hide_result_panel()
	_hide_combat_overlay()
	if announcement_label:
		announcement_label.visible = false
	start_banner_timer = 0.0
	if start_banner_panel:
		start_banner_panel.visible = false
	if start_banner_label:
		start_banner_label.visible = false
	_set_game_hud_visible(false)
	if p1:
		p1.control_enabled = false
		p1.ai_input = {}
		p1._set_animation("idle")
	if p2:
		p2.control_enabled = false
		p2.ai_input = {}
		p2._set_animation("idle")
	SoundManager.play_music("menu_theme", 0.50)
	if not boot_intro_seen and boot_overlay:
		_start_boot_intro()
	_update_menu_ui()

func _process_menu_input() -> void:
	match app_state:
		AppState.MENU:
			if Input.is_action_just_pressed("p1_up"):
				menu_index = posmod(menu_index - 1, 3)
				SoundManager.play("menu_cursor", 0.42)
			elif Input.is_action_just_pressed("p1_down"):
				menu_index = posmod(menu_index + 1, 3)
				SoundManager.play("menu_cursor", 0.42)
			elif Input.is_action_just_pressed("p1_start"):
				SoundManager.play("menu_select", 0.50)
				match menu_index:
					0:
						app_state = AppState.FIGHTER_SELECT
						fighter_select_side = 0
						fighter_select_index = FIGHTER_PLACEHOLDERS.find(selected_p1_fighter_name)
						if fighter_select_index < 0:
							fighter_select_index = 0
					1:
						app_state = AppState.CONTROLS
					2:
						app_state = AppState.OPTIONS
		AppState.FIGHTER_SELECT:
			if Input.is_action_just_pressed("p1_left") or Input.is_action_just_pressed("p1_right"):
				fighter_select_side = 1 - fighter_select_side
				SoundManager.play("menu_cursor", 0.42)
				fighter_select_index = FIGHTER_PLACEHOLDERS.find(selected_p2_fighter_name if fighter_select_side == 1 else selected_p1_fighter_name)
				if fighter_select_index < 0 or _is_fighter_locked(FIGHTER_PLACEHOLDERS[fighter_select_index]):
					fighter_select_index = _first_unlocked_fighter_index()
			elif Input.is_action_just_pressed("p1_up"):
				_step_fighter_select(-1)
				SoundManager.play("menu_cursor", 0.42)
			elif Input.is_action_just_pressed("p1_down"):
				_step_fighter_select(1)
				SoundManager.play("menu_cursor", 0.42)
			elif Input.is_action_just_pressed("p1_start"):
				SoundManager.play("menu_select", 0.50)
				if _is_fighter_locked(FIGHTER_PLACEHOLDERS[fighter_select_index]):
					fighter_select_index = _first_unlocked_fighter_index()
				_set_selected_fighter_for_side(FIGHTER_PLACEHOLDERS[fighter_select_index])
				if fighter_select_side == 0:
					fighter_select_side = 1
					fighter_select_index = FIGHTER_PLACEHOLDERS.find(selected_p2_fighter_name)
					if fighter_select_index < 0 or _is_fighter_locked(FIGHTER_PLACEHOLDERS[fighter_select_index]):
						fighter_select_index = _first_unlocked_fighter_index()
				else:
					_start_match()
			elif Input.is_action_just_pressed("p1_punch_light"):
				app_state = AppState.MENU
		AppState.CONTROLS:
			if Input.is_action_just_pressed("p1_start") or Input.is_action_just_pressed("p1_punch_light"):
				app_state = AppState.MENU
		AppState.OPTIONS:
			if Input.is_action_just_pressed("p1_up"):
				option_index = posmod(option_index - 1, OPTION_COUNT)
			elif Input.is_action_just_pressed("p1_down"):
				option_index = posmod(option_index + 1, OPTION_COUNT)
			elif Input.is_action_just_pressed("p1_left"):
				_adjust_option(-1)
			elif Input.is_action_just_pressed("p1_right"):
				_adjust_option(1)
			elif Input.is_action_just_pressed("p1_start") or Input.is_action_just_pressed("p1_punch_light"):
				app_state = AppState.MENU

func _is_fighter_locked(fighter_name: String) -> bool:
	return LOCKED_FIGHTERS.has(fighter_name)

func _first_unlocked_fighter_index() -> int:
	for i in range(FIGHTER_PLACEHOLDERS.size()):
		if not _is_fighter_locked(FIGHTER_PLACEHOLDERS[i]):
			return i
	return 0

func _step_fighter_select(delta: int) -> void:
	if FIGHTER_PLACEHOLDERS.is_empty():
		fighter_select_index = 0
		return
	for _attempt in range(FIGHTER_PLACEHOLDERS.size()):
		fighter_select_index = posmod(fighter_select_index + delta, FIGHTER_PLACEHOLDERS.size())
		var fighter_name: String = FIGHTER_PLACEHOLDERS[fighter_select_index]
		if not _is_fighter_locked(fighter_name):
			_set_selected_fighter_for_side(fighter_name)
			return
	fighter_select_index = 0

func _set_selected_fighter_for_side(fighter_name: String) -> void:
	if _is_fighter_locked(fighter_name):
		return
	if fighter_select_side == 0:
		selected_p1_fighter_name = fighter_name
	else:
		selected_p2_fighter_name = fighter_name

func _adjust_option(delta: int) -> void:
	match option_index:
		0:
			option_difficulty_index = posmod(option_difficulty_index + delta, CPU_DIFFICULTIES.size())
		1:
			option_sfx_volume = clampi(option_sfx_volume + delta * 5, 0, 100)
			SoundManager.set_sfx_volume_percent(option_sfx_volume)
		2:
			option_music_volume = clampi(option_music_volume + delta * 5, 0, 100)
			SoundManager.set_music_volume_percent(option_music_volume)
		3:
			option_radio_index += delta
			SoundManager.set_radio_channel(option_radio_index)

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

func _make_panel(pos: Vector2, panel_size: Vector2, fill_color: Color, border_color: Color, border_width: int = 1, radius: int = 8) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _set_panel_colors(panel: Panel, fill_color: Color, border_color: Color) -> void:
	if not panel:
		return
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.bg_color = fill_color
		style.border_color = border_color

func _create_menu_ui() -> void:
	menu_overlay = ColorRect.new()
	menu_overlay.position = Vector2.ZERO
	menu_overlay.size = Vector2(SCREEN_WIDTH, 288)
	menu_overlay.color = Color(0.01, 0.02, 0.03, 1.0)
	_ui_add_child(menu_overlay)

	menu_panel_back = _make_panel(Vector2(54, 24), Vector2(404, 236), Color(0.0, 0.85, 0.72, 0.18), Color(0.0, 0.95, 0.82, 0.34), 2, 13)
	_ui_add_child(menu_panel_back)

	menu_panel = _make_panel(Vector2(58, 28), Vector2(396, 228), Color(0.03, 0.05, 0.08, 0.96), Color(0.08, 0.42, 0.48, 0.65), 1, 11)
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
	menu_subtitle_label.add_theme_font_override("font", JP_UI_FONT)
	menu_subtitle_label.add_theme_font_size_override("font_size", 11)
	menu_subtitle_label.add_theme_color_override("font_color", Color(0.42, 0.76, 0.78))
	_ui_add_child(menu_subtitle_label)

	menu_body_label = Label.new()
	menu_body_label.position = Vector2(92, 102)
	menu_body_label.size = Vector2(328, 106)
	menu_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	menu_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	menu_body_label.add_theme_font_override("font", JP_UI_FONT)
	menu_body_label.add_theme_font_size_override("font_size", 15)
	menu_body_label.add_theme_color_override("font_color", Color(0.86, 0.94, 0.98))
	_ui_add_child(menu_body_label)

	for i in range(FIGHTER_PLACEHOLDERS.size()):
		var x := 82 + i * 116
		var back := _make_panel(Vector2(x, 100), Vector2(104, 94), Color(0.0, 0.85, 0.72, 0.14), Color(0.0, 0.95, 0.82, 0.30), 2, 8)
		_ui_add_child(back)
		fighter_card_backs.append(back)

		var fill := _make_panel(Vector2(x + 2, 102), Vector2(100, 90), Color(0.06, 0.09, 0.13, 0.98), Color(0.10, 0.36, 0.42, 0.45), 1, 7)
		_ui_add_child(fill)
		fighter_card_fills.append(fill)

		var label := Label.new()
		label.position = Vector2(x + 8, 106)
		label.size = Vector2(88, 16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.90, 0.98, 1.0))
		label.text = FIGHTER_PLACEHOLDERS[i]
		_ui_add_child(label)
		fighter_card_labels.append(label)

		var portrait_frame := _make_panel(Vector2(x + 28, 124), Vector2(48, 48), Color(0.02, 0.09, 0.11, 0.82), Color(0.0, 0.95, 0.82, 0.58), 2, 8)
		_ui_add_child(portrait_frame)
		fighter_card_portrait_frames.append(portrait_frame)

		var portrait := TextureRect.new()
		portrait.position = Vector2(x + 30, 126)
		portrait.size = Vector2(44, 44)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		portrait.texture = _get_fighter_select_portrait(FIGHTER_PLACEHOLDERS[i])
		portrait.modulate = Color(1.0, 1.0, 1.0, 0.96) if portrait.texture else Color(0.05, 0.85, 0.75, 0.18)
		_ui_add_child(portrait)
		fighter_card_portraits.append(portrait)

		var tag := Label.new()
		tag.position = Vector2(x + 6, 175)
		tag.size = Vector2(92, 12)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.add_theme_font_override("font", JP_UI_FONT)
		tag.add_theme_font_size_override("font_size", 8)
		tag.add_theme_color_override("font_color", Color(0.45, 0.75, 0.82))
		tag.text = "PLACEHOLDER"
		_ui_add_child(tag)
		fighter_card_tags.append(tag)

	fighter_select_desc_label = Label.new()
	fighter_select_desc_label.position = Vector2(90, 199)
	fighter_select_desc_label.size = Vector2(332, 30)
	fighter_select_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fighter_select_desc_label.add_theme_font_override("font", JP_UI_FONT)
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

	# Coarse local panel lines stay very subtle; the actual CRT treatment is the
	# full-screen shader overlay below. Plain ColorRect stripes looked like UI
	# rulers rather than a capture-through-a-monitor scanline effect.
	for i in range(72):
		var global_line := ColorRect.new()
		global_line.position = Vector2(0, i * 4)
		global_line.size = Vector2(SCREEN_WIDTH, 1)
		global_line.color = Color(0.0, 0.0, 0.0, 0.035)
		_ui_add_child(global_line)
		menu_global_scanlines.append(global_line)

	start_banner_panel = _make_panel(Vector2(-360, 118), Vector2(360, 50), Color(0.02, 0.09, 0.11, 0.92), Color(0.0, 0.95, 0.82, 0.86), 2, 10)
	start_banner_panel.visible = false
	_ui_add_child(start_banner_panel)

	start_banner_label = Label.new()
	start_banner_label.position = Vector2(-346, 130)
	start_banner_label.size = Vector2(332, 24)
	start_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_banner_label.add_theme_font_size_override("font_size", 18)
	start_banner_label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.96))
	start_banner_label.text = "SIMULATION BOOT // ENGAGE"
	start_banner_label.visible = false
	_ui_add_child(start_banner_label)

	menu_crt_overlay = ColorRect.new()
	menu_crt_overlay.name = "MenuCRTScanlineOverlay"
	menu_crt_overlay.position = Vector2.ZERO
	menu_crt_overlay.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	menu_crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crt_shader := Shader.new()
	crt_shader.code = """
shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float time_offset = 0.0;
uniform float dark_strength = 0.22;
uniform float glow_strength = 0.040;
uniform float vignette_strength = 0.16;

void fragment() {
	vec2 p = FRAGCOORD.xy;
	float row = mod(floor(p.y), 4.0);
	float dark_row = 1.0 - step(2.0, row);
	float phosphor_row = 1.0 - abs(fract(p.y * 0.5) * 2.0 - 1.0);
	float roll = 0.5 + 0.5 * sin((p.y * 0.085) + time_offset * 3.1);
	float flicker = 0.5 + 0.5 * sin(time_offset * 17.0 + p.y * 0.012);
	float rgb_mask = step(0.58, fract(p.x / 3.0));
	float dist = distance(UV, vec2(0.5, 0.52));
	float vignette = smoothstep(0.34, 0.76, dist);
	float alpha = dark_row * (dark_strength + roll * 0.035 + flicker * 0.018);
	alpha += phosphor_row * glow_strength;
	alpha += rgb_mask * 0.018;
	alpha += vignette * vignette_strength;
	vec3 tint = mix(vec3(0.0, 0.012, 0.018), vec3(0.0, 0.20, 0.18), phosphor_row * 0.18);
	COLOR = vec4(tint, clamp(alpha, 0.0, 0.42));
}
"""
	var crt_mat := ShaderMaterial.new()
	crt_mat.shader = crt_shader
	menu_crt_overlay.material = crt_mat
	_ui_add_child(menu_crt_overlay)

func _create_gameplay_pixel_shift_overlay() -> void:
	gameplay_pixel_shift_overlay = ColorRect.new()
	gameplay_pixel_shift_overlay.name = "SignalStaticGlitchOverlay"
	gameplay_pixel_shift_overlay.position = Vector2.ZERO
	gameplay_pixel_shift_overlay.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	gameplay_pixel_shift_overlay.color = Color(1, 1, 1, 1)
	gameplay_pixel_shift_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_pixel_shift_overlay.visible = false
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float time_offset = 0.0;
uniform float distortion_strength = 0.0032;
uniform float static_strength = 0.038;
uniform float patch_strength = 0.66;
uniform float scanline_strength = 0.032;
uniform float glitch_visibility = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float rect_mask(vec2 uv, vec2 center, vec2 half_size, float feather) {
	vec2 d = abs(uv - center) - half_size;
	float outside = length(max(d, vec2(0.0)));
	float inside = min(max(d.x, d.y), 0.0);
	return 1.0 - smoothstep(0.0, feather, outside + inside);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float tick = floor(time_offset * 6.0);
	float slow_tick = floor(time_offset * 1.35);
	vec2 px = vec2(1.0 / 512.0, 1.0 / 288.0);

	// Static-distortion direction: visible in motion, but mostly localized.
	// This is closer to the earlier signal pass than the too-subtle pixel LCD pass.
	float edge = smoothstep(0.64, 0.98, abs(UV.x - 0.5) * 2.0);
	float band_a = rect_mask(UV, vec2(0.18 + 0.06 * hash(vec2(slow_tick, 1.0)), 0.24 + 0.18 * hash(vec2(slow_tick, 2.0))), vec2(0.11, 0.020), 0.012);
	float band_b = rect_mask(UV, vec2(0.74 + 0.08 * hash(vec2(slow_tick, 3.0)), 0.54 + 0.22 * hash(vec2(slow_tick, 4.0))), vec2(0.15, 0.026), 0.014);
	float chip_a = rect_mask(UV, vec2(0.08 + 0.84 * hash(vec2(slow_tick, 5.0)), 0.14 + 0.72 * hash(vec2(slow_tick, 6.0))), vec2(0.030, 0.050), 0.010);
	float patch = max(max(band_a, band_b), chip_a * 0.72);
	float burst_gate = step(0.56, hash(vec2(tick, slow_tick + 17.0)));
	patch *= burst_gate * glitch_visibility;

	float row_noise = hash(vec2(floor(UV.y * 120.0), tick));
	float wobble = (row_noise - 0.5) * distortion_strength * (0.35 + patch * patch_strength + edge * 0.25);
	vec2 sample_uv = uv + vec2(wobble, 0.0);

	vec3 base = texture(screen_texture, sample_uv).rgb;
	vec3 col = base;

	float grain = hash(floor(UV * vec2(512.0, 288.0)) + vec2(tick * 19.0, tick * 7.0)) - 0.5;
	float scanline = sin((UV.y * 288.0 + time_offset * 16.0) * 3.14159);
	float scan = scanline * scanline_strength;
	float noise_mask = (0.16 + patch * 1.20 + edge * 0.18) * (0.35 + glitch_visibility * 0.65);
	col += vec3(grain * static_strength * noise_mask);
	col -= vec3(scan * 0.032);

	// Short chroma smear inside patches only; this makes the glitch readable without
	// returning to random pixel snow.
	vec3 shifted = col;
	shifted.r = texture(screen_texture, sample_uv + vec2(px.x * (1.0 + patch * 3.0), 0.0)).r;
	shifted.b = texture(screen_texture, sample_uv - vec2(px.x * (1.0 + patch * 3.0), 0.0)).b;
	col = mix(col, shifted + vec3(0.035, 0.0, 0.070) * patch, patch * 0.58);

	// Broken LCD edge twitch, intentionally not full-screen.
	float edge_spark = step(0.982, hash(vec2(floor(UV.y * 72.0), tick * 3.0))) * edge * glitch_visibility;
	col += vec3(0.060, 0.16, 0.20) * edge_spark * 0.20;

	// The actual CRT border is a separate alpha overlay above this screen-reading
	// shader. Keeping it separate avoids UV/camera/subviewport ambiguity here.
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	gameplay_pixel_shift_overlay.material = mat
	_ui_add_child(gameplay_pixel_shift_overlay)

func _create_crt_vignette_overlay() -> void:
	crt_vignette_overlay = ColorRect.new()
	crt_vignette_overlay.name = "CRTRoundedVignetteOverlay"
	crt_vignette_overlay.position = Vector2.ZERO
	crt_vignette_overlay.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	crt_vignette_overlay.color = Color(1, 1, 1, 1)
	crt_vignette_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt_vignette_overlay.visible = false
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float vignette_strength = 0.36;
uniform float edge_strength = 0.114;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.008, 0.012, 1.0);

void fragment() {
	vec2 uv = UV;
	vec2 centered = uv - vec2(0.5);
	vec2 lens = centered * vec2(1.0, 1.42);
	float radial = length(lens);
	float corner = smoothstep(0.36, 0.72, radial);
	float edge_x = smoothstep(0.38, 0.50, abs(centered.x));
	float edge_y = smoothstep(0.38, 0.50, abs(centered.y));
	float edge = max(edge_x, edge_y) * edge_strength;
	float alpha = clamp(corner * vignette_strength + edge, 0.0, 0.42);
	COLOR = vec4(vignette_color.rgb, alpha);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	crt_vignette_overlay.material = mat
	_ui_add_child(crt_vignette_overlay)

func _update_gameplay_pixel_shift_overlay(delta: float) -> void:
	if not gameplay_pixel_shift_overlay:
		return
	gameplay_pixel_shift_time += delta
	if signal_glitch_suppress_timer > 0.0:
		signal_glitch_suppress_timer = maxf(0.0, signal_glitch_suppress_timer - delta)
	if signal_hit_glitch_timer > 0.0:
		signal_hit_glitch_timer = maxf(0.0, signal_hit_glitch_timer - delta)
	else:
		signal_hit_glitch_strength = move_toward(signal_hit_glitch_strength, 0.0, delta * 7.0)
	var ambient_glitch_visibility := 0.05 if app_state != AppState.GAME else 0.42
	if signal_glitch_suppress_timer > 0.0:
		ambient_glitch_visibility = 0.0
	var target_glitch_visibility := maxf(ambient_glitch_visibility, signal_hit_glitch_strength)
	signal_glitch_visibility = move_toward(signal_glitch_visibility, target_glitch_visibility, delta * 8.0)
	gameplay_pixel_shift_overlay.visible = not boot_intro_active
	if crt_vignette_overlay:
		crt_vignette_overlay.visible = not boot_intro_active
	if gameplay_pixel_shift_overlay.material is ShaderMaterial:
		var mat := gameplay_pixel_shift_overlay.material as ShaderMaterial
		mat.set_shader_parameter("time_offset", gameplay_pixel_shift_time)
		mat.set_shader_parameter("glitch_visibility", signal_glitch_visibility)

func _create_boot_intro_ui() -> void:
	boot_overlay = ColorRect.new()
	boot_overlay.name = "HackfighterBootIntro"
	boot_overlay.position = Vector2.ZERO
	boot_overlay.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	boot_overlay.color = Color(0.002, 0.006, 0.010, 1.0)
	boot_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boot_overlay.visible = false
	_ui_add_child(boot_overlay)

	boot_logo_label = Label.new()
	boot_logo_label.position = Vector2(42, 82)
	boot_logo_label.size = Vector2(428, 46)
	boot_logo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boot_logo_label.add_theme_font_override("font", JP_UI_FONT)
	boot_logo_label.add_theme_font_size_override("font_size", 34)
	boot_logo_label.add_theme_color_override("font_color", Color(0.90, 0.96, 0.98))
	boot_logo_label.text = "HACKFIGHTER"
	boot_logo_label.visible = false
	_ui_add_child(boot_logo_label)

	boot_subtitle_label = Label.new()
	boot_subtitle_label.position = Vector2(56, 124)
	boot_subtitle_label.size = Vector2(400, 26)
	boot_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boot_subtitle_label.add_theme_font_override("font", JP_UI_FONT)
	boot_subtitle_label.add_theme_font_size_override("font_size", 15)
	boot_subtitle_label.add_theme_color_override("font_color", Color(0.70, 0.94, 0.94))
	boot_subtitle_label.text = "起動中 // 侵入格闘システム"
	boot_subtitle_label.visible = false
	_ui_add_child(boot_subtitle_label)

	var code_lines := ["CONNECTING TO NOUS GRID...", "LOADING TEKNIUM COMBAT KERNEL", "LOCKING UNIMPLEMENTED SLOTS", "READY / MENU HANDOFF"]
	for i in range(code_lines.size()):
		var line := Label.new()
		line.position = Vector2(82, 154 + i * 15)
		line.size = Vector2(348, 14)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_theme_font_override("font", JP_UI_FONT)
		line.add_theme_font_size_override("font_size", 10)
		line.add_theme_color_override("font_color", Color(0.70, 0.82, 0.84))
		line.text = code_lines[i]
		line.visible = false
		_ui_add_child(line)
		boot_code_labels.append(line)

	boot_progress_panel = _make_panel(Vector2(126, 218), Vector2(260, 10), Color(0.01, 0.04, 0.05, 0.96), Color(0.0, 0.88, 0.78, 0.62), 1, 3)
	boot_progress_panel.visible = false
	_ui_add_child(boot_progress_panel)

	boot_progress_fill = ColorRect.new()
	boot_progress_fill.position = Vector2(129, 221)
	boot_progress_fill.size = Vector2(0, 6)
	boot_progress_fill.color = Color(0.80, 1.0, 0.96, 1.0)
	boot_progress_fill.visible = false
	_ui_add_child(boot_progress_fill)

	boot_status_label = Label.new()
	boot_status_label.position = Vector2(92, 236)
	boot_status_label.size = Vector2(328, 16)
	boot_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boot_status_label.add_theme_font_override("font", JP_UI_FONT)
	boot_status_label.add_theme_font_size_override("font_size", 11)
	boot_status_label.add_theme_color_override("font_color", Color(0.78, 0.92, 0.94))
	boot_status_label.text = "PRESS START AFTER BOOT"
	boot_status_label.visible = false
	_ui_add_child(boot_status_label)

func _start_boot_intro() -> void:
	boot_intro_active = true
	boot_intro_seen = true
	boot_intro_time = 0.0
	SoundManager.play("menu_open", 0.30)
	_set_boot_intro_visible(true)
	_update_boot_intro(0.0)

func _set_boot_intro_visible(visible: bool) -> void:
	if boot_overlay: boot_overlay.visible = visible
	if boot_logo_label: boot_logo_label.visible = visible
	if boot_subtitle_label: boot_subtitle_label.visible = visible
	if boot_status_label: boot_status_label.visible = visible
	if boot_progress_panel: boot_progress_panel.visible = visible
	if boot_progress_fill: boot_progress_fill.visible = visible
	for line in boot_code_labels:
		if line: line.visible = visible

func _update_boot_intro(delta: float) -> void:
	if not boot_intro_active:
		return
	boot_intro_time += delta
	var t := clampf(boot_intro_time / BOOT_INTRO_DURATION, 0.0, 1.0)
	var logo_alpha := smoothstep(0.02, 0.22, t) * (1.0 - smoothstep(0.88, 1.0, t))
	var pulse := 0.86 + 0.14 * sin(boot_intro_time * 13.0)
	if boot_overlay:
		boot_overlay.color = Color(0.002, 0.006 + t * 0.012, 0.010 + t * 0.018, 1.0 - smoothstep(0.86, 1.0, t))
	if boot_logo_label:
		boot_logo_label.modulate = Color(0.88 + pulse * 0.10, 0.96, 0.98, logo_alpha)
		boot_logo_label.position.x = 42.0 + sin(boot_intro_time * 19.0) * (1.8 if t < 0.32 else 0.35)
	if boot_subtitle_label:
		boot_subtitle_label.modulate = Color(1.0, 1.0, 1.0, smoothstep(0.08, 0.24, t) * (1.0 - smoothstep(0.90, 1.0, t)))
	for i in range(boot_code_labels.size()):
		var line := boot_code_labels[i]
		var line_on := smoothstep(0.14 + float(i) * 0.08, 0.20 + float(i) * 0.08, t)
		line.modulate = Color(1.0, 1.0, 1.0, line_on * (1.0 - smoothstep(0.90, 1.0, t)))
	if boot_progress_fill:
		boot_progress_fill.size.x = 254.0 * smoothstep(0.22, 0.88, t)
		boot_progress_fill.modulate = Color(0.78, 0.96, 0.94, 0.80 + sin(boot_intro_time * 22.0) * 0.16)
	if boot_status_label:
		boot_status_label.text = "SYSTEM ONLINE" if t > 0.82 else "BOOT %.0f%%" % [t * 100.0]
		boot_status_label.modulate = Color(1.0, 1.0, 1.0, smoothstep(0.34, 0.52, t) * (1.0 - smoothstep(0.92, 1.0, t)))
	if boot_intro_time >= BOOT_INTRO_DURATION:
		boot_intro_active = false
		_set_boot_intro_visible(false)
		SoundManager.play("menu_select", 0.38)

func _get_fighter_select_portrait(fighter_name: String) -> Texture2D:
	match fighter_name:
		"TEKNIUM":
			return load("res://assets/ui/hero_profile.png") as Texture2D
		"LOBSTER":
			return load("res://assets/ui/hero_profile_lobster.png") as Texture2D
		_:
			return null

func _update_menu_ui() -> void:
	var visible := app_state != AppState.GAME
	if menu_overlay: menu_overlay.visible = visible
	if menu_panel_back: menu_panel_back.visible = visible
	if menu_panel: menu_panel.visible = visible
	for line in menu_scanlines:
		if line: line.visible = visible
	for line in menu_global_scanlines:
		if line: line.visible = visible
	if menu_crt_overlay: menu_crt_overlay.visible = visible
	if menu_title_label: menu_title_label.visible = visible
	if menu_subtitle_label: menu_subtitle_label.visible = visible and (app_state == AppState.MENU or app_state == AppState.FIGHTER_SELECT)
	if menu_body_label: menu_body_label.visible = visible
	if menu_hint_label: menu_hint_label.visible = visible
	if fighter_select_desc_label: fighter_select_desc_label.visible = visible and app_state == AppState.FIGHTER_SELECT
	for node in fighter_card_backs:
		if node: node.visible = visible and app_state == AppState.FIGHTER_SELECT
	for node in fighter_card_fills:
		if node: node.visible = visible and app_state == AppState.FIGHTER_SELECT
	for node in fighter_card_portrait_frames:
		if node: node.visible = visible and app_state == AppState.FIGHTER_SELECT
	for node in fighter_card_portraits:
		if node: node.visible = visible and app_state == AppState.FIGHTER_SELECT
	for node in fighter_card_labels:
		if node: node.visible = visible and app_state == AppState.FIGHTER_SELECT
	for node in fighter_card_tags:
		if node: node.visible = visible and app_state == AppState.FIGHTER_SELECT
	if not visible:
		return
	menu_subtitle_label.text = "ハックファイター"
	menu_body_label.position = Vector2(92, 102)
	menu_body_label.size = Vector2(328, 106)
	menu_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	menu_body_label.add_theme_font_size_override("font_size", 15)
	menu_body_label.add_theme_color_override("font_color", Color(0.84, 0.90, 0.92))
	match app_state:
		AppState.MENU:
			menu_body_label.position = Vector2(106, 104)
			menu_body_label.size = Vector2(300, 96)
			menu_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			menu_title_label.text = "HACKFIGHTER"
			var items := ["START SIMULATION", "CONTROL MAP", "SYSTEM OPTIONS"]
			var lines: Array[String] = []
			for i in range(items.size()):
				lines.append(("「 %s 」" % items[i]) if i == menu_index else items[i])
			menu_body_label.text = "\n".join(lines)
			menu_hint_label.text = "NAV: W/S   CONFIRM: ENTER"
		AppState.FIGHTER_SELECT:
			menu_title_label.text = "FIGHTER SELECT"
			menu_subtitle_label.text = "戦士選択"
			menu_body_label.text = ""
			var active_side_label := "P1" if fighter_select_side == 0 else "AI/P2"
			fighter_select_desc_label.text = "選択中 %s     P1:%s   AI:%s" % [active_side_label, selected_p1_fighter_name, selected_p2_fighter_name]
			fighter_select_desc_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.90))
			for i in range(FIGHTER_PLACEHOLDERS.size()):
				var fighter_name: String = FIGHTER_PLACEHOLDERS[i]
				var locked := _is_fighter_locked(fighter_name)
				var cursor_here: bool = i == fighter_select_index
				var p1_here: bool = fighter_name == selected_p1_fighter_name
				var p2_here: bool = fighter_name == selected_p2_fighter_name
				var active_pick_here: bool = not locked and ((fighter_select_side == 0 and p1_here) or (fighter_select_side == 1 and p2_here))
				if locked:
					_set_panel_colors(fighter_card_backs[i], Color(0.08, 0.09, 0.10, 0.42), Color(0.40, 0.48, 0.50, 0.24))
					_set_panel_colors(fighter_card_fills[i], Color(0.025, 0.03, 0.04, 0.94), Color(0.24, 0.30, 0.32, 0.28))
					_set_panel_colors(fighter_card_portrait_frames[i], Color(0.02, 0.025, 0.03, 0.72), Color(0.42, 0.48, 0.50, 0.22))
				else:
					var active_border := Color(0.0, 0.95, 0.82, 0.78 if active_pick_here else (0.58 if cursor_here else 0.30))
					_set_panel_colors(fighter_card_backs[i], Color(0.0, 0.85, 0.72, 0.18 if active_pick_here else (0.13 if cursor_here else 0.08)), active_border)
					_set_panel_colors(fighter_card_fills[i], Color(0.08, 0.13, 0.18, 1.0) if active_pick_here else Color(0.05, 0.08, 0.11, 0.98), Color(0.10, 0.36, 0.42, 0.56 if cursor_here else 0.36))
					_set_panel_colors(fighter_card_portrait_frames[i], Color(0.02, 0.09, 0.11, 0.88), active_border)
				fighter_card_labels[i].modulate = Color(0.92, 0.96, 0.98, 1.0) if active_pick_here else (Color(0.46, 0.52, 0.54, 0.62) if locked else Color(0.78, 0.84, 0.88, 0.92))
				var portrait_alpha := 0.12 if locked else (1.0 if active_pick_here else (0.88 if cursor_here else 0.68))
				if fighter_card_portraits[i].texture:
					fighter_card_portraits[i].modulate = Color(1.0, 1.0, 1.0, portrait_alpha)
				else:
					fighter_card_portraits[i].modulate = Color(0.46, 0.52, 0.54, 0.10) if locked else Color(0.05, 0.85, 0.75, 0.18 if cursor_here else 0.10)
				var badges: Array[String] = []
				if locked:
					fighter_card_tags[i].text = "未実装"
					fighter_card_tags[i].modulate = Color(0.54, 0.60, 0.62, 0.78)
					continue
				if p1_here:
					badges.append("P1")
				if p2_here:
					badges.append("AI")
				if badges.is_empty():
					badges.append("STARTER" if fighter_name == "LOBSTER" else "SLOT")
				fighter_card_tags[i].text = "/".join(badges) + " • " + ("ACTIVE" if active_pick_here else ("CURSOR" if cursor_here else "READY"))
				fighter_card_tags[i].modulate = Color(0.86, 0.92, 0.94, 1.0) if active_pick_here else Color(0.66, 0.74, 0.78, 0.88)
			menu_hint_label.text = "PICK: W/S   SIDE: A/D   ENTER: CONFIRM/NEXT   BACK: U/J"
		AppState.CONTROLS:
			menu_title_label.text = "CONTROL MAP"
			menu_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			menu_body_label.text = "MOVE      A / D\nJUMP      W\nCROUCH    S\nLP        U or J\nHP        I or K\nLK        O or L\nHK        P or ;"
			menu_hint_label.text = "RETURN: ENTER OR U/J"
		AppState.OPTIONS:
			menu_title_label.text = "SYSTEM OPTIONS"
			menu_body_label.position = Vector2(78, 94)
			menu_body_label.size = Vector2(356, 122)
			menu_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			menu_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			menu_body_label.add_theme_font_size_override("font_size", 11)
			var radio_label := SoundManager.get_radio_channel_label()
			if radio_label == "":
				radio_label = "NO CHANNELS INSTALLED"
			var option_rows := [
				["CPU PROFILE", "< %s >" % CPU_DIFFICULTIES[option_difficulty_index]],
				["SFX BUS", "< %d%% >" % option_sfx_volume],
				["MUSIC BUS", "< %d%% >" % option_music_volume],
				["RADIO CHANNEL", "< %s >" % radio_label],
			]
			var option_lines: Array[String] = []
			for i in range(option_rows.size()):
				var prefix := "[>]" if i == option_index else "[ ]"
				option_lines.append("%-4s %-14s %s" % [prefix, option_rows[i][0], option_rows[i][1]])
			menu_body_label.text = "\n".join(option_lines)
			menu_hint_label.text = "NAV: W/S   CHANGE: A/D   RETURN: ENTER OR U/J"

func _animate_menu_ui() -> void:
	var pulse := 0.22 + 0.06 * sin(menu_fx_time * 1.9)
	if menu_panel_back:
		_set_panel_colors(menu_panel_back, Color(0.0, 0.85, 0.72, pulse * 0.72), Color(0.0, 0.95, 0.82, 0.28 + pulse))
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
	for i in range(menu_global_scanlines.size()):
		var global_line := menu_global_scanlines[i]
		if global_line:
			global_line.modulate.a = 0.025 + 0.02 * (0.5 + 0.5 * sin(menu_fx_time * 2.4 + float(i) * 0.22))
	if menu_crt_overlay and menu_crt_overlay.material is ShaderMaterial:
		(menu_crt_overlay.material as ShaderMaterial).set_shader_parameter("time_offset", menu_fx_time)

func _play_start_banner() -> void:
	if not (start_banner_panel and start_banner_label):
		return
	start_banner_timer = 1.35
	start_banner_panel.visible = true
	start_banner_label.visible = true
	_update_start_banner(0.0)

func _show_combat_overlay(title: String, detail: String, accent: Color, hold_time: float = 0.0) -> void:
	if not (combat_overlay_back and combat_overlay_panel and combat_overlay_title_label and combat_overlay_detail_label):
		return
	combat_overlay_accent = accent
	combat_overlay_timer = hold_time
	_set_panel_colors(combat_overlay_back, Color(accent.r, accent.g, accent.b, 0.18), Color(accent.r, accent.g, accent.b, 0.55))
	_set_panel_colors(combat_overlay_panel, Color(0.015, 0.035, 0.048, 0.88), Color(accent.r, accent.g, accent.b, 0.78))
	combat_overlay_title_label.text = title
	combat_overlay_detail_label.text = detail
	combat_overlay_title_label.add_theme_color_override("font_color", Color(0.94, 1.0, 1.0))
	combat_overlay_detail_label.add_theme_color_override("font_color", Color(accent.r * 0.55 + 0.45, accent.g * 0.55 + 0.45, accent.b * 0.55 + 0.45, 1.0))
	combat_overlay_back.visible = true
	combat_overlay_panel.visible = true
	combat_overlay_title_label.visible = true
	combat_overlay_detail_label.visible = true
	_update_combat_overlay(0.0)

func _hide_combat_overlay() -> void:
	combat_overlay_timer = 0.0
	for node in [combat_overlay_back, combat_overlay_panel, combat_overlay_title_label, combat_overlay_detail_label]:
		if node:
			node.visible = false
	if announcement_label:
		announcement_label.visible = false

func _update_combat_overlay(delta: float) -> void:
	if not (combat_overlay_back and combat_overlay_panel and combat_overlay_title_label and combat_overlay_detail_label):
		return
	if not combat_overlay_panel.visible:
		return
	if combat_overlay_timer > 0.0:
		combat_overlay_timer = maxf(0.0, combat_overlay_timer - delta)
		if combat_overlay_timer <= 0.0:
			_hide_combat_overlay()
			return
	var t := Time.get_ticks_msec() * 0.001
	var pulse := 0.72 + 0.18 * sin(t * 7.0)
	combat_overlay_back.modulate = Color(1.0, 1.0, 1.0, 0.86 + 0.08 * sin(t * 3.1))
	combat_overlay_panel.modulate = Color(1.0, 1.0, 1.0, 0.92)
	combat_overlay_title_label.modulate = Color(1.0, 1.0, 1.0, pulse)
	combat_overlay_detail_label.modulate = Color(1.0, 1.0, 1.0, 0.76 + 0.12 * sin(t * 4.3))

func _update_start_banner(delta: float) -> void:
	if not (start_banner_panel and start_banner_label):
		return
	if start_banner_timer <= 0.0:
		return
	start_banner_timer = maxf(0.0, start_banner_timer - delta)
	var elapsed := 1.35 - start_banner_timer
	var slide := clampf(elapsed / 0.22, 0.0, 1.0)
	var fade := clampf(start_banner_timer / 0.25, 0.0, 1.0)
	var x := lerpf(-360.0, 76.0, 1.0 - pow(1.0 - slide, 3.0))
	start_banner_panel.position = Vector2(x, 118)
	start_banner_label.position = Vector2(x + 14.0, 130)
	start_banner_panel.modulate = Color(1, 1, 1, fade)
	start_banner_label.modulate = Color(1, 1, 1, fade)
	if start_banner_timer <= 0.0:
		start_banner_panel.visible = false
		start_banner_label.visible = false

func _set_game_hud_visible(vis: bool) -> void:
	var nodes = [
		gameplay_pixel_shift_overlay,
		crt_vignette_overlay,
		impact_flash,
		p1_health_widget, p2_health_widget,
		timer_backplate, timer_bg, timer_label,
	]
	for node in nodes:
		if node:
			node.visible = vis

func _play_profile_round_intro_fade() -> void:
	if p1_health_widget and p1_health_widget.has_method("play_round_intro_fade"):
		p1_health_widget.play_round_intro_fade(0.0)
	if p2_health_widget and p2_health_widget.has_method("play_round_intro_fade"):
		p2_health_widget.play_round_intro_fade(0.10)

func _start_next_round(first_round: bool = false) -> void:
	round_state = RoundState.PLAYING
	intro_active = true
	start_banner_timer = 0.0
	if start_banner_panel:
		start_banner_panel.visible = false
	if start_banner_label:
		start_banner_label.visible = false
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
	_play_profile_round_intro_fade()
	if announcement_label:
		announcement_label.visible = false
		announcement_label.text = ""
	_show_combat_overlay("ROUND %d" % current_round, "INITIALIZING COMBAT LINK", Color(0.0, 0.95, 0.82), 0.0)
	SoundManager.play_round_call(current_round, 0.75)
	await get_tree().create_timer(1.15).timeout
	if this_intro != intro_token:
		return
	_show_combat_overlay("READY", "SYNCHRONIZE INPUT // HOLD POSITION", Color(0.78, 1.0, 0.28), 0.0)
	SoundManager.play("ready", 0.75)
	await get_tree().create_timer(0.95).timeout
	if this_intro != intro_token:
		return
	_show_combat_overlay("ENGAGE", "SIMULATION LIVE", Color(0.18, 1.0, 0.56), 0.0)
	SoundManager.play("fight", 0.8)
	await get_tree().create_timer(0.45).timeout
	if this_intro != intro_token:
		return
	_hide_combat_overlay()
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
	var round_detail := ""
	var round_title := ""
	var accent := Color(0.0, 0.95, 0.82)
	if winner == 0:
		round_title = "ROUND DRAW"
		round_detail = "TIME LIMIT // NO CLEAR WINNER"
		accent = Color(0.70, 0.82, 1.0)
	elif by_ko:
		round_title = "TARGET DOWN"
		round_detail = "P%d TAKES ROUND %d" % [winner, current_round]
		accent = Color(0.20, 1.0, 0.52) if winner == 1 else Color(1.0, 0.34, 0.58)
	else:
		round_title = "TIME LIMIT"
		round_detail = "P%d TAKES ROUND %d" % [winner, current_round]
		accent = Color(0.78, 1.0, 0.28)
	_show_combat_overlay(round_title, round_detail, accent, 0.0)
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

	timer_backplate = ColorRect.new()
	timer_backplate.position = Vector2(229, 11)
	timer_backplate.size = Vector2(54, 18)
	# Dark translucent teal, matching the empty healthbar track family while
	# keeping the stage visible through the countdown hollow.
	timer_backplate.color = Color(0.02, 0.16, 0.16, 0.46)
	timer_backplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_add_child(timer_backplate)

	timer_bg = NinePatchRect.new()
	timer_bg.texture = load("res://assets/ui/countdown_timer.png")
	# Same scaling method as the approved healthbar outline: keep the raw
	# high-source art, use a sized NinePatchRect, and zero all patch margins so
	# Godot scales the authored image as one complete piece instead of reserving
	# or rendering at source dimensions.
	timer_bg.position = Vector2(224, 6)
	timer_bg.size = Vector2(64, 29)
	timer_bg.custom_minimum_size = Vector2.ZERO
	timer_bg.patch_margin_left = 0
	timer_bg.patch_margin_top = 0
	timer_bg.patch_margin_right = 0
	timer_bg.patch_margin_bottom = 0
	timer_bg.modulate = Color.WHITE
	timer_bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ui_add_child(timer_bg)

	timer_label = Label.new()
	timer_label.position = Vector2(237, 9)
	timer_label.size = Vector2(40, 18)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_override("font", HUD_FONT)
	timer_label.add_theme_font_size_override("font_size", 13)
	timer_label.add_theme_color_override("font_color", Color(0.62, 1.35, 1.14))
	timer_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.05, 0.07, 0.95))
	timer_label.add_theme_constant_override("shadow_offset_x", 1)
	timer_label.add_theme_constant_override("shadow_offset_y", 1)
	_ui_add_child(timer_label)

	timer_word_label = Label.new()
	# The replacement frame is already labeled by its shape/details; hide the old
	# TIME caption so the hollow center stays dedicated to the countdown digits.
	timer_word_label.visible = false
	timer_word_label.text = ""
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

	combat_overlay_back = _make_panel(Vector2(100, 92), Vector2(312, 90), Color(0.0, 0.92, 0.82, 0.18), Color(0.0, 0.95, 0.82, 0.54), 2, 11)
	combat_overlay_back.visible = false
	_ui_add_child(combat_overlay_back)

	combat_overlay_panel = _make_panel(Vector2(106, 98), Vector2(300, 78), Color(0.015, 0.035, 0.048, 0.90), Color(0.0, 0.95, 0.82, 0.78), 1, 9)
	combat_overlay_panel.visible = false
	_ui_add_child(combat_overlay_panel)

	combat_overlay_title_label = Label.new()
	combat_overlay_title_label.position = Vector2(118, 106)
	combat_overlay_title_label.size = Vector2(276, 34)
	combat_overlay_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_overlay_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combat_overlay_title_label.add_theme_font_override("font", HUD_FONT)
	combat_overlay_title_label.add_theme_font_size_override("font_size", 25)
	combat_overlay_title_label.add_theme_color_override("font_color", Color(0.94, 1.0, 1.0))
	combat_overlay_title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.03, 1.0))
	combat_overlay_title_label.add_theme_constant_override("shadow_offset_x", 2)
	combat_overlay_title_label.add_theme_constant_override("shadow_offset_y", 2)
	combat_overlay_title_label.visible = false
	_ui_add_child(combat_overlay_title_label)

	combat_overlay_detail_label = Label.new()
	combat_overlay_detail_label.position = Vector2(118, 140)
	combat_overlay_detail_label.size = Vector2(276, 22)
	combat_overlay_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_overlay_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combat_overlay_detail_label.add_theme_font_override("font", HUD_FONT)
	combat_overlay_detail_label.add_theme_font_size_override("font_size", 10)
	combat_overlay_detail_label.add_theme_color_override("font_color", Color(0.70, 1.0, 0.92))
	combat_overlay_detail_label.visible = false
	_ui_add_child(combat_overlay_detail_label)

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
		timer_label.add_theme_color_override("font_color", Color(1.35, 0.38, 0.54))
		timer_bg.modulate = Color(1.06, 0.78, 0.90, 1.0)
	else:
		timer_label.add_theme_color_override("font_color", Color(0.62, 1.35, 1.14))
		timer_bg.modulate = Color.WHITE
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
