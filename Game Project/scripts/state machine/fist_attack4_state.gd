class_name FistAttack4State
extends "res://scripts/state machine//state.gd"

var transition_timer

func _init(body, tt).(body):
	self.transition_timer = tt
	
func _state_logic(_delta):
	if body.velocity.x != 0 and body.is_on_floor():
		body.velocity.x = 0
	body.apply_gravity()

func _enter():
	var animation = "fist_attack4"
	var animation_duration = body.get_animation_node(animation).get_length()
	
	set_ready_to_transition_flag(false)
	body.play_animation(animation)
	transition_timer.start(animation_duration)
	
	body.set_label(animation)
	print("state:", animation)
	
func _exit():
	pass
	
