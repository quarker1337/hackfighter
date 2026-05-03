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

var portrait_fx_clip: Control = null
var portrait_scanline_a: TextureRect = null
var portrait_scanline_b: TextureRect = null
var special_fire: ColorRect = null

const SIDE_P1_ACCENT := Color(0.24, 1.18, 1.06, 1.0) # #3FF6E0 with bloom headroom
const SIDE_P2_ACCENT := Color(1.28, 0.31, 0.66, 1.0) # #FF4FA8 with bloom headroom
const SIDE_P1_LABEL := Color("#7CF7B5")
const SIDE_P2_LABEL := Color("#FFC2E0")
const P2_FILL_BASE := Color(1.34, 0.12, 0.62, 1.0)
const P2_FILL_SHINE := Color(1.55, 0.58, 0.96, 1.0)
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
const PORTRAIT_SCANLINE_SCROLL_SPEED: float = 9.5
const PORTRAIT_SCANLINE_INSET: Vector2 = Vector2(4, 4)
const PORTRAIT_SCANLINE_CLIP_SIZE: Vector2 = Vector2(46, 46)
const PORTRAIT_SCANLINE_BASE_ALPHA: float = 0.26
const PORTRAIT_SCANLINE_GLITCH_ALPHA: float = 0.48
const PORTRAIT_GLITCH_MIN_DELAY: float = 1.8
const PORTRAIT_GLITCH_MAX_DELAY: float = 4.2
const PORTRAIT_GLITCH_DURATION_MIN: float = 0.055
const PORTRAIT_GLITCH_DURATION_MAX: float = 0.13
const PORTRAIT_ROUND_FADE_DURATION: float = 0.62
const PORTRAIT_ROUND_FADE_STAGGER: float = 0.10
const LABEL_HEIGHT: float = 12.0
const HUD_FONT := preload("res://fonts/DejaVuSansMono.ttf")

var _current_health: int
var _full_width: float = P1_FILL_WIDTH
var _fill_x: float = P1_FILL_X
var _accent: Color = SIDE_P1_ACCENT
var _profile_fx_time: float = 0.0
var _profile_scanline_offset: float = 0.0
var _profile_next_glitch_time: float = 0.0
var _profile_glitch_remaining: float = 0.0
var _profile_glitch_jitter: float = 0.0
var _profile_round_fade_tween: Tween = null
var _special_shine_tween: Tween = null
var _special_ready: bool = false
var _special_pulse_time: float = 0.0
var _profile_rng := RandomNumberGenerator.new()

func _ready() -> void:
	_current_health = max_health
	_profile_rng.randomize()
	# Offset each side so both portraits feel like separate tiny monitors.
	_profile_scanline_offset = PORTRAIT_HEIGHT * (0.33 if slot == "P1" else 0.71)
	_schedule_next_profile_glitch()
	_ensure_portrait_fx_nodes()
	_ensure_special_fire_node()
	_configure_layout()
	_apply_assets()
	_apply_side_theme()
	_apply_hero_theme()
	set_health(max_health, false)
	_set_profile_intro_alpha(1.0)

func _process(delta: float) -> void:
	_update_profile_fx(delta)
	_update_special_ready_pulse(delta)

