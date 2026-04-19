extends Node2D

## Stage scene — parallax background layers + floor collision
##
## Three background layers (clouds, mid-bg, floor) all rendered at screen
## origin with no parallax offset. The JS camera range is only 30px and
## the resulting parallax shift is ~16px max — negligible for initial setup.
##
## Parallax will be wired back in once camera tracking is active and we
## can verify it visually against the JS reference.

@onready var parallax_bg: ParallaxBackground = $ParallaxBackground
@onready var clouds_layer: ParallaxLayer = $ParallaxBackground/CloudsLayer
@onready var mid_bg_layer: ParallaxLayer = $ParallaxBackground/MidBgLayer
@onready var floor_layer: ParallaxLayer = $ParallaxBackground/FloorLayer
@onready var floor_body: StaticBody2D = $FloorBody

# Cloud drift (from JS: 0.001 px/frame at 60fps)
const CLOUD_DRIFT_SPEED: float = 0.001

func _process(_delta: float) -> void:
	if clouds_layer:
		clouds_layer.motion_offset.x += CLOUD_DRIFT_SPEED
