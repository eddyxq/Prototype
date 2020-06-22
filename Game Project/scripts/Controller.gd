extends Node2D

###############################################################################
# detects and handles user inputs          
###############################################################################

# user keyboard input flags
var up     # w / up arrow
var down   # s / down arrrow
var left   # a / left arrow
var right  # d / right arrow
var attack # space bar

var skill1 # 1 number key
var skill2 # 2 number key
var skill3 # 3 number key
var skill4 # 4 number key
var skill5 # 5 number key

var item1  # q / x
var item2  # e / c

# references to the player and UI
onready var player = $Warrior
onready var ui = $HUD/UI

# called every delta
func _physics_process(_delta):
	
	# detect keyboard input
	up = Input.is_action_pressed("ui_up")
	down = Input.is_action_pressed("ui_down")
	left = Input.is_action_pressed("ui_left")
	right = Input.is_action_pressed("ui_right")
	attack = Input.is_action_pressed("ui_attack")

	skill1 = Input.is_action_pressed("ui_skill_slot1") && Global.mana >= 1
	skill2 = Input.is_action_pressed("ui_skill_slot2") && Global.mana >= 2
	skill3 = Input.is_action_pressed("ui_skill_slot3")
	skill4 = Input.is_action_pressed("ui_skill_slot4")
	skill5 = Input.is_action_pressed("ui_skill_slot5")
	item1 = Input.is_action_pressed("ui_item_slot1")
	item2 = Input.is_action_pressed("ui_item_slot2")

	# update player state
	player.animation_loop(attack, skill1, skill2, skill3, skill4, skill5, item1, item2)
	player.movement_loop(attack, up, left, right)
	
	# disable controlled when player dies
	if Global.health < 1:
		player.play_death_sfx()
		player.play_animation("dead")
		set_physics_process(false) 
	
	# apply auto mana regeneration
	ui.mana_bar.update()
	ui.health_bar.update()
	
	# apply cooldown upon skill activation
	if skill1:
		ui.start_skill1_cooldown()
	if skill2:
		ui.start_skill2_cooldown()
	if skill3:
		ui.start_skill3_cooldown()
	if item1:
		ui.start_item1_cooldown()
	if item2:
		ui.start_item2_cooldown()
		

	# turn on light if player is underground
	if(player.get_global_position().y > 445):
		player.set_light_enabled(true)
	else:
		player.set_light_enabled(false)

