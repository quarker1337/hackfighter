extends Control

@export var max_health: int = 1000
@export var hero_name: String = "TEKNIUM"
@export var slot: String = "P1" # "P1", "P2", or "AI"
@export var portrait_texture: Texture2D

@onready var portrait: TextureRect = $Portrait
@onready var portrait_ring: TextureRect = $PortraitRing
@onready var name_label: Label = $NameLabel
@onready var bar: Control = $Bar
@onready var track: NinePatchRect = $Bar/Track
@onready var fill_clip: Control = $Bar/FillClip
@onready var fill: NinePatchRect = $Bar/FillClip/Fill
@onready var outline: NinePatchRect = $Bar/Outline

const SIDE_P1_ACCENT := Color(0.24, 1.18, 1.06, 1.0) # #3FF6E0 with bloom headroom
const SIDE_P2_ACCENT := Color(1.28, 0.31, 0.66, 1.0) # #FF4FA8 with bloom headroom
const SIDE_P1_LABEL := Color("#7CF7B5")
const SIDE_P2_LABEL := Color("#FFC2E0")
# 420px mockup bars do not fit Hackfighter's 512px game viewport twice plus timer,
# so this keeps the round-3 proportions at the actual viewport scale.
const BAR_WIDTH: float = 164.0
const BAR_HEIGHT: float = 27.0
const P1_FILL_X: float = 5.0
const P1_FILL_WIDTH: float = 157.0
const P2_FILL_X: float = 1.0
const P2_FILL_WIDTH: float = 157.0
const FILL_INSET_Y: float = 6.0
const FILL_HEIGHT: float = 14.0
const PORTRAIT_WIDTH: float = 54.0
const PORTRAIT_HEIGHT: float = 54.0
const PORTRAIT_OVERLAP: float = 6.0
const PORTRAIT_OUTWARD_OFFSET: float = 7.0
const LABEL_HEIGHT: float = 12.0
const HUD_FONT := preload("res://fonts/DejaVuSansMono.ttf")

var _current_health: int
var _full_width: float = P1_FILL_WIDTH
var _fill_x: float = P1_FILL_X
var _accent: Color = SIDE_P1_ACCENT

func _ready() -> void:
	_current_health = max_health
	_configure_layout()
	_apply_assets()
	_apply_side_theme()
	_apply_hero_theme()
	set_health(max_health, false)

func configure(new_hero_name: String, new_slot: String) -> void:
	hero_name = new_hero_name.to_upper()
	slot = new_slot
	if is_inside_tree():
		_configure_layout()
		_apply_assets()
		_apply_side_theme()
		_apply_hero_theme()
		set_health(_current_health, false)

