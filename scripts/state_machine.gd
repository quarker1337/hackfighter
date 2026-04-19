extends Node
class_name StateMachine

## State machine matching JS fighter.js states exactly
## JS states: IDLE, WALK_RIGHT, WALK_LEFT, CROUCH, JUMP, ATTACK

enum State {
	IDLE,
	WALK_RIGHT,
	WALK_LEFT,
	CROUCH,
	JUMP,
	ATTACK,
}

var current_state: State = State.IDLE
var previous_state: State = State.IDLE
var state_frame: int = 0

signal state_changed(from: State, to: State)

func transition_to(new_state: State) -> void:
	if new_state == current_state:
		return
	previous_state = current_state
	current_state = new_state
	state_frame = 0
	state_changed.emit(previous_state, current_state)

func tick() -> void:
	state_frame += 1

func state_name() -> String:
	return State.keys()[current_state]

func state_name_lower() -> String:
	## Returns JS-compatible lowercase state string for debug overlay
	match current_state:
		State.IDLE:       return "IDLE"
		State.WALK_RIGHT: return "WALK_RIGHT"
		State.WALK_LEFT:  return "WALK_LEFT"
		State.CROUCH:     return "CROUCH"
		State.JUMP:       return "JUMP"
		State.ATTACK:     return "ATTACK"
		_:                return "UNKNOWN"
