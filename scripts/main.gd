extends Control

## Main game controller — Stoat Fighter 2 Godot port
## Coordinates game loop, camera, fighters, HUD
##
## Scene structure:
##   Main (Control) — fills screen, handles stretch
##     SubViewportContainer — stretches viewport to fill
##       SubViewport (512x288) — game world
##         GameRoot
##           Stage — parallax backgrounds
##           Player1, Player2 — fighters
##           Camera2D — tracks midpoint between fighters
##           DebugLabel — shows diagnostic info (auto-hides)

@onready var p1: Player = %Player1
@onready var p2: Player = %Player2
@onready var camera: Camera2D = %Camera2D
@onready var debug_label: Label = %DebugLabel

## Camera config — tighter zoom, tracks fighter midpoint
const CAMERA_ZOOM := Vector2(1.0, 1.0)  # start at 1:1, add zoom later
const CAMERA_SMOOTHING := 8.0
const CAMERA_MIN_X := 220.0   # left limit (world coords)
const CAMERA_MAX_X := 600.0   # right limit (world coords)
const CAMERA_Y := 144.0       # fixed vertical position
const MARGIN_LEFT := 140.0    # stage margin (matches JS)
const MARGIN_RIGHT := 140.0

var debug_timer := 0.0

func _ready() -> void:
	print("Stoat Fighter 2 — Godot port initialized")
	# Set ground_y on players
	if p1:
		p1.ground_y = p1.position.y
		print("Main: p1.ground_y set to %.1f (p1.pos=%s)" % [p1.ground_y, str(p1.position)])
	if p2:
		p2.ground_y = p2.position.y
		print("Main: p2.ground_y set to %.1f (p2.pos=%s)" % [p2.ground_y, str(p2.position)])
	
	# Configure camera
	camera.zoom = CAMERA_ZOOM
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = CAMERA_SMOOTHING
	camera.make_current()
	
	# Show debug info for 3 seconds
	if debug_label:
		debug_timer = 3.0
		_update_debug_label()

func _process(delta: float) -> void:
	# Camera tracking temporarily disabled — using fixed position
	# TODO: re-enable with proper parallax when zoom is added
	
	# Keep root debug overlay updating every frame so it survives player/render issues
	_update_debug_label()
	
	# Debug label countdown
	if debug_timer > 0:
		debug_timer -= delta
		if debug_timer <= 0 and debug_label:
			debug_label.visible = false
	else:
		if debug_label:
			debug_label.visible = true

func _update_debug_label() -> void:
	if not debug_label:
		return
	var lines: Array[String] = []
	if p1:
		var sprite1 := p1.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		lines.append("P1 node=yes in_tree=%s pos=(%.1f, %.1f) visible=%s playing=%s anim=%s cam=(%.1f, %.1f)" % [str(p1.is_inside_tree()), p1.position.x, p1.position.y, str(sprite1.visible if sprite1 else false), str(sprite1.is_playing() if sprite1 else false), str(sprite1.animation if sprite1 else "<none>"), camera.position.x if camera else -1.0, camera.position.y if camera else -1.0])
	else:
		lines.append("P1 node=NULL")
	if p2:
		var sprite2 := p2.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		lines.append("P2 node=yes in_tree=%s pos=(%.1f, %.1f) visible=%s playing=%s anim=%s" % [str(p2.is_inside_tree()), p2.position.x, p2.position.y, str(sprite2.visible if sprite2 else false), str(sprite2.is_playing() if sprite2 else false), str(sprite2.animation if sprite2 else "<none>")])
	else:
		lines.append("P2 node=NULL")
	debug_label.visible = true
	debug_label.text = "\n".join(lines)
