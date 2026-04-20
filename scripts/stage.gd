extends Node2D

## Stage scene — screen-space background layers driven manually from camera_x.
## This matches the JS demo more closely than trying to zoom/scale fighters.

@onready var parallax_bg: ParallaxBackground = $ParallaxBackground
@onready var clouds_sprite: Sprite2D = $ParallaxBackground/CloudsLayer/CloudSprite
@onready var mid_bg_sprite: Sprite2D = $ParallaxBackground/MidBgLayer/MidBgSprite
@onready var floor_sprite: Sprite2D = $ParallaxBackground/FloorLayer/FloorSprite
@onready var floor_body: StaticBody2D = $FloorBody

# Cloud drift (from JS: 0.001 px/frame at 60fps)
const CLOUD_DRIFT_SPEED: float = 0.001
const SCREEN_WIDTH: float = 512.0
const FLOOR_WIDTH: float = 682.0
const BASE_OFFSET_X: float = 90.0
const VIEW_ZOOM: float = 1.03
const MAX_SCROLL: float = FLOOR_WIDTH * VIEW_ZOOM - SCREEN_WIDTH

var camera_left: float = 0.0
var cloud_drift_x: float = 0.0

func _ready() -> void:
	if floor_sprite:
		floor_sprite.scale *= VIEW_ZOOM
	if mid_bg_sprite:
		mid_bg_sprite.scale *= VIEW_ZOOM
	if clouds_sprite:
		clouds_sprite.scale *= VIEW_ZOOM

func set_camera_left(value: float) -> void:
	camera_left = clampf(value, 0.0, MAX_SCROLL)
	_update_layer_offsets()

func _process(_delta: float) -> void:
	cloud_drift_x += CLOUD_DRIFT_SPEED
	if cloud_drift_x >= FLOOR_WIDTH:
		cloud_drift_x -= FLOOR_WIDTH
	_update_layer_offsets()

func _update_layer_offsets() -> void:
	if floor_sprite:
		floor_sprite.position.x = BASE_OFFSET_X - camera_left
	if mid_bg_sprite:
		mid_bg_sprite.position.x = BASE_OFFSET_X - camera_left
	if clouds_sprite:
		clouds_sprite.position.x = BASE_OFFSET_X - cloud_drift_x