func _configure_layout() -> void:
	name_label.text = "%s — %s" % [slot, hero_name]
	bar.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	# Slot-specific X tuning from visual review:
	# P1 extends the front left while pulling the back/end in after visual review.
	# P2 pulls the left/back edge in from overshoot while extending the right/front edge slightly.
	if slot == "P1":
		_fill_x = P1_FILL_X
		_full_width = P1_FILL_WIDTH
	else:
		_fill_x = P2_FILL_X
		_full_width = P2_FILL_WIDTH
	track.position = Vector2(_fill_x, FILL_INSET_Y)
	track.size = Vector2(_full_width, FILL_HEIGHT)
	track.patch_margin_left = 0
	track.patch_margin_top = 0
	track.patch_margin_right = 0
	track.patch_margin_bottom = 0
	outline.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	# The uploaded 457x78 outline is complete authored bar art, not a 9-slice skin.
	# Preserve it by scaling the whole image; old 8px ninepatch margins visually cut/compressed the caps.
	outline.patch_margin_left = 0
	outline.patch_margin_top = 0
	outline.patch_margin_right = 0
	outline.patch_margin_bottom = 0
	fill.size = Vector2(_full_width, FILL_HEIGHT)
	fill.position = Vector2.ZERO
	fill.patch_margin_left = 0
	fill.patch_margin_top = 0
	fill.patch_margin_right = 0
	fill.patch_margin_bottom = 0
	fill_clip.size = Vector2(_full_width, FILL_HEIGHT)
	portrait.size = Vector2(PORTRAIT_WIDTH, PORTRAIT_HEIGHT)
	portrait_ring.size = Vector2(PORTRAIT_WIDTH, PORTRAIT_HEIGHT)
	bar.scale.x = 1.0
	fill_clip.anchor_top = 0.0
	fill_clip.anchor_bottom = 0.0
	fill_clip.anchor_left = 0.0
	fill_clip.anchor_right = 0.0
	fill_clip.position = Vector2(_fill_x, FILL_INSET_Y)

	if slot == "P1":
		portrait.position = Vector2(-PORTRAIT_OUTWARD_OFFSET, 3)
		portrait_ring.position = portrait.position
		bar.position = Vector2(PORTRAIT_WIDTH - PORTRAIT_OVERLAP, 16)
		name_label.position = Vector2(PORTRAIT_WIDTH + 2, 1)
		name_label.size = Vector2(BAR_WIDTH - 12, LABEL_HEIGHT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		bar.position = Vector2(0, 16)
		portrait.position = Vector2(BAR_WIDTH - PORTRAIT_OVERLAP + PORTRAIT_OUTWARD_OFFSET, 3)
		portrait_ring.position = portrait.position
		name_label.position = Vector2(4, 1)
		name_label.size = Vector2(BAR_WIDTH - 12, LABEL_HEIGHT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _apply_assets() -> void:
	track.texture = load("res://assets/ui/healthbar_track.png")
	track.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fill.texture = track.texture
	fill.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	outline.texture = load("res://assets/ui/healthbar_outline.png")
	outline.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait_ring.texture = null
	portrait_ring.visible = false
	portrait.texture = load("res://assets/ui/hero_profile.png")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# UI profile art is authored higher than the logical slot so downscaling can
	# stay smooth on the high-res HUD canvas. Keep gameplay sprites nearest, not this.
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait_ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_ring.stretch_mode = TextureRect.STRETCH_SCALE
	portrait_ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.material = null
	var fill_shader := load("res://shaders/healthbar_fill.gdshader")
	if fill_shader:
		var fill_material := ShaderMaterial.new()
		fill_material.shader = fill_shader
		fill.material = fill_material

func _apply_side_theme() -> void:
	_accent = SIDE_P1_ACCENT if slot == "P1" else SIDE_P2_ACCENT
	outline.modulate = Color.WHITE
	portrait_ring.modulate = Color.WHITE
	name_label.add_theme_font_override("font", HUD_FONT)
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", SIDE_P1_LABEL if slot == "P1" else SIDE_P2_LABEL)

func _apply_hero_theme() -> void:
	var colors := _hero_fill_colors(hero_name)
	var mat := fill.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("base_color", colors[0])
		mat.set_shader_parameter("shine_color", colors[1])
		mat.set_shader_parameter("shine_pos", 0.35)
		mat.set_shader_parameter("shine_width", 0.18)

func set_health(value: int, animated: bool = true) -> void:
	value = clampi(value, 0, max_health)
	if animated and value == _current_health:
		return
	_current_health = value
	var ratio := float(value) / float(max_health)
	var target_w := _full_width * ratio
	var target_x := _fill_x
	if slot != "P1":
		target_x = _fill_x + (_full_width - target_w)
	if animated and is_inside_tree():
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(fill_clip, "size:x", target_w, 0.20)
		tw.tween_property(fill_clip, "position:x", target_x, 0.20)
		tw.tween_property(fill, "position:x", -(_full_width - target_w) if slot != "P1" else 0.0, 0.20)
	else:
		fill_clip.size.x = target_w
		fill_clip.position.x = target_x
		fill.position.x = -(_full_width - target_w) if slot != "P1" else 0.0

func take_damage(amount: int) -> void:
	set_health(_current_health - amount)
	_flash_and_shake()

func _flash_and_shake() -> void:
	var original_pos := position
	var tw := create_tween()
	tw.tween_property(outline, "modulate", Color(1.6, 1.6, 1.6, 1.0), 0.04)
	tw.tween_property(outline, "modulate", _accent, 0.12)
	var mat := fill.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("damage_flash", 1.0)
		var flash := create_tween()
		flash.tween_method(func(v: float) -> void: mat.set_shader_parameter("damage_flash", v), 1.0, 0.0, 0.18)
	var shake := create_tween()
	shake.tween_property(self, "position:x", original_pos.x + 3, 0.03)
	shake.tween_property(self, "position:x", original_pos.x - 3, 0.03)
	shake.tween_property(self, "position:x", original_pos.x, 0.03)

func _hero_fill_colors(name: String) -> Array[Color]:
	match name.to_upper():
		"LOBSTER":
			return [Color(1.35, 0.42, 0.16, 1.0), Color(1.55, 0.82, 0.46, 1.0)]
		"NOUSGIRL":
			return [Color(0.72, 0.26, 1.34, 1.0), Color(1.02, 0.72, 1.42, 1.0)]
		_:
			return [Color(0.25, 1.25, 0.20, 1.0), Color(0.82, 1.45, 0.62, 1.0)]

func _load_portrait_texture(name: String) -> Texture2D:
	match name.to_upper():
		"LOBSTER":
			return load("res://art/portraits/lobster_portrait.png")
		"NOUSGIRL":
			return load("res://art/portraits/nousgirl_portrait.png")
		_:
			return load("res://art/portraits/teknium_portrait.png")
