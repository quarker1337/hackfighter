# sprite_loader.gd — Build SpriteFrames from individual PNG files at runtime
# Avoids .tres UID issues and keeps animation config in auditable code
# Directory structure: res://assets/sprites/prototype/<anim_name>/<frame>.png

class_name SpriteLoader

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
