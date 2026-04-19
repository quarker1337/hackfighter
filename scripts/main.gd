extends Control

## Main game controller — Stoat Fighter 2 Godot port
## Coordinates game loop, camera, fighters, HUD
##
## Scene structure:
##   Main (Control) — fills screen, handles stretch
##     SubViewportContainer — hosts the game viewport
##       GameViewport (SubViewport 512x288) — clips all content to canvas bounds
##         GameRoot (Node2D) — world-space parent for stage/camera/fighters
##           Stage — parallax backgrounds + floor collision
##           Camera2D — follows fighters

# Stage & camera
@onready var stage: Node2D = $SubViewportContainer/GameViewport/GameRoot/Stage
@onready var camera: Camera2D = $SubViewportContainer/GameViewport/GameRoot/Camera2D

# Game state
var game_state: String = "title"  # "title" or "playing"
var frame: int = 0

# Stage dimensions (from JS config)
const STAGE_WIDTH: float = 822.0
const SCREEN_WIDTH: float = 512.0
const SCREEN_HEIGHT: float = 288.0

# Camera clamping (from JS stage.js)
# JS: cameraX (left edge) clamped to [marginLeft=140, maxCam=170]
# JS: maxCam = STAGE_WIDTH - SCREEN_WIDTH - marginRight = 822-512-140 = 170
# Godot limits constrain viewport edges, not camera center.
# limit_left=140  → viewport left edge >= 140  → camera center >= 396
# limit_right=682  → viewport right edge <= 682 → camera center <= 426
# (682 = floor sprite width, ensures we never see past the background art)

func _ready() -> void:
	print("Stoat Fighter 2 — Godot port initialized")
	# Center camera on stage midpoint (x=411, y=144)
	camera.position = Vector2(STAGE_WIDTH / 2.0, SCREEN_HEIGHT / 2.0)
	# Set limits so camera never shows past the background margins
	camera.limit_left = 140.0
	camera.limit_right = 682.0
	camera.limit_top = 0.0
	camera.limit_bottom = SCREEN_HEIGHT
	camera.make_current()

func _physics_process(_delta: float) -> void:
	frame += 1
	if game_state == "playing":
		_update_camera()

func _update_camera() -> void:
	pass
