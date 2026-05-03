# sprite_loader.gd — Build SpriteFrames from PNGs/sheets at runtime
# Avoids .tres UID issues and keeps animation config in auditable code
# Supports the legacy Prototype easter egg and real HACKFIGHTER characters.

class_name SpriteLoader

static func build_character_frames(character_name: String) -> SpriteFrames:
	match character_name.to_lower():
		"teknium":
			return build_teknium_frames()
		"lobster":
			return build_lobster_frames()
		_:
			return build_prototype_frames()

static func build_teknium_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	var idle_tex := load("res://assets/real/characters/teknium/Teknium_Idle_V2-Sheet.png") as Texture2D
	var walk_tex := load("res://assets/real/characters/teknium/Teknium_Walking_V2-Sheet.png") as Texture2D
	var crouch_tex := load("res://assets/real/characters/teknium/Teknium_Crouch_V1-Sheet.png") as Texture2D
	var jump_tex := load("res://assets/real/characters/teknium/Teknium_Jump_V2-Sheet.png") as Texture2D
	var lightkick_tex := load("res://assets/real/characters/teknium/Teknium_Lightkick_V2-Sheet.png") as Texture2D
	var heavypunch_tex := load("res://assets/real/characters/teknium/Teknium_Heavy_punch_V1-Sheet.png") as Texture2D
	var heavykick_tex := load("res://assets/real/characters/teknium/Teknium_High_Kick_V1-Sheet.png") as Texture2D
	var special_tex := load("res://assets/real/characters/teknium/Teknium_Special_V1-Sheet.png") as Texture2D
	var victory_tex := load("res://assets/real/characters/teknium/Teknium_Victory_V1-Sheet.png") as Texture2D
	var hurt_tex := load("res://assets/real/characters/teknium/Teknium_Hurt_V3-Sheet.png") as Texture2D
	var ko_tex := load("res://assets/real/characters/teknium/Teknium_KO_V1-Sheet.png") as Texture2D
	if not idle_tex or not walk_tex:
		push_warning("SpriteLoader: Teknium sheets missing, falling back to Prototype")
		return build_prototype_frames()

	_add_sheet_animation(frames, "idle", idle_tex, 8, 60.0 / 8.0, true)
	_add_sheet_animation(frames, "walking", walk_tex, 6, 60.0 / 6.0, true)

	if jump_tex:
		_add_sheet_animation(frames, "jump", jump_tex, 2, 60.0 / 5.0, false)
	else:
		_add_single_frame_anim_from_sheet(frames, "jump", idle_tex, 0, 8, 60.0 / 5.0)
	if crouch_tex:
		_add_sheet_animation(frames, "crouching", crouch_tex, 6, 60.0 / 4.0, false)
	else:
		_add_single_frame_anim_from_sheet(frames, "crouching", idle_tex, 1, 8, 60.0 / 4.0)
	_add_sheet_range_animation(frames, "lightpunch", idle_tex, 2, 2, 8, 60.0 / 4.0, false)
	if heavypunch_tex:
		_add_sheet_animation(frames, "heavypunch", heavypunch_tex, 6, 18.0, false)
	else:
		_add_sheet_range_animation(frames, "heavypunch", idle_tex, 2, 3, 8, 60.0 / 5.0, false)
	if lightkick_tex:
		_add_sheet_animation(frames, "lightkick", lightkick_tex, 8, 36.0, false)
	else:
		_add_single_frame_anim_from_sheet(frames, "lightkick", idle_tex, 4, 8, 60.0 / 4.0)
	if heavykick_tex:
		_add_sheet_animation(frames, "heavykick", heavykick_tex, 8, 19.2, false)
	else:
		_add_single_frame_anim_from_sheet(frames, "heavykick", idle_tex, 5, 8, 60.0 / 5.0)
	if special_tex:
		# 10-frame special sheet matching Lobster's split format:
		# frames 1-7 are Teknium's caster animation, frames 8-10 are the
		# standalone green projectile rendered as a separate moving sprite.
		_add_sheet_range_animation(frames, "specialattack", special_tex, 0, 7, 10, 60.0 / 4.0, false)
		_add_sheet_range_animation(frames, "specialprojectile", special_tex, 7, 3, 10, 24.0, true)
	if victory_tex:
		_add_sheet_range_animation(frames, "victory", victory_tex, 0, 4, 11, 60.0 / 8.0, false)
		_add_sheet_range_animation(frames, "victory_loop", victory_tex, 4, 7, 11, 60.0 / 8.0, true)
	else:
		_add_single_frame_anim_from_sheet(frames, "victory", idle_tex, 6, 8, 60.0 / 8.0)
	if hurt_tex:
		_add_sheet_animation(frames, "abdomen_hit", hurt_tex, 4, 60.0 / 4.0, false)
		_add_sheet_animation(frames, "head_hit", hurt_tex, 4, 60.0 / 4.0, false)
	else:
		_add_single_frame_anim_from_sheet(frames, "abdomen_hit", idle_tex, 7, 8, 60.0 / 6.0)
		_add_single_frame_anim_from_sheet(frames, "head_hit", idle_tex, 7, 8, 60.0 / 6.0)
	if ko_tex:
		_add_sheet_animation(frames, "ko", ko_tex, 8, 60.0 / 6.0, false)
	_add_single_frame_anim_from_sheet(frames, "blocking_stand", idle_tex, 0, 8, 60.0 / 6.0)
	if crouch_tex:
		_add_single_frame_anim_from_sheet(frames, "blocking_crouch", crouch_tex, 0, 6, 60.0 / 6.0)
	else:
		_add_single_frame_anim_from_sheet(frames, "blocking_crouch", idle_tex, 1, 8, 60.0 / 6.0)
	return frames

