extends Node2D

## Stage scene — current real HACKFIGHTER city stage only.

@onready var sky_canvas: CanvasLayer = $SkyCanvasLayer
@onready var sky_gradient: ColorRect = $SkyCanvasLayer/SkyGradient
@onready var parallax_bg: ParallaxBackground = $ParallaxBackground
@onready var clouds_sprite: Sprite2D = $ParallaxBackground/CloudsLayer/CloudSprite
@onready var mid_bg_sprite: Sprite2D = $ParallaxBackground/MidBgLayer/MidBgSprite
@onready var floor_sprite: Sprite2D = $ParallaxBackground/FloorLayer/FloorSprite
@onready var city_sprite: Sprite2D = $CitySprite
@onready var floor_body: StaticBody2D = $FloorBody

const SCREEN_WIDTH: float = 512.0
const VIEW_ZOOM: float = 1.03
const CITY_TEX_PATH := "res://assets/real/stages/city/City_Scene_V2.png"
const CITY_RED_LIGHTS_PATH := "res://assets/real/stages/city/Red_Lights.png"
const CITY_WINDOW_FRAME_PATHS := [
	"res://assets/real/stages/city/Windows_1.png",
	"res://assets/real/stages/city/Windows_2.png",
	"res://assets/real/stages/city/Windows_3.png",
]
const CITY_SIGN_FRAME_PATHS := [
	"res://assets/real/stages/city/Sign_Text_Frame_1.png",
	"res://assets/real/stages/city/Sign_Text_Frame_2.png",
	"res://assets/real/stages/city/Sign_Text_Frame_3.png",
	"res://assets/real/stages/city/Sign_Text_Frame_4.png",
	"res://assets/real/stages/city/Sign_Text_Frame_5.png",
	"res://assets/real/stages/city/Sign_Text_Frame_6.png",
]
const CITY_WINDOWS_FRAME_TIME: float = 4.0
const CITY_SIGN_FRAME_TIME: float = 0.22
const CITY_RED_LIGHT_BLINK_TIME: float = 1.35
const CITY_RED_LIGHT_DIM_ALPHA: float = 0.35
const CITY_RED_LIGHT_BRIGHT_ALPHA: float = 1.0
const CITY_SCALE: float = 682.0 / 1024.0
const CITY_DISPLAY_WIDTH: float = 1024.0 * CITY_SCALE
const CITY_VISIBLE_WIDTH: float = SCREEN_WIDTH / VIEW_ZOOM
const CITY_CROP_LEFT: float = 0.0
const CITY_PLAYER_LEFT: float = 115.0
const CITY_PLAYER_RIGHT: float = 565.0

var stage_theme: String = "city"
var floor_width: float = CITY_DISPLAY_WIDTH
var camera_left_min: float = CITY_CROP_LEFT
var max_scroll: float = maxf(CITY_CROP_LEFT, CITY_DISPLAY_WIDTH - CITY_VISIBLE_WIDTH)
var camera_left: float = 0.0
var city_overlay_root: Node2D = null
var city_red_lights_sprite: Sprite2D = null
var city_windows_sprite: Sprite2D = null
var city_sign_sprite: Sprite2D = null
var city_window_textures: Array[Texture2D] = []
var city_sign_textures: Array[Texture2D] = []
var city_window_frame: int = 0
var city_sign_frame: int = 0
var city_window_timer: float = 0.0
var city_sign_timer: float = 0.0
var city_red_light_timer: float = 0.0

func _ready() -> void:
	_apply_stage_theme(stage_theme)

func set_stage_theme(value: String) -> void:
	stage_theme = "city"
	_apply_stage_theme(stage_theme)

func get_stage_width() -> float:
	return floor_width

func get_camera_left_min() -> float:
	return camera_left_min

func get_player_left_bound() -> float:
	return CITY_PLAYER_LEFT

func get_player_right_bound() -> float:
	return CITY_PLAYER_RIGHT

func get_p1_spawn_x() -> float:
	return 205.0

func get_p2_spawn_x() -> float:
	return 505.0

