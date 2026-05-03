extends Node
class_name SimpleAI

var difficulty: String = "NORMAL"

## SimpleAI — 1:1 port of JS ai.js
## Distance-based CPU opponent: far=walk, mid=random attack, close=attack/block

var decision_timer: int = 0
var current_action: String = "idle"

const PROFILE_SETTINGS := {
	"EASY": { "min_decision": 28, "decision_jitter": 22, "block_chance": 0.12, "poke_chance": 0.24, "close_aggression": 0.34, "retreat_chance": 0.16 },
	"NORMAL": { "min_decision": 18, "decision_jitter": 18, "block_chance": 0.24, "poke_chance": 0.38, "close_aggression": 0.54, "retreat_chance": 0.12 },
	"HARD": { "min_decision": 10, "decision_jitter": 14, "block_chance": 0.42, "poke_chance": 0.54, "close_aggression": 0.72, "retreat_chance": 0.08 },
}

func reset() -> void:
	decision_timer = 0
	current_action = "idle"

func set_difficulty(value: String) -> void:
	difficulty = value.to_upper()
	if not PROFILE_SETTINGS.has(difficulty):
		difficulty = "NORMAL"

func _settings() -> Dictionary:
	return PROFILE_SETTINGS.get(difficulty, PROFILE_SETTINGS["NORMAL"])

## Get AI input as a dictionary of booleans (same shape as keyboard input)
## self_player = the AI-controlled Player, opponent = the other Player
func get_input(self_player: Player, opponent: Player) -> Dictionary:
	if self_player == null or opponent == null:
		current_action = "idle"
		return _action_to_input(current_action, self_player, opponent)

	# If self is stunned, busy, airborne, getting up, or KO — keep the input clean.
	if self_player.is_in_hitstun or self_player.is_in_blockstun or self_player.is_knocked_down or self_player.in_jump or self_player.current_attack != "" or self_player.health <= 0:
		current_action = "idle"
		decision_timer = 0
		return _action_to_input(current_action, self_player, opponent)

	# Reactive defense should interrupt a held walk/idle decision; otherwise the CPU
	# can look like it ignores block even on HARD.
	var settings := _settings()
	var dist: float = absf(self_player.position.x - opponent.position.x)

	# Trailer/demo spacing: split-projectile specials need visible runway.
	# Important: CPU projectile fighters should NOT back off before charging special.
	# They should fight normally, land 3 hits, then create distance and fire.
	var projectile_fighters := ["lobster", "teknium"]
	var self_key := self_player.character_name.to_lower()
	var opponent_key := opponent.character_name.to_lower()
	var self_has_projectile_special := projectile_fighters.has(self_key)
	var opponent_has_projectile_special := projectile_fighters.has(opponent_key)
	var opponent_projectile_special_threat := opponent_has_projectile_special and (opponent.special_ready or opponent.current_attack == "specialAttack")
	var self_projectile_special_threat := self_has_projectile_special and self_player.special_ready
	var needs_projectile_runway := opponent_projectile_special_threat or self_projectile_special_threat
	var backoff_distance := 112.0
	if needs_projectile_runway:
		backoff_distance = 315.0
	if needs_projectile_runway and dist < backoff_distance:
		if randf() < 1.0:
			# Use a separate action so Player can treat this as evasive movement,
			# not normal "hold back to block" while a projectile special is active.
			current_action = "demo_runway_retreat"
			decision_timer = 16 + (randi() % 12)
			return _action_to_input(current_action, self_player, opponent)
	elif self_projectile_special_threat and dist >= backoff_distance:
		# Once the CPU has charged special and made space, fire from range.
		current_action = "heavyKick"
		decision_timer = 6
		return _action_to_input(current_action, self_player, opponent)

	if opponent.current_attack != "" and dist < 135.0 and randf() < float(settings["block_chance"]):
		current_action = "block"
		decision_timer = min(decision_timer, 4)
		return _action_to_input(current_action, self_player, opponent)

	decision_timer -= 1
	if decision_timer > 0:
		return _action_to_input(current_action, self_player, opponent)

	decision_timer = int(settings["min_decision"]) + (randi() % int(settings["decision_jitter"]))
	var r: float = randf()

	if dist > 170.0:
		# Far: close distance. Hard commits harder; Easy occasionally hesitates.
		if r < (0.78 if difficulty == "EASY" else 0.90):
			current_action = "walk_forward"
		elif r < 0.95 and difficulty != "EASY":
			current_action = "jump"
		else:
			current_action = "idle"
	elif dist > 96.0:
		# Mid: mostly step in, with profile-scaled pokes for trailer-friendly pressure.
		var poke_chance: float = float(settings["poke_chance"])
		if r < poke_chance * 0.40:
			current_action = "lightKick"
		elif r < poke_chance * 0.72:
			current_action = "lightPunch"
		elif r < poke_chance:
			current_action = "heavyKick"
		elif r < 0.88:
			current_action = "walk_forward"
		else:
			current_action = "idle"
	else:
		# Close: pressure scales from sparring partner to actually dangerous.
		var attack_cutoff: float = float(settings["close_aggression"])
		if r < attack_cutoff * 0.30:
			current_action = "lightPunch"
		elif r < attack_cutoff * 0.52:
			current_action = "lightKick"
		elif r < attack_cutoff * 0.78:
			current_action = "heavyPunch"
		elif r < attack_cutoff:
			current_action = "heavyKick"
		elif r < attack_cutoff + float(settings["block_chance"]) * 0.35:
			current_action = "block"
		elif r < attack_cutoff + float(settings["block_chance"]) * 0.35 + float(settings["retreat_chance"]):
			current_action = "walk_backward"
		else:
			current_action = "idle"

	return _action_to_input(current_action, self_player, opponent)

## Convert AI action to the same input dictionary format as keyboard
func _action_to_input(action: String, self_player: Player, opponent: Player) -> Dictionary:
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
	if self_player == null or opponent == null:
		return input
	var facing_right: bool = self_player.position.x < opponent.position.x
	var forward: String = "right" if facing_right else "left"
	var backward: String = "left" if facing_right else "right"
	
	match action:
		"walk_forward":
			input[forward] = true
		"walk_backward", "demo_runway_retreat":
			input[backward] = true
			if action == "demo_runway_retreat":
				input["force_retreat"] = true
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