static func build_lobster_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	var idle_tex := load("res://assets/real/characters/lobster/Lobster_Idle_V1-Sheet.png") as Texture2D
	var walk_tex := load("res://assets/real/characters/lobster/Lobster_Walk_V1-Sheet.png") as Texture2D
	var crouch_tex := load("res://assets/real/characters/lobster/Lobster_Crouch_V3-Sheet.png") as Texture2D
	var jump_tex := load("res://assets/real/characters/lobster/Lobster_Jump_V1-Sheet.png") as Texture2D
	var lightpunch_tex := load("res://assets/real/characters/lobster/Lobster_Light_Punch_V1-Sheet.png") as Texture2D
	var heavypunch_tex := load("res://assets/real/characters/lobster/Lobster_Heavy_Punch_V1-Sheet.png") as Texture2D
	var doublepunch_tex := load("res://assets/real/characters/lobster/Lobster_Double_Punch_V2-Sheet.png") as Texture2D
	var special_tex := load("res://assets/real/characters/lobster/Lobster_Double_Punch_Special_V3-Sheet.png") as Texture2D
	var taunt_tex := load("res://assets/real/characters/lobster/Lobster_Taunt_V1-Sheet.png") as Texture2D
	var hurt_tex := load("res://assets/real/characters/lobster/Lobster_Hurt_V1-Sheet.png") as Texture2D
	var ko_tex := load("res://assets/real/characters/lobster/Lobster_KO_V1-Sheet.png") as Texture2D
	if not idle_tex or not walk_tex:
		push_warning("SpriteLoader: Lobster sheets missing, falling back to Teknium")
		return build_teknium_frames()

	_add_sheet_animation(frames, "idle", idle_tex, 5, 60.0 / 8.0, true)
	_add_sheet_animation(frames, "walking", walk_tex, 6, 60.0 / 6.0, true)

	if jump_tex:
		_add_sheet_animation(frames, "jump", jump_tex, 2, 60.0 / 5.0, false)
	else:
		_add_single_frame_anim_from_sheet(frames, "jump", idle_tex, 1, 5, 60.0 / 5.0)
	if crouch_tex:
		_add_sheet_animation(frames, "crouching", crouch_tex, 6, 60.0 / 4.0, false)
	else:
		_add_single_frame_anim_from_sheet(frames, "crouching", idle_tex, 2, 5, 60.0 / 4.0)
	if lightpunch_tex:
		_add_sheet_animation(frames, "lightpunch", lightpunch_tex, 5, 60.0 / 4.0, false)
	else:
		_add_sheet_range_animation(frames, "lightpunch", idle_tex, 2, 2, 5, 60.0 / 4.0, false)
	if heavypunch_tex:
		# Lobster's authored heavy punch has 6 frames; frames 5-6 are the real
		# extended claw. Duplicate the final frame once so the hit pose breathes
		# slightly before the attack returns to idle.
		_add_sheet_animation(frames, "heavypunch", heavypunch_tex, 6, 18.0, false)
		frames.add_frame("heavypunch", frames.get_frame_texture("heavypunch", 5))
	else:
		_add_sheet_range_animation(frames, "heavypunch", idle_tex, 1, 3, 5, 60.0 / 5.0, false)
	if doublepunch_tex:
		_add_sheet_animation(frames, "lightkick", doublepunch_tex, 8, 60.0 / 4.0, false)
		_add_sheet_animation(frames, "heavykick", doublepunch_tex, 8, 60.0 / 5.0, false)
	else:
		_add_single_frame_anim_from_sheet(frames, "lightkick", walk_tex, 2, 6, 60.0 / 4.0)
		_add_single_frame_anim_from_sheet(frames, "heavykick", walk_tex, 3, 6, 60.0 / 5.0)
	if special_tex:
		# V3 is authored facing right (unlike earlier Lobster sheets) and has 10
		# frames. Frames 1-7 are Lobster's cast animation; frames 8-10 are the
		# fiery claw projectile and are rendered as a separate moving sprite.
		_add_sheet_range_animation(frames, "specialattack", special_tex, 0, 7, 10, 60.0 / 4.0, false)
		_add_sheet_range_animation(frames, "specialprojectile", special_tex, 7, 3, 10, 24.0, true)
	else:
		_add_sheet_animation(frames, "specialattack", doublepunch_tex if doublepunch_tex else walk_tex, 8 if doublepunch_tex else 6, 60.0 / 5.0, false)
	if taunt_tex:
		_add_sheet_range_animation(frames, "victory", taunt_tex, 0, 3, 6, 60.0 / 8.0, false)
		_add_sheet_range_animation(frames, "victory_loop", taunt_tex, 3, 3, 6, 60.0 / 8.0, true)
	else:
		_add_single_frame_anim_from_sheet(frames, "victory", idle_tex, 4, 5, 60.0 / 8.0)
	if hurt_tex:
		_add_sheet_animation(frames, "abdomen_hit", hurt_tex, 3, 60.0 / 4.0, false)
		_add_sheet_animation(frames, "head_hit", hurt_tex, 3, 60.0 / 4.0, false)
	else:
		_add_single_frame_anim_from_sheet(frames, "abdomen_hit", idle_tex, 3, 5, 60.0 / 4.0)
		_add_single_frame_anim_from_sheet(frames, "head_hit", idle_tex, 3, 5, 60.0 / 4.0)
	if ko_tex:
		_add_sheet_animation(frames, "ko", ko_tex, 8, 60.0 / 6.0, false)
	else:
		_add_single_frame_anim_from_sheet(frames, "ko", idle_tex, 3, 5, 60.0 / 6.0)
	_add_single_frame_anim_from_sheet(frames, "blocking_stand", idle_tex, 0, 5, 60.0 / 6.0)
	if crouch_tex:
		_add_single_frame_anim_from_sheet(frames, "blocking_crouch", crouch_tex, 0, 6, 60.0 / 6.0)
	else:
		_add_single_frame_anim_from_sheet(frames, "blocking_crouch", idle_tex, 2, 5, 60.0 / 6.0)
	return frames

