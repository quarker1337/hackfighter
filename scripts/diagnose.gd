extends SceneTree

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	if not scene:
		print("ERROR: Failed to load Main.tscn")
		quit()
		return
	
	var root: Node = scene.instantiate()
	get_root().add_child(root)
	
	# Give a frame for _ready to run
	await create_timer(0.1).timeout
	
	# Find players
	var p1: Node = root.find_child("Player1", true, false)
	var p2: Node = root.find_child("Player2", true, false)
	
	print("--- PLAYER1 ---")
	if p1:
		print("  class: %s  pos: %s" % [p1.get_class(), str(p1.position)])
		var sprite1 = p1.find_child("AnimatedSprite2D", true, false)
		if sprite1:
			var as2d: AnimatedSprite2D = sprite1 as AnimatedSprite2D
			print("  sprite found: animation=%s frame=%d playing=%s" % [as2d.animation, as2d.frame, as2d.is_playing()])
			if as2d.sprite_frames:
				print("  sprite_frames: anims=%s" % str(as2d.sprite_frames.get_animation_names()))
			else:
				print("  sprite_frames: NULL")
		else:
			print("  NO AnimatedSprite2D child found")
		var sm1 = p1.find_child("StateMachine", true, false)
		if sm1:
			print("  state_machine: state=%d frame=%d" % [sm1.current_state, sm1.state_frame])
		else:
			print("  NO StateMachine child found")
	else:
		print("  NOT FOUND")
	
	print("--- PLAYER2 ---")
	if p2:
		print("  class: %s  pos: %s" % [p2.get_class(), str(p2.position)])
	else:
		print("  NOT FOUND")
	
	# Dump full tree
	print("--- SCENE TREE ---")
	_dump(root, 0)
	
	quit()

func _dump(node: Node, depth: int) -> void:
	var indent = "  ".repeat(depth)
	var extra = ""
	if node is AnimatedSprite2D:
		var a: AnimatedSprite2D = node
		extra = " anim=%s frame=%d playing=%s frames=%s" % [a.animation, a.frame, a.is_playing(), str(a.sprite_frames.get_animation_names()) if a.sprite_frames else "NULL"]
	if node is Camera2D:
		var c: Camera2D = node
		extra = " pos=%s limits=[%s,%s]" % [str(c.position), str(c.limit_left), str(c.limit_right)]
	print("%s%s [%s]%s" % [indent, node.name, node.get_class(), extra])
	for child in node.get_children():
		_dump(child, depth + 1)