func _apply_stage_theme(_theme: String) -> void:
	# Real HACKFIGHTER city stage as a world-space backdrop.
	floor_width = CITY_DISPLAY_WIDTH
	camera_left_min = CITY_CROP_LEFT
	max_scroll = maxf(camera_left_min, floor_width - CITY_VISIBLE_WIDTH)
	if sky_canvas: sky_canvas.visible = false
	if sky_gradient: sky_gradient.visible = false
	if parallax_bg: parallax_bg.visible = false
	if city_sprite:
		city_sprite.visible = true
		city_sprite.texture = load(CITY_TEX_PATH)
		city_sprite.scale = Vector2(CITY_SCALE, CITY_SCALE)
		city_sprite.position = Vector2.ZERO
	_ensure_city_overlay_nodes()
	_set_city_overlays_visible(true)

func set_camera_left(value: float) -> void:
	camera_left = clampf(value, camera_left_min, max_scroll)

func _process(_delta: float) -> void:
	_update_city_overlay_animation(_delta)

func _ensure_city_overlay_nodes() -> void:
	if city_overlay_root:
		return
	city_overlay_root = Node2D.new()
	city_overlay_root.name = "CityOverlayRoot"
	city_overlay_root.z_index = 1
	city_sprite.add_child(city_overlay_root)

	city_red_lights_sprite = _make_city_overlay_sprite("RedLights", load(CITY_RED_LIGHTS_PATH))
	city_overlay_root.add_child(city_red_lights_sprite)

	city_window_textures.clear()
	for path in CITY_WINDOW_FRAME_PATHS:
		city_window_textures.append(load(path))
	city_windows_sprite = _make_city_overlay_sprite("Windows", city_window_textures[0] if not city_window_textures.is_empty() else null)
	city_overlay_root.add_child(city_windows_sprite)

	city_sign_textures.clear()
	for path in CITY_SIGN_FRAME_PATHS:
		city_sign_textures.append(load(path))
	city_sign_sprite = _make_city_overlay_sprite("SignText", city_sign_textures[0] if not city_sign_textures.is_empty() else null)
	city_overlay_root.add_child(city_sign_sprite)

func _make_city_overlay_sprite(node_name: String, texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite

func _set_city_overlays_visible(vis: bool) -> void:
	if city_overlay_root:
		city_overlay_root.visible = vis
	if city_red_lights_sprite and not vis:
		city_red_lights_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _update_city_overlay_animation(delta: float) -> void:
	if not city_overlay_root or not city_overlay_root.visible:
		return
	if city_red_lights_sprite:
		city_red_light_timer = fmod(city_red_light_timer + delta, CITY_RED_LIGHT_BLINK_TIME)
		var red_phase := city_red_light_timer / CITY_RED_LIGHT_BLINK_TIME
		var red_alpha := CITY_RED_LIGHT_BRIGHT_ALPHA if red_phase < 0.42 else CITY_RED_LIGHT_DIM_ALPHA
		city_red_lights_sprite.modulate = Color(1.0, 1.0, 1.0, red_alpha)
	if city_windows_sprite and city_window_textures.size() > 1:
		city_window_timer += delta
		if city_window_timer >= CITY_WINDOWS_FRAME_TIME:
			city_window_timer = fmod(city_window_timer, CITY_WINDOWS_FRAME_TIME)
			city_window_frame = (city_window_frame + 1) % city_window_textures.size()
			city_windows_sprite.texture = city_window_textures[city_window_frame]
	if city_sign_sprite and city_sign_textures.size() > 1:
		city_sign_timer += delta
		if city_sign_timer >= CITY_SIGN_FRAME_TIME:
			city_sign_timer = fmod(city_sign_timer, CITY_SIGN_FRAME_TIME)
			city_sign_frame = (city_sign_frame + 1) % city_sign_textures.size()
			city_sign_sprite.texture = city_sign_textures[city_sign_frame]

func get_camera_left() -> float:
	return camera_left

func get_max_scroll() -> float:
	return max_scroll