static func _add_sheet_animation(frames: SpriteFrames, anim_name: String, sheet: Texture2D, frame_count: int, speed: float, loop: bool) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, speed)
	frames.set_animation_loop(anim_name, loop)
	var frame_w := int(sheet.get_width() / frame_count)
	var frame_h := int(sheet.get_height())
	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		frames.add_frame(anim_name, atlas)

static func _add_single_frame_anim_from_sheet(frames: SpriteFrames, anim_name: String, sheet: Texture2D, frame_idx: int, frame_count: int, speed: float) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, speed)
	frames.set_animation_loop(anim_name, false)
	var frame_w := int(sheet.get_width() / frame_count)
	var frame_h := int(sheet.get_height())
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(frame_idx * frame_w, 0, frame_w, frame_h)
	frames.add_frame(anim_name, atlas)

static func _add_sheet_range_animation(frames: SpriteFrames, anim_name: String, sheet: Texture2D, start_idx: int, num_frames: int, frame_count: int, speed: float, loop: bool) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, speed)
	frames.set_animation_loop(anim_name, loop)
	var frame_w := int(sheet.get_width() / frame_count)
	var frame_h := int(sheet.get_height())
	for i in range(num_frames):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2((start_idx + i) * frame_w, 0, frame_w, frame_h)
		frames.add_frame(anim_name, atlas)

