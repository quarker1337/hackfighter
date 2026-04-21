extends Control

## Main game controller — Stoat Fighter 2 Godot port
## Coordinates game loop, camera, fighters, HUD, combat

@onready var p1: Player = %Player1
@onready var p2: Player = %Player2
@onready var camera: Camera2D = %Camera2D
@onready var debug_label: Label = $DebugLabel
@onready var stage: Node = %Stage
@onready var game_view: SubViewportContainer = $SubViewportContainer

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
var p1_health_bar: ColorRect = null
var p2_health_bar: ColorRect = null
var p1_health_bg: ColorRect = null
var p2_health_bg: ColorRect = null
var p1_health_border: ColorRect = null
var p2_health_border: ColorRect = null
var p1_health_label: Label = null
var p2_health_label: Label = null
var p1_name_label: Label = null
var p2_name_label: Label = null
var timer_label: Label = null
var announcement_label: Label = null
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
const CAMERA_Y := 144.0
const SCREEN_WIDTH := 512.0
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

var debug_timer := 0.0

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
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = CAMERA_SMOOTHING
	camera.make_current()

	# Create HUD
	_create_hud()
	_create_menu_ui()
	_enter_menu()

	# Show debug info for 3 seconds
	if debug_label:
		debug_timer = 3.0

func _process(delta: float) -> void:
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
			# AI drives P2 only during live rounds
			if p1 and p2 and ai:
				p2.ai_input = ai.get_input(p2, p1)

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
					announcement_label.text = "SIMULATION COMPLETE\nP%d DOMINANT\nPRESS ENTER FOR MENU" % (1 if p1_round_wins >= ROUNDS_TO_WIN else 2)
					announcement_label.visible = true
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

	# Camera tracking (midpoint between fighters)
	if p1 and p2:
		var stage_width: float = stage.get_stage_width() if stage and stage.has_method("get_stage_width") else STAGE_FLOOR_WIDTH
		var stage_left_min: float = stage.get_camera_left_min() if stage and stage.has_method("get_camera_left_min") else 160.0
		var cam_left := clampf((p1.position.x + p2.position.x) / 2.0 - VISIBLE_WIDTH / 2.0, stage_left_min, stage_width - VISIBLE_WIDTH)
		camera.position.x = cam_left + VISIBLE_WIDTH / 2.0
		camera.position.y = CAMERA_Y
		if stage and stage.has_method("set_camera_left"):
			stage.set_camera_left(cam_left)

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
		attacker.apply_hitstop(HITSTOP_ON_BLOCK)
		defender.apply_hitstop(HITSTOP_ON_BLOCK)
		SoundManager.play_block_sound()
	else:
		# Clean hit
		var knockdown: bool = atk_data.get("knockdown", false)
		defender.pushback_dir = push_dir
		defender.apply_hit(atk_data.damage, atk_data.hitstun, atk_data.pushback, knockdown)
		attacker.apply_hitstop(HITSTOP_ON_HIT)
		defender.apply_hitstop(HITSTOP_ON_HIT)
		SoundManager.play_hit_sound(attacker.current_attack)
		if defender.health <= 0:
			SoundManager.play_ko()

