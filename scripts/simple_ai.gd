extends Node
class_name SimpleAI

var difficulty: String = "NORMAL"

## SimpleAI — 1:1 port of JS ai.js
## Distance-based CPU opponent: far=walk, mid=random attack, close=attack/block

var decision_timer: int = 0
var current_action: String = "idle"

func reset() -> void:
	decision_timer = 0
	current_action = "idle"

func set_difficulty(value: String) -> void:
	difficulty = value.to_upper()

## Get AI input as a dictionary of booleans (same shape as keyboard input)
## self_player = the AI-controlled Player, opponent = the other Player
func get_input(self_player: Player, opponent: Player) -> Dictionary:
	decision_timer -= 1
	if decision_timer > 0:
		return _action_to_input(current_action, self_player, opponent)
	
	# Make a new decision. Slower/faster depending on difficulty.
	match difficulty:
		"EASY":
			decision_timer = 40 + randi() % 30
		"HARD":
			decision_timer = 22 + randi() % 18
		_:
			decision_timer = 32 + randi() % 28
	
	var dist: float = absf(self_player.position.x - opponent.position.x)
	
	# If self is in hitstun, knockdown, or KO — can't act (matches JS)
	if self_player.is_in_hitstun or self_player.is_knocked_down or self_player.health <= 0:
		current_action = "idle"
		return _action_to_input(current_action, self_player, opponent)
	
	# If opponent is attacking, maybe block — difficulty-scaled.
	var block_chance := 0.18
	match difficulty:
		"EASY":
			block_chance = 0.10
		"HARD":
			block_chance = 0.28
	if opponent.current_attack != "" and randf() < block_chance:
		current_action = "block"
		return _action_to_input(current_action, self_player, opponent)
	
	if dist > 150.0:
		# Far away: walk forward mostly (matches JS: 70% walk, 15% jump, 15% idle)
		var r: float = randf()
		if r < 0.7:
			current_action = "walk_forward"
		elif r < 0.85:
			current_action = "jump"
		else:
			current_action = "idle"
	elif dist > 80.0:
		# Mid range: random attack or walk (matches JS distribution)
		var r: float = randf()
		if r < 0.25:
			current_action = "lightPunch"
		elif r < 0.4:
			current_action = "heavyKick"
		elif r < 0.55:
			current_action = "lightKick"
		elif r < 0.7:
			current_action = "walk_forward"
		else:
			current_action = "idle"
	else:
		# Close range: difficulty-scaled aggression.
		var r: float = randf()
		if difficulty == "EASY":
			if r < 0.07:
				current_action = "lightPunch"
			elif r < 0.12:
				current_action = "heavyPunch"
			elif r < 0.18:
				current_action = "lightKick"
			elif r < 0.23:
				current_action = "heavyKick"
			elif r < 0.30:
				current_action = "block"
			elif r < 0.44:
				current_action = "walk_backward"
			else:
				current_action = "idle"
		elif difficulty == "HARD":
			if r < 0.14:
				current_action = "lightPunch"
			elif r < 0.24:
				current_action = "heavyPunch"
			elif r < 0.34:
				current_action = "lightKick"
			elif r < 0.42:
				current_action = "heavyKick"
			elif r < 0.54:
				current_action = "block"
			elif r < 0.68:
				current_action = "walk_backward"
			else:
				current_action = "idle"
		else:
			if r < 0.10:
				current_action = "lightPunch"
			elif r < 0.16:
				current_action = "heavyPunch"
			elif r < 0.24:
				current_action = "lightKick"
			elif r < 0.30:
				current_action = "heavyKick"
			elif r < 0.38:
				current_action = "block"
			elif r < 0.52:
				current_action = "walk_backward"
			else:
				current_action = "idle"
	
	return _action_to_input(current_action, self_player, opponent)

## Convert AI action to the same input dictionary format as keyboard
func _action_to_input(action: String, self_player: Player, opponent: Player) -> Dictionary:
	var facing_right: bool = self_player.position.x < opponent.position.x
	var forward: String = "right" if facing_right else "left"
	var backward: String = "left" if facing_right else "right"
	
	var input: Dictionary = {
		"left": false,
		"right": false,
		"up": false,
		"down": false,
		"punch_light": false,
		"punch_heavy": false,
		"kick_light": false,
		"kick_heavy": false,
	}
	
	match action:
		"walk_forward":
			input[forward] = true
		"walk_backward":
			input[backward] = true
		"block":
			input[backward] = true
			if randf() < 0.4:
				input["down"] = true
		"jump":
			input["up"] = true
			if randf() < 0.5:
				input[forward] = true
		"lightPunch":
			input["punch_light"] = true
		"heavyPunch":
			input["punch_heavy"] = true
		"lightKick":
			input["kick_light"] = true
		"heavyKick":
			input["kick_heavy"] = true
		"idle", _:
			pass
	
	return input