static func build_prototype_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	
	# Animation definitions from JS config
	# Format: [anim_name, sub_dir, frame_files, speed_fps, loop]
	# speed_fps = 60 / animSpeed (JS frames-per-sprite-frame)
	var anims: Array = [
		["idle",           "Idle",          ["Idle1.png","Idle2.png","Idle3.png","Idle4.png"],  60.0/8.0,  true],
		["walking",        "walking",       ["Walking1.png","Walking2.png","Walking3.png","Walking4.png","Walking5.png"], 60.0/6.0, true],
		["jump",           "jump",          ["Jump_Simple1.png","Jump_Simple2.png"], 60.0/5.0, false],
		["crouching",      "crouching",     ["Crouching1.png","Crouching2.png"], 60.0/4.0, false],
		["lightpunch",     "lightpunch",    ["lightpunch1.png","lightpunch2.png","lightpunch3.png"], 60.0/4.0, false],
		["heavypunch",     "heavypunch",    ["heavypunch1.png","heavypunch2.png","heavypunch3.png","heavypunch4.png","heavypunch5.png"], 60.0/5.0, false],
		["lightkick",      "lightkick",     ["Lightkick1.png","Lightkick2.png","Lightkick3.png","Lightkick4.png","Lightkick5.png"], 60.0/4.0, false],
		["heavykick",      "heavykick",     ["heavykick1.png","heavykick2.png","heavykick3.png","heavykick4.png","heavykick5.png"], 60.0/5.0, false],
		["victory",        "victory",       ["victory1.png","victory2.png","victory3.png","victory4.png"], 60.0/8.0, false],
		["abdomen_hit",    "Abdomen_Hit",   ["Abdomen_Hit1.png","Abdomen_Hit2.png","Abdomen_Hit3.png","Abdomen_Hit4.png"], 60.0/6.0, false],
		["head_hit",       "Headhit",       ["Headhit1.png","Headhit2.png","Headhit3.png"], 60.0/6.0, false],
		["blocking_stand", "blocking",      ["Blocking_stand.png"], 60.0/6.0, false],
		["blocking_crouch","blocking",      ["Blocking_crouch.png"], 60.0/6.0, false],
	]
	
	var total_loaded: int = 0
	var total_failed: int = 0
	
	for anim_def in anims:
		var anim_name: String = anim_def[0]
		var sub_dir: String = anim_def[1]
		var file_list: Array = anim_def[2]
		var speed: float = anim_def[3]
		var loop: bool = anim_def[4]
		
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, speed)
		frames.set_animation_loop(anim_name, loop)
		
		for file_name in file_list:
			var path: String = "res://assets/sprites/prototype/" + sub_dir + "/" + file_name
			var tex := load(path) as Texture2D
			if tex:
				frames.add_frame(anim_name, tex)
				total_loaded += 1
			else:
				push_warning("SpriteLoader: FAILED to load %s (load returned null)" % path)
				total_failed += 1
	
	print("SpriteLoader: build_prototype_frames done — %d loaded, %d failed, %d animations" % [total_loaded, total_failed, frames.get_animation_names().size()])
	print("SpriteLoader: animation names: %s" % str(frames.get_animation_names()))
	
	# Check frame counts per animation
	for anim_name in frames.get_animation_names():
		var count = frames.get_frame_count(anim_name)
		if count == 0:
			print("SpriteLoader: WARNING — animation '%s' has ZERO frames!" % anim_name)
	
	return frames