func _box_overlap(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.position.x + b.size.x and \
	       a.position.x + a.size.x > b.position.x and \
	       a.position.y < b.position.y + b.size.y and \
	       a.position.y + a.size.y > b.position.y

func _start_match() -> void:
	app_state = AppState.GAME
	menu_index = 0
	if game_view:
		game_view.visible = true
	if stage and stage.has_method("set_stage_theme"):
		stage.set_stage_theme("city")
	_set_game_hud_visible(true)
	# Placeholder roster shell: backend still uses current default real build, with SF kept as easter egg.
	if p1:
		p1.set_character("Teknium")
	if p2:
		p2.set_character("Teknium")
	if p1_name_label:
		p1_name_label.text = selected_fighter_name
	if p2_name_label:
		p2_name_label.text = "CPU"
	current_round = 1
	p1_round_wins = 0
	p2_round_wins = 0
	if ai:
		ai.set_difficulty(CPU_DIFFICULTIES[option_difficulty_index])
		ai.reset()
	_update_round_dots()
	_start_next_round(true)

func _enter_menu() -> void:
	app_state = AppState.MENU
	menu_index = 0
	fighter_select_index = 0
	intro_active = false
	intro_token += 1
	if game_view:
		game_view.visible = false
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

func _create_menu_ui() -> void:
	menu_overlay = ColorRect.new()
	menu_overlay.position = Vector2.ZERO
	menu_overlay.size = Vector2(SCREEN_WIDTH, 288)
	menu_overlay.color = Color(0.01, 0.02, 0.03, 1.0)
	add_child(menu_overlay)

	menu_panel_back = ColorRect.new()
	menu_panel_back.position = Vector2(56, 26)
	menu_panel_back.size = Vector2(400, 232)
	menu_panel_back.color = Color(0.0, 0.85, 0.72, 0.28)
	add_child(menu_panel_back)

	menu_panel = ColorRect.new()
	menu_panel.position = Vector2(58, 28)
	menu_panel.size = Vector2(396, 228)
	menu_panel.color = Color(0.03, 0.05, 0.08, 0.96)
	add_child(menu_panel)

	menu_title_label = Label.new()
	menu_title_label.position = Vector2(84, 40)
	menu_title_label.size = Vector2(344, 34)
	menu_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title_label.add_theme_font_size_override("font_size", 24)
	menu_title_label.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
	add_child(menu_title_label)

	menu_subtitle_label = Label.new()
	menu_subtitle_label.position = Vector2(84, 68)
	menu_subtitle_label.size = Vector2(344, 20)
	menu_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_subtitle_label.add_theme_font_size_override("font_size", 11)
	menu_subtitle_label.add_theme_color_override("font_color", Color(0.28, 0.95, 0.85))
	add_child(menu_subtitle_label)

	menu_body_label = Label.new()
	menu_body_label.position = Vector2(92, 102)
	menu_body_label.size = Vector2(328, 106)
	menu_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	menu_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	menu_body_label.add_theme_font_size_override("font_size", 15)
	menu_body_label.add_theme_color_override("font_color", Color(0.86, 0.94, 0.98))
	add_child(menu_body_label)

	for i in range(FIGHTER_PLACEHOLDERS.size()):
		var x := 82 + i * 116
		var back := ColorRect.new()
		back.position = Vector2(x, 102)
		back.size = Vector2(104, 86)
		back.color = Color(0.0, 0.85, 0.72, 0.22)
		add_child(back)
		fighter_card_backs.append(back)

		var fill := ColorRect.new()
		fill.position = Vector2(x + 2, 104)
		fill.size = Vector2(100, 82)
		fill.color = Color(0.06, 0.09, 0.13, 0.98)
		add_child(fill)
		fighter_card_fills.append(fill)

		var label := Label.new()
		label.position = Vector2(x + 8, 116)
		label.size = Vector2(88, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.90, 0.98, 1.0))
		label.text = FIGHTER_PLACEHOLDERS[i]
		add_child(label)
		fighter_card_labels.append(label)

		var tag := Label.new()
		tag.position = Vector2(x + 8, 145)
		tag.size = Vector2(88, 26)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 10)
		tag.add_theme_color_override("font_color", Color(0.45, 0.75, 0.82))
		tag.text = "PLACEHOLDER\nASSET SLOT"
		add_child(tag)
		fighter_card_tags.append(tag)

	fighter_select_desc_label = Label.new()
	fighter_select_desc_label.position = Vector2(90, 196)
	fighter_select_desc_label.size = Vector2(332, 30)
	fighter_select_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fighter_select_desc_label.add_theme_font_size_override("font_size", 10)
	fighter_select_desc_label.add_theme_color_override("font_color", Color(0.45, 0.75, 0.82))
	add_child(fighter_select_desc_label)

	menu_hint_label = Label.new()
	menu_hint_label.position = Vector2(82, 222)
	menu_hint_label.size = Vector2(348, 22)
	menu_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_hint_label.add_theme_font_size_override("font_size", 11)
	menu_hint_label.add_theme_color_override("font_color", Color(0.45, 0.75, 0.82))
	add_child(menu_hint_label)

	for i in range(18):
		var line := ColorRect.new()
		line.position = Vector2(70, 34 + i * 12)
		line.size = Vector2(372, 1)
		line.color = Color(0.45, 0.95, 0.95, 0.06)
		add_child(line)
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
	var nodes = [p1_health_bg, p2_health_bg, p1_health_border, p2_health_border, p1_health_bar, p2_health_bar, p1_health_label, p2_health_label, p1_name_label, p2_name_label, timer_label]
	for node in nodes:
		if node:
			node.visible = vis
	for dot in p1_round_dots:
		if dot: dot.visible = vis
	for dot in p2_round_dots:
		if dot: dot.visible = vis

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
	# We create HUD as children of the root Control (outside SubViewport)
	# so it's always visible at screen coordinates, not world coordinates.
	# This matches the JS approach where HUD draws on the canvas directly.

	# Health bar backgrounds
	p1_health_bg = ColorRect.new()
	p1_health_bg.position = Vector2(HUD_P1_BAR_X, HUD_BAR_Y)
	p1_health_bg.size = Vector2(HUD_BAR_WIDTH, HUD_BAR_HEIGHT)
	p1_health_bg.color = Color(0.25, 0.25, 0.25)
	add_child(p1_health_bg)
	p1_health_border = ColorRect.new()
	p1_health_border.position = Vector2(HUD_P1_BAR_X - 1, HUD_BAR_Y - 1)
	p1_health_border.size = Vector2(HUD_BAR_WIDTH + 2, HUD_BAR_HEIGHT + 2)
	p1_health_border.color = Color(0.7, 0.7, 0.7)
	p1_health_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p1_health_border)
	move_child(p1_health_border, p1_health_bg.get_index())

	p2_health_bg = ColorRect.new()
	p2_health_bg.position = Vector2(HUD_P2_BAR_X, HUD_BAR_Y)
	p2_health_bg.size = Vector2(HUD_BAR_WIDTH, HUD_BAR_HEIGHT)
	p2_health_bg.color = Color(0.25, 0.25, 0.25)
	add_child(p2_health_bg)
	p2_health_border = ColorRect.new()
	p2_health_border.position = Vector2(HUD_P2_BAR_X - 1, HUD_BAR_Y - 1)
	p2_health_border.size = Vector2(HUD_BAR_WIDTH + 2, HUD_BAR_HEIGHT + 2)
	p2_health_border.color = Color(0.7, 0.7, 0.7)
	p2_health_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p2_health_border)
	move_child(p2_health_border, p2_health_bg.get_index())

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
	p1_name_label = Label.new()
	p1_name_label.position = Vector2(HUD_P1_BAR_X, HUD_BAR_Y + HUD_BAR_HEIGHT + 2)
	p1_name_label.add_theme_font_size_override("font_size", 10)
	p1_name_label.add_theme_color_override("font_color", Color.WHITE)
	p1_name_label.text = "OLD_PROTOTYPE_FIGHTER"
	add_child(p1_name_label)

	p2_name_label = Label.new()
	p2_name_label.position = Vector2(HUD_P2_BAR_X + HUD_BAR_WIDTH - 22, HUD_BAR_Y + HUD_BAR_HEIGHT + 2)
	p2_name_label.add_theme_font_size_override("font_size", 10)
	p2_name_label.add_theme_color_override("font_color", Color.WHITE)
	p2_name_label.text = "OLD_PROTOTYPE_FIGHTER"
	add_child(p2_name_label)

	p1_health_label = Label.new()
	p1_health_label.position = Vector2(HUD_P1_BAR_X, HUD_BAR_Y + HUD_BAR_HEIGHT + 14)
	p1_health_label.add_theme_font_size_override("font_size", 10)
	p1_health_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(p1_health_label)

	p2_health_label = Label.new()
	p2_health_label.position = Vector2(HUD_P2_BAR_X, HUD_BAR_Y + HUD_BAR_HEIGHT + 14)
	p2_health_label.add_theme_font_size_override("font_size", 10)
	p2_health_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(p2_health_label)

	timer_label = Label.new()
	timer_label.position = Vector2(HUD_TIMER_X, HUD_TIMER_Y)
	timer_label.size = Vector2(28, 20)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 14)
	timer_label.add_theme_color_override("font_color", Color.YELLOW)
	add_child(timer_label)

	for i in range(ROUNDS_TO_WIN):
		var p1_dot := ColorRect.new()
		p1_dot.position = Vector2(HUD_P1_BAR_X + float(i) * HUD_DOT_SPACING, HUD_DOT_Y)
		p1_dot.size = Vector2(HUD_DOT_SIZE, HUD_DOT_SIZE)
		p1_dot.color = Color(0.3, 0.3, 0.3)
		add_child(p1_dot)
		p1_round_dots.append(p1_dot)

		var p2_dot := ColorRect.new()
		p2_dot.position = Vector2(HUD_P2_BAR_X + HUD_BAR_WIDTH - HUD_DOT_SIZE - float(i) * HUD_DOT_SPACING, HUD_DOT_Y)
		p2_dot.size = Vector2(HUD_DOT_SIZE, HUD_DOT_SIZE)
		p2_dot.color = Color(0.3, 0.3, 0.3)
		add_child(p2_dot)
		p2_round_dots.append(p2_dot)

	announcement_label = Label.new()
	announcement_label.position = Vector2(92, 92)
	announcement_label.size = Vector2(328, 96)
	announcement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcement_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	announcement_label.add_theme_font_size_override("font_size", 17)
	announcement_label.add_theme_color_override("font_color", Color(0.90, 0.98, 1.0))
	announcement_label.visible = false
	add_child(announcement_label)

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

	timer_label.text = "%02d" % int(ceil(round_time_left))
	if round_time_left <= 10.0 and not intro_active:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.34, 0.34))
	else:
		timer_label.add_theme_color_override("font_color", Color(0.28, 0.95, 0.85))
	if intro_active:
		timer_label.modulate.a = 0.7
	else:
		timer_label.modulate.a = 1.0

func _update_round_dots() -> void:
	for i in range(ROUNDS_TO_WIN):
		if i < p1_round_wins:
			p1_round_dots[i].color = Color.YELLOW
		else:
			p1_round_dots[i].color = Color(0.3, 0.3, 0.3)
		if i < p2_round_wins:
			p2_round_dots[i].color = Color.YELLOW
		else:
			p2_round_dots[i].color = Color(0.3, 0.3, 0.3)

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
		lines.append("Cam x=%.1f left=%.1f/%.1f" % [camera.position.x, stage.get_camera_left(), stage.get_max_scroll()])
	debug_label.visible = true
	debug_label.text = "\n".join(lines)
