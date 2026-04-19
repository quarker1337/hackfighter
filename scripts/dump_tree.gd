extends Node2D

## Debug scene tree dumper — run once, print hierarchy, then quit

func _ready() -> void:
	_dump_tree(get_tree().root, 0)
	get_tree().quit()

func _dump_tree(node: Node, depth: int) -> void:
	var indent = "  ".repeat(depth)
	var info = indent + node.name + " [" + node.get_class() + "]"
	
	# CanvasLayer details
	if node is CanvasLayer:
		info += " layer=" + str(node.layer)
	
	# ParallaxLayer details
	if node is ParallaxLayer:
		info += " motion_scale=" + str(node.motion_scale)
		info += " motion_mirroring=" + str(node.motion_mirroring)
		info += " motion_offset=" + str(node.motion_offset)
	
	# Sprite2D details
	if node is Sprite2D:
		var s: Sprite2D = node as Sprite2D
		info += " visible=" + str(s.visible)
		info += " centered=" + str(s.centered)
		info += " position=" + str(s.position)
		info += " scale=" + str(s.scale)
		info += " offset=" + str(s.offset)
		if s.texture:
			info += " texture_size=" + str(s.texture.get_size())
		else:
			info += " texture=NULL"
	
	# ColorRect details
	if node is ColorRect:
		var cr: ColorRect = node as ColorRect
		info += " position=" + str(cr.position)
		info += " size=" + str(cr.size)
		info += " offset_right=" + str(cr.offset_right)
		info += " offset_bottom=" + str(cr.offset_bottom)
	
	# Camera2D
	if node is Camera2D:
		var c: Camera2D = node as Camera2D
		info += " position=" + str(c.position)
		info += " zoom=" + str(c.zoom)
	
	print(info)
	for child in node.get_children():
		_dump_tree(child, depth + 1)
