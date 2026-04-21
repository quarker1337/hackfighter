extends Node2D

## Stage scene — supports current real HACKFIGHTER city stage by default,
## while preserving the legacy legacy fighter / Prototype scene as an easter egg.

@onready var sky_canvas: CanvasLayer = $SkyCanvasLayer
@onready var sky_gradient: ColorRect = $SkyCanvasLayer/SkyGradient
@onready var parallax_bg: ParallaxBackground = $ParallaxBackground
@onready var clouds_sprite: Sprite2D = $ParallaxBackground/CloudsLayer/CloudSprite
@onready var mid_bg_sprite: Sprite2D = $ParallaxBackground/MidBgLayer/MidBgSprite
@onready var floor_sprite: Sprite2D = $ParallaxBackground/FloorLayer/FloorSprite
@onready var floor_body: StaticBody2D = $FloorBody

# Cloud drift (from JS: 0.001 px/frame at 60fps)
const CLOUD_DRIFT_SPEED: float = 0.001
const SCREEN_WIDTH: float = 512.0
const LEGACY_FLOOR_WIDTH: float = 682.0
const BASE_OFFSET_X: float = 90.0
const VIEW_ZOOM: float = 1.03
const CITY_TEX_PATH := "res://assets/real/stages/city/City_Scene.png"
const CITY_SCALE: float = 682.0 / 1024.0
const CITY_DISPLAY_WIDTH: float = 1024.0 * CITY_SCALE
const CITY_DISPLAY_MAX_SCROLL: float = CITY_DISPLAY_WIDTH - SCREEN_WIDTH
const CITY_CROP_LEFT: float = 0.0
const CITY_PLAYER_LEFT: float = 165.0
const CITY_PLAYER_RIGHT: float = 910.0

var stage_theme: String = "city"
var floor_width: float = LEGACY_FLOOR_WIDTH
var camera_left_min: float = 0.0
var max_scroll: float = LEGACY_FLOOR_WIDTH * VIEW_ZOOM - SCREEN_WIDTH
var camera_left: float = 0.0
var cloud_drift_x: float = 0.0

func _ready() -> void:
	_apply_stage_theme(stage_theme)

func set_stage_theme(value: String) -> void:
	stage_theme = value
	_apply_stage_theme(stage_theme)

func get_stage_width() -> float:
	return floor_width

func get_camera_left_min() -> float:
	return camera_left_min

func get_player_left_bound() -> float:
	return 165.0 if stage_theme == "sf_easter_egg" else CITY_PLAYER_LEFT

func get_player_right_bound() -> float:
	return 657.0 if stage_theme == "sf_easter_egg" else CITY_PLAYER_RIGHT

func get_p1_spawn_x() -> float:
	return 270.0 if stage_theme == "sf_easter_egg" else 300.0

func get_p2_spawn_x() -> float:
	return 550.0 if stage_theme == "sf_easter_egg" else 760.0

func _apply_stage_theme(theme: String) -> void:
	if theme == "sf_easter_egg":
		floor_width = LEGACY_FLOOR_WIDTH
		camera_left_min = 160.0
		max_scroll = floor_width * VIEW_ZOOM - SCREEN_WIDTH
		if sky_canvas: sky_canvas.visible = true
		if sky_gradient: sky_gradient.visible = true
		if clouds_sprite: clouds_sprite.visible = true
		if mid_bg_sprite: mid_bg_sprite.visible = true
		if floor_sprite:
			floor_sprite.texture = load("res://assets/backgrounds/prototype-stage-full.png")
			floor_sprite.region_enabled = false
			floor_sprite.scale = Vector2(VIEW_ZOOM, VIEW_ZOOM)
			floor_sprite.position = Vector2.ZERO
		if mid_bg_sprite:
			mid_bg_sprite.texture = load("res://assets/backgrounds/stage_prototype_background_1.png")
			mid_bg_sprite.scale = Vector2(VIEW_ZOOM, VIEW_ZOOM)
			mid_bg_sprite.position = Vector2.ZERO
		if clouds_sprite:
			clouds_sprite.texture = load("res://assets/backgrounds/stage_prototype_background_2.png")
			clouds_sprite.scale = Vector2(VIEW_ZOOM, VIEW_ZOOM)
			clouds_sprite.position = Vector2.ZERO
		return

	# Default real HACKFIGHTER city stage
	floor_width = 1024.0
	camera_left_min = CITY_CROP_LEFT
	max_scroll = maxf(camera_left_min, floor_width - SCREEN_WIDTH)
	if sky_canvas: sky_canvas.visible = false
	if sky_gradient: sky_gradient.visible = false
	if clouds_sprite: clouds_sprite.visible = false
	if mid_bg_sprite: mid_bg_sprite.visible = false
	if floor_sprite:
		floor_sprite.texture = load(CITY_TEX_PATH)
		floor_sprite.region_enabled = false
		floor_sprite.scale = Vector2(CITY_SCALE, CITY_SCALE)
		floor_sprite.position = Vector2.ZERO

func set_camera_left(value: float) -> void:
	camera_left = clampf(value, camera_left_min, max_scroll)
	_update_layer_offsets()

func _process(_delta: float) -> void:
	if stage_theme == "sf_easter_egg":
		cloud_drift_x += CLOUD_DRIFT_SPEED
		if cloud_drift_x >= LEGACY_FLOOR_WIDTH:
			cloud_drift_x -= LEGACY_FLOOR_WIDTH
	_update_layer_offsets()

func _update_layer_offsets() -> void:
	if floor_sprite:
		if stage_theme == "sf_easter_egg":
			floor_sprite.position.x = BASE_OFFSET_X - camera_left
		else:
			var visual_scroll := 0.0
			if max_scroll > camera_left_min:
				visual_scroll = ((camera_left - camera_left_min) / (max_scroll - camera_left_min)) * CITY_DISPLAY_MAX_SCROLL
			floor_sprite.position.x = -visual_scroll
	if mid_bg_sprite and stage_theme == "sf_easter_egg":
		mid_bg_sprite.position.x = BASE_OFFSET_X - camera_left
	if clouds_sprite and stage_theme == "sf_easter_egg":
		clouds_sprite.position.x = BASE_OFFSET_X - cloud_drift_x

func get_camera_left() -> float:
	return camera_left

func get_max_scroll() -> float:
	return max_scroll