func configure(new_hero_name: String, new_slot: String) -> void:
	hero_name = new_hero_name.to_upper()
	slot = new_slot
	if is_inside_tree():
		_ensure_portrait_fx_nodes()
		_ensure_special_fire_node()
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
	# Explicit draw order: track/fill/special fire are clipped under the authored
	# outline/topbar art. A child with a high z_index can otherwise visually bleed
	# over the sibling outline in Godot's CanvasItem sorting.
	track.z_index = 0
	fill_clip.z_index = 1
	outline.z_index = 20
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
	fill_clip.clip_contents = true
	fill_clip.size = Vector2(_full_width, FILL_HEIGHT)
	if special_fire:
		special_fire.position = Vector2.ZERO
		special_fire.size = Vector2(_full_width, FILL_HEIGHT)
		var mat := special_fire.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("direction", 1.0 if slot == "P1" else -1.0)
	portrait.size = Vector2(PORTRAIT_WIDTH, PORTRAIT_HEIGHT)
	portrait_ring.size = Vector2(PORTRAIT_WIDTH, PORTRAIT_HEIGHT)
	if portrait_fx_clip:
		portrait_fx_clip.size = PORTRAIT_SCANLINE_CLIP_SIZE
		portrait_fx_clip.clip_contents = true
	if portrait_scanline_a:
		portrait_scanline_a.size = Vector2(PORTRAIT_WIDTH, PORTRAIT_HEIGHT)
	if portrait_scanline_b:
		portrait_scanline_b.size = Vector2(PORTRAIT_WIDTH, PORTRAIT_HEIGHT)
	bar.scale.x = 1.0
	fill_clip.anchor_top = 0.0
	fill_clip.anchor_bottom = 0.0
	fill_clip.anchor_left = 0.0
	fill_clip.anchor_right = 0.0
	fill_clip.position = Vector2(_fill_x, FILL_INSET_Y)

	if slot == "P1":
		portrait.position = Vector2(-PORTRAIT_OUTWARD_OFFSET, 3)
		portrait_ring.position = portrait.position
		if portrait_fx_clip:
			portrait_fx_clip.position = portrait.position + PORTRAIT_SCANLINE_INSET
		bar.position = Vector2(PORTRAIT_WIDTH - PORTRAIT_OVERLAP, 16)
		name_label.position = Vector2(PORTRAIT_WIDTH + 2, 1)
		name_label.size = Vector2(BAR_WIDTH - 12, LABEL_HEIGHT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		bar.position = Vector2(0, 16)
		portrait.position = Vector2(BAR_WIDTH - PORTRAIT_OVERLAP + PORTRAIT_OUTWARD_OFFSET, 3)
		portrait_ring.position = portrait.position
		if portrait_fx_clip:
			portrait_fx_clip.position = portrait.position + PORTRAIT_SCANLINE_INSET
		name_label.position = Vector2(4, 1)
		name_label.size = Vector2(BAR_WIDTH - 12, LABEL_HEIGHT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _apply_assets() -> void:
	var suffix := "" if slot == "P1" else "_p2"
	track.texture = load("res://assets/ui/healthbar_track%s.png" % suffix)
	track.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fill.texture = track.texture
	fill.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	outline.texture = load("res://assets/ui/healthbar_outline%s.png" % suffix)
	outline.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait_ring.texture = load("res://assets/ui/hero_profile_top%s.png" % suffix)
	portrait_ring.visible = true
	portrait_ring.z_index = 3
	portrait.texture = load(_hero_profile_path(hero_name, suffix))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# UI profile art is authored higher than the logical slot so downscaling can
	# stay smooth on the high-res HUD canvas. Keep gameplay sprites nearest, not this.
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var scanline_texture := load("res://assets/ui/hero_profile_scanlines%s.png" % suffix)
	for scanline in [portrait_scanline_a, portrait_scanline_b]:
		if scanline:
			scanline.texture = scanline_texture
			scanline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			scanline.stretch_mode = TextureRect.STRETCH_SCALE
			scanline.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	var colors := [P2_FILL_BASE, P2_FILL_SHINE] if slot != "P1" else _hero_fill_colors(hero_name)
	var mat := fill.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("base_color", colors[0])
		mat.set_shader_parameter("shine_color", colors[1])
		mat.set_shader_parameter("shine_pos", 0.35)
		mat.set_shader_parameter("shine_width", 0.18)

func _ensure_portrait_fx_nodes() -> void:
	if portrait_fx_clip:
		return
	portrait_fx_clip = Control.new()
	portrait_fx_clip.name = "PortraitScanlineClip"
	portrait_fx_clip.clip_contents = true
	portrait_fx_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_fx_clip.z_index = 2
	add_child(portrait_fx_clip)
	move_child(portrait_fx_clip, portrait.get_index() + 1)
	portrait_scanline_a = _make_portrait_scanline("ScanlineA")
	portrait_scanline_b = _make_portrait_scanline("ScanlineB")
	portrait_fx_clip.add_child(portrait_scanline_a)
	portrait_fx_clip.add_child(portrait_scanline_b)

func _make_portrait_scanline(node_name: String) -> TextureRect:
	var scanline := TextureRect.new()
	scanline.name = node_name
	scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scanline.modulate = Color(1, 1, 1, PORTRAIT_SCANLINE_BASE_ALPHA)
	scanline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scanline.stretch_mode = TextureRect.STRETCH_SCALE
	scanline.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return scanline

func _ensure_special_fire_node() -> void:
	if special_fire:
		return
	special_fire = ColorRect.new()
	special_fire.name = "SpecialFireShine"
	special_fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	special_fire.visible = false
	special_fire.color = Color.WHITE
	special_fire.z_index = 1
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;
uniform vec4 fire_color : source_color = vec4(0.2, 1.0, 0.5, 1.0);
uniform float intensity = 0.0;
uniform float direction = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(41.7, 289.3))) * 45758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
void fragment() {
	vec2 uv = UV;
	float t = TIME * 3.3;
	float flow_x = (direction > 0.0) ? uv.x : 1.0 - uv.x;
	float wave = noise(vec2(flow_x * 9.0 - t * 1.8, uv.y * 5.0 + sin(t) * 0.5));
	float lick = smoothstep(0.24 + uv.y * 0.28, 0.95, wave + sin(flow_x * 18.0 - t * 4.0) * 0.16);
	float scan = smoothstep(0.0, 0.22, fract(flow_x * 2.2 - t * 0.75)) * (1.0 - smoothstep(0.22, 0.55, fract(flow_x * 2.2 - t * 0.75)));
	float top = 1.0 - smoothstep(0.15, 1.05, uv.y);
	float flame = (lick * 0.78 + scan * 0.44 + 0.18) * top * intensity;
	vec3 hot = mix(fire_color.rgb, vec3(1.0, 0.92, 0.34), clamp(lick + scan * 0.8, 0.0, 1.0));
	COLOR = vec4(hot, clamp(flame, 0.0, 0.86));
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("intensity", 0.0)
	special_fire.material = mat
	fill_clip.add_child(special_fire)
	fill_clip.move_child(special_fire, fill.get_index() + 1)
	# Belt-and-suspenders: keep the outline/topbar sibling last and highest.
	if outline and outline.get_parent() == bar:
		bar.move_child(outline, bar.get_child_count() - 1)

func _schedule_next_profile_glitch() -> void:
	_profile_next_glitch_time = _profile_rng.randf_range(PORTRAIT_GLITCH_MIN_DELAY, PORTRAIT_GLITCH_MAX_DELAY)

func play_round_intro_fade(delay: float = 0.0) -> void:
	if _profile_round_fade_tween and _profile_round_fade_tween.is_valid():
		_profile_round_fade_tween.kill()
	_set_profile_intro_alpha(0.0)
	_profile_round_fade_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if delay > 0.0:
		_profile_round_fade_tween.tween_interval(delay)
	_profile_round_fade_tween.tween_method(_set_profile_intro_alpha, 0.0, 1.0, PORTRAIT_ROUND_FADE_DURATION)

func _set_profile_intro_alpha(alpha: float) -> void:
	alpha = clampf(alpha, 0.0, 1.0)
	if portrait:
		portrait.modulate = Color(1, 1, 1, alpha)
	if portrait_ring:
		portrait_ring.modulate = Color(1, 1, 1, alpha)
	if portrait_fx_clip:
		portrait_fx_clip.modulate = Color(1, 1, 1, alpha)

func _update_profile_fx(delta: float) -> void:
	if not portrait_fx_clip or not portrait_scanline_a or not portrait_scanline_b:
		return
	_profile_fx_time += delta
	_profile_scanline_offset = fmod(_profile_scanline_offset + PORTRAIT_SCANLINE_SCROLL_SPEED * delta, PORTRAIT_HEIGHT)
	var alpha := PORTRAIT_SCANLINE_BASE_ALPHA
	var jitter_x := 0.0
	if _profile_glitch_remaining > 0.0:
		_profile_glitch_remaining = maxf(0.0, _profile_glitch_remaining - delta)
		alpha = PORTRAIT_SCANLINE_GLITCH_ALPHA
		# Tiny horizontal tears only on the scanline overlay, never on the solid frame.
		jitter_x = _profile_glitch_jitter if int(_profile_fx_time * 60.0) % 2 == 0 else -_profile_glitch_jitter
		if _profile_glitch_remaining <= 0.0:
			_schedule_next_profile_glitch()
	else:
		_profile_next_glitch_time -= delta
		if _profile_next_glitch_time <= 0.0:
			_profile_glitch_remaining = _profile_rng.randf_range(PORTRAIT_GLITCH_DURATION_MIN, PORTRAIT_GLITCH_DURATION_MAX)
			_profile_glitch_jitter = _profile_rng.randf_range(1.0, 2.8)
	portrait_fx_clip.position = portrait.position + PORTRAIT_SCANLINE_INSET + Vector2(jitter_x, 0)
	portrait_scanline_a.position = Vector2(-PORTRAIT_SCANLINE_INSET.x, _profile_scanline_offset - PORTRAIT_SCANLINE_INSET.y)
	portrait_scanline_b.position = Vector2(-PORTRAIT_SCANLINE_INSET.x, _profile_scanline_offset - PORTRAIT_HEIGHT - PORTRAIT_SCANLINE_INSET.y)
	var side_tint := Color(0.92, 1.0, 0.98, alpha) if slot == "P1" else Color(1.0, 0.92, 0.98, alpha)
	portrait_scanline_a.modulate = side_tint
	portrait_scanline_b.modulate = side_tint

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

func play_special_ready_shine() -> void:
	set_special_ready(true)
	var hero_color := _hero_special_color(hero_name)
	var hot_color := Color(
		minf(hero_color.r * 1.75 + 0.38, 2.4),
		minf(hero_color.g * 1.75 + 0.38, 2.4),
		minf(hero_color.b * 1.75 + 0.38, 2.4),
		1.0
	)
	if _special_shine_tween and _special_shine_tween.is_valid():
		_special_shine_tween.kill()
	_special_shine_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Keep the authored healthbar border clean; the fire/shine lives behind it in FillClip.
	if outline:
		outline.modulate = Color.WHITE
	_special_shine_tween.tween_property(fill, "modulate", hot_color, 0.08)
	_special_shine_tween.tween_property(portrait_ring, "modulate", hot_color, 0.08)
	_special_shine_tween.tween_property(name_label, "modulate", hot_color, 0.08)
	_special_shine_tween.chain().tween_interval(0.06)
	# Do not tween back to plain white here. The sustained special-ready pulse owns
	# these colors until the move consumes the charge or the round resets.
	_special_shine_tween.chain().tween_callback(func() -> void: _apply_special_ready_pulse(true))
	var mat := fill.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("damage_flash", 1.0)
		var flash := create_tween()
		flash.tween_method(func(v: float) -> void: mat.set_shader_parameter("damage_flash", v), 1.0, 0.0, 0.36)

func set_special_ready(ready: bool) -> void:
	if ready == _special_ready:
		return
	_special_ready = ready
	if _special_shine_tween and _special_shine_tween.is_valid():
		_special_shine_tween.kill()
		_special_shine_tween = null
	if not ready:
		_special_pulse_time = 0.0
		if special_fire:
			special_fire.visible = false
			var fire_mat := special_fire.material as ShaderMaterial
			if fire_mat:
				fire_mat.set_shader_parameter("intensity", 0.0)
		if fill:
			fill.modulate = Color.WHITE
		if name_label:
			name_label.modulate = Color.WHITE
		if outline:
			outline.modulate = Color.WHITE
		if portrait_ring:
			portrait_ring.modulate = Color.WHITE
	else:
		_apply_special_ready_pulse(true)

func _update_special_ready_pulse(delta: float) -> void:
	if not _special_ready:
		return
	_special_pulse_time += delta
	_apply_special_ready_pulse(false)

func _apply_special_ready_pulse(force: bool = false) -> void:
	if not _special_ready and not force:
		return
	var hero_color := _hero_special_color(hero_name)
	var pulse := 0.62 + 0.20 * sin(_special_pulse_time * 5.6)
	var bar_glow := Color(
		1.0 + hero_color.r * pulse * 0.58,
		1.0 + hero_color.g * pulse * 0.58,
		1.0 + hero_color.b * pulse * 0.58,
		1.0
	)
	var name_glow := Color(
		1.0 + hero_color.r * pulse * 0.32,
		1.0 + hero_color.g * pulse * 0.32,
		1.0 + hero_color.b * pulse * 0.32,
		1.0
	)
	if fill:
		fill.modulate = bar_glow
	if special_fire:
		special_fire.visible = true
		var fire_mat := special_fire.material as ShaderMaterial
		if fire_mat:
			fire_mat.set_shader_parameter("fire_color", hero_color)
			fire_mat.set_shader_parameter("intensity", clampf(0.62 + pulse * 0.46, 0.0, 1.0))
			fire_mat.set_shader_parameter("direction", 1.0 if slot == "P1" else -1.0)
	if outline:
		outline.modulate = Color.WHITE
	if portrait_ring:
		portrait_ring.modulate = Color.WHITE
	if name_label:
		name_label.modulate = name_glow

func _flash_and_shake() -> void:
	var original_pos := position
	var tw := create_tween()
	tw.tween_property(outline, "modulate", Color(1.6, 1.6, 1.6, 1.0), 0.04)
	# Damage flash must return to the untouched uploaded outline. Ending on _accent
	# left a permanent red/pink tint after P2 was hit once.
	tw.tween_property(outline, "modulate", Color.WHITE, 0.12)
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

func _hero_special_color(name: String) -> Color:
	match name.to_upper():
		"LOBSTER":
			return Color(1.0, 0.34, 0.12, 1.0)
		"NOUSGIRL":
			return Color(0.90, 0.36, 1.0, 1.0)
		_:
			return Color(0.22, 1.0, 0.52, 1.0)

func _hero_profile_path(name: String, suffix: String) -> String:
	match name.to_upper():
		"LOBSTER":
			return "res://assets/ui/hero_profile_lobster%s.png" % suffix
		_:
			return "res://assets/ui/hero_profile%s.png" % suffix

func _load_portrait_texture(name: String) -> Texture2D:
	match name.to_upper():
		"LOBSTER":
			return load("res://art/portraits/lobster_portrait.png")
		"NOUSGIRL":
			return load("res://art/portraits/nousgirl_portrait.png")
		_:
			return load("res://art/portraits/teknium_portrait.png")
