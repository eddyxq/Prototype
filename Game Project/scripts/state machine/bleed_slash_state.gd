class_name BleedSlashState
extends "res://scripts/state machine//state.gd"

var transition_timer

func _init(body, tt).(body):
	self.transition_timer = tt

func _state_logic(_delta):
	body.apply_gravity()
	
func _enter():
	var animation = "bleed_slash"
	var animation_duration = body.get_animation_node(animation).get_length()
	
	set_ready_to_transition_flag(false)
	body.skill3()
	transition_timer.start(animation_duration)
	
	body.set_label(animation)
	print("state:", animation)
	
func _exit():
	pass
