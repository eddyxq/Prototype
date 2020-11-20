extends KinematicBody2D

###############################################################################
# player class
###############################################################################

onready var UI = get_tree().get_root().get_node("/root/Controller/HUD/UI")
onready var skill_bar = get_tree().get_root().get_node("/root/Controller/HUD/UI/SkillBar")
onready var item_bar = get_tree().get_root().get_node("/root/Controller/HUD/UI/ItemBar")
onready var http : HTTPRequest = $HTTPRequest
onready var tree_state = $SwordAnimationTree.get("parameters/playback")

# player direction
enum DIRECTION {
	N, # north/up
	S, # south/down
	W, # west/left
	E, # east/right
}

# possible weapons and stances
enum STANCE {
	FIST, 
	SWORD, 
	BOW
}

# user profile sstructure
var profile = {
	"player_name": {},
	"player_lv": {},
	"player_health": {},
	"player_strength": {},
	"player_defense": {},
	"player_critical": {},
	"player_exp": {}
} 

# combat stats
const max_hp = 100
const min_hp = 0
const max_mp = 6
const min_mp = 0
var health = max_hp
var mana = max_mp
var strength = 10
var crit_rate = 30

# speed stats
const jump_speed = 330
const run_speed_modifier = 1.3
const boost_speed_modifier = 2.3
const atkmove_speed_modifier = 0
const dash_speed_modifier = 50
var base_speed = 50
var max_speed = 100
var min_speed = 0
var acceleration_rate = 14
var movement_speed # final actual speed after calculations

# player orientation
var dir = DIRECTION.E # default right facing 

# player stance
var stance = STANCE.FIST # default stance

# world constants
var DEFAULT_GRAVITY = 18
var gravity = 18

# flags for player states
var invincible = false # true when player has invincible frames

# flags that restrict usage of skills and items
var skill_slot_off_cooldown = [true, true, true, true, true, true, true]
var item_slot_off_cooldown = [true, true]
var weapon_change_off_cooldown = true

# mana cost of each skill
var skill_mana_cost = [1,1,1,1,1,1,1]

# velocity vector
var velocity = Vector2()

# animation tree
var state_machine

# flag use to signal that the player hit an enemy
var recentHit = false

# special movement states
var dashing = false
var sprinting = false

# variables used for ledge climbing
var isTouchingLedge = false
var movement_enabled = true

var current_animation_tree = null
var skillAnimationNode = null

var is_attacking = false
var is_using_skill = false
var is_switching_stance = false

var attack_animation_map = {}
#var jumpEnabled = true
# called when the node enters the scene tree for the first time
func _ready():
	# Firebase.get_document("users/%s" % Firebase.user_info.id, http)
	default_player_parameters()
	setup_state_machine()


# animation logic
func animation_loop(attack, skill, item, switch):
	move() # moving state
	jump() # jumping state
	fall() # falling state
	idle() # idle state
	attack() # attacking state
	detect_skill_activation() # pass input
#	detect_item_usage(item) # item activation
	grab_ledge()
#	stance_update(switch) # stance change

func _init_attack_animation_dict():
	attack_animation_map = {
		"fist_attack1": true,
		"fist_attack2": true,
		"fist_attack3": true,
		"fist_attack4": true,
		"sword_attack1": true,
		"sword_attack2": true,
		"sword_attack3": true,
	}
# movement logic
func movement_loop(attack, up, left, right):
	pass
	detect_ledge()
	if movement_enabled:
		apply_gravity() # pull player downwards
#		update_sprite_direction(right, left) # flips sprite to corresponding direction
#		vertical_movement() # vertical translation
#		update_speed_modifier(attack) # restricts movement during certain actions
#		apply_accel_decel(left, right) # acceleration effect
		apply_translation(left, right, attack)

#func update_sprite_direction(right, left):
#	if right:
#		dir = DIRECTION.E 
#		if flip:
#			scale.x = -1
#			flip = false
#
#	elif left:
#		dir = DIRECTION.W
#		if not flip:
#			scale.x = -1
#			flip = true

#var is_flip = false
#func flip_x_scale():
#	if dir == DIRECTION.E and is_flip:
#		scale.x = -1
#		is_flip = false
#
#	elif dir == DIRECTION.W and not is_flip:
#		if not flip:
#			scale.x = -1
#			flip = true


func move_left():
	# change direction when necessary
	if dir != DIRECTION.W:
		dir = DIRECTION.W
		base_speed = min_speed 
			
	# accelerate to the left
	base_speed += acceleration_rate
	if base_speed > max_speed:
		base_speed = max_speed
	
	velocity.x = base_speed * run_speed_modifier * -1
	
	
func move_right():
	# change direction when necessary
	if dir != DIRECTION.E:
		dir = DIRECTION.E 
		base_speed = min_speed
	
	# accelerate to the right
	base_speed += acceleration_rate
	if base_speed > max_speed:
		base_speed = max_speed
	
	velocity.x = base_speed * run_speed_modifier 
	
# TODO: let player fall through platforms
func move_down():
	pass

# applies a blinking damage effect to the player
func hurt(dmg):
	if !invincible:
		play_hurt_sfx()
		UI.health_bar.decrease(health, dmg)
		health -= dmg
		if health > 0:
			invincible = true
			blinking_damage_effect()

# ensures the hitbox is always in front
func update_hitbox_location():
	if $HitBox.position.x < 0 && dir == DIRECTION.E:
		$HitBox.position.x *= -1
	elif $HitBox.position.x > 0 && dir == DIRECTION.W:
		$HitBox.position.x *= -1

# update player's direction and sprite orientation
#var flip = false
#func update_sprite_direction(right, left):
#	if right:
#		dir = DIRECTION.E 
#		if flip:
#			scale.x = -1
#			flip = false
#
#	elif left:
#		dir = DIRECTION.W
#		if not flip:
#			scale.x = -1
#			flip = true

## update player's y velocity
#func vertical_movement():
#	if is_on_floor():
#		velocity.y = 0
#
#		if jumpEnabled: # jump
#			jumpEnabled = false
#
#			emit_foot_dust()
#			velocity.y = -jump_speed
#			play_footstep_sfx()

		

# travel to input state in animation tree
func play_animation(anim):
	# reset character parameters default
	default_player_hitbox_parameters()
	default_player_sprite_parameters()
	state_machine.travel(anim)

# enables normal attack hitbox
func toggle_hitbox_on():
	$HitBox/CollisionShape2D.disabled = false

# disables normal attack hitbox
func toggle_hitbox_off():
	$HitBox/CollisionShape2D.disabled = true

# activates sword skill 1 shooting a ranged projectile
func distance_blade():
	var projectile = preload("res://scenes/player/BladeProjectile.tscn").instance()
	get_parent().add_child(projectile)
	projectile.position = $PositionCenter.global_position
	projectile.set_projectile_direction(dir)
	
# activates sword skill 2 doing a spinning rapid attack
func whiirlwind_slash():
	var hitBox = preload("res://scenes/player/DashHitBox.tscn").instance()
	if dir == DIRECTION.W:
		hitBox.scale.x = -1
	hitBox.has_bleed_effect()
	get_parent().add_child(hitBox)
	hitBox.position = $PositionCenter.global_position
	
# activates sword skill 3 applying bleed to an enemy
func bleed_slash():
	dash()
	var hitBox = preload("res://scenes/player/DashHitBox.tscn").instance()
	if dir == DIRECTION.W:
		hitBox.scale.x = -1
	hitBox.has_bleed_effect()
	get_parent().add_child(hitBox)
	hitBox.position = $PositionCenter.global_position
	
# activates sword skill 4 damaging enemies in dash path
func dash_slash():
	dash()
	var hitBox2 = preload("res://scenes/player/DashHitBox.tscn").instance()
	if dir == DIRECTION.W:
		hitBox2.scale.x = -1
	hitBox2.has_stun_effect()
	get_parent().add_child(hitBox2)
	hitBox2.position = $PositionCenter.global_position

# activates bow skill 1 shooting a ranged projectile
func piercing_arrow():
	var projectile = preload("res://scenes/player/ArrowProjectile.tscn").instance()
	get_parent().add_child(projectile)
	projectile.position = $PositionCenter.global_position
	projectile.set_projectile_direction(dir)

# initializes the state machine for managing animation state transitions
func setup_state_machine():
	current_animation_tree = $FistAnimationTree
	state_machine = current_animation_tree.get("parameters/playback")
	skillAnimationNode = get_skill_animation_node()
	current_animation_tree.active = true
	
func get_skill_animation_node():
	var animation_root = current_animation_tree.get("tree_root")
	
	return animation_root.get_node("skill_placeholder")

# decreases player mp by integer amount passed in as amount
func consume_mp(amount):
	mana -= amount
	if mana < min_mp:
		mana = min_mp
	UI.mana_bar.update_bar(mana)

# increases player mp by integer amount passed in as amount
func restore_mp(amount):
	mana += amount
	if mana > max_mp:
		mana = max_mp

# ***temporarily disabled: might be adjusted or removed for game balance***
# to enable to go HealthRecovery node and check off Autostart
# auto health recovery over time
func _on_HealthRecovery_timeout():
	if health < max_hp && health > -1:
		UI.health_bar.increase(health, 1)
		health += 1

# ***temporarily disabled: might be adjusted or removed for game balance***
# to enable to go ManaRecovery node and check off Autostart
# auto mana recovery over time
func _on_ManaRecovery_timeout():
	if mana < max_mp && health > -1:
		mana += 1
		UI.mana_bar.update_bar(mana)

# loads player profile from database
func _on_HTTPRequest_request_completed(_result, response_code, _headers, body):
	var result_body := JSON.parse(body.get_string_from_ascii()).result as Dictionary
	match response_code:
		404:
			return
		200:
			Global.profile = result_body.fields

# player becomes invicible for a moment after getting hurt
func _on_IFrame_timeout():
	invincible = false

# applies damage when hitbox collide with enemies
# calls screen shaker whenever damage was critical
func _on_HitBox_body_entered(body):
	if "Enemy" in body.name:
		recentHit = true
		var is_crit
		# fists have lower damage and crit rate
		if stance == STANCE.FIST:
			is_crit = body.hurt(1, 0, 20, "default")
		elif stance == STANCE.SWORD:
			is_crit = body.hurt(5, 0, 30, "default")
		if is_crit:
			$Camera2D/ScreenShaker.start()

# timer used to countdown the animation of sprint buff
func _on_ghost_timer_timeout():
	var ghost_sprite = preload("res://scenes/player/PlayerGhost.tscn").instance()
	get_parent().add_child(ghost_sprite)
	ghost_sprite.position = position
	ghost_sprite.frame = $Sprite.frame
	ghost_sprite.flip_h = $Sprite.flip_h

# toggles a circular lighting effect around the player
func set_light_enabled(status):
	$Light2D.set_enabled(status)

# moves coins towards player when it is within auto pick up range
func _on_Area2D_body_entered(body):
	if body.get_filename() == "res://scenes/item/Coin.tscn":
		body.start_chase(self)

# resets the cooldown of slot utilized allowing reuse
func reset_skill_cooldown(skill_slot_num):
	# skill num 1 thruough 6 are skill slots
	# skill num 11 and 12 are item slots
	if skill_slot_num == 0:
		skill_slot_off_cooldown[skill_slot_num] = true
	elif skill_slot_num == 1:
		skill_slot_off_cooldown[skill_slot_num] = true
	elif skill_slot_num == 2:
		skill_slot_off_cooldown[skill_slot_num] = true
	elif skill_slot_num == 3:
		skill_slot_off_cooldown[skill_slot_num] = true
	elif skill_slot_num == 4:
		skill_slot_off_cooldown[skill_slot_num] = true
	elif skill_slot_num == 5:
		skill_slot_off_cooldown[skill_slot_num] = true
	elif skill_slot_num == 6:
		skill_slot_off_cooldown[skill_slot_num] = true
	elif skill_slot_num == 11:
		item_slot_off_cooldown[0] = true
	elif skill_slot_num == 12:
		item_slot_off_cooldown[1] = true

# toggles the player's stance between fist and sword
func toggle_stance():
	if weapon_change_off_cooldown and is_on_floor():
		$WeaponChangeCD.start()
		weapon_change_off_cooldown = false
		if stance == STANCE.FIST and movement_enabled and !isTouchingLedge:
			draw_sword()
		elif stance == STANCE.SWORD and movement_enabled and !isTouchingLedge:
			sheath_sword()

# draws sword weapon
func draw_sword():
	current_animation_tree.active = false
	current_animation_tree = $SwordAnimationTree
	state_machine = current_animation_tree.get("parameters/playback")
	skillAnimationNode = get_skill_animation_node()
	current_animation_tree.active = true
	stance = STANCE.SWORD

# put away sword
func sheath_sword():
	current_animation_tree.active = false
	current_animation_tree = $FistAnimationTree
	state_machine = current_animation_tree.get("parameters/playback")
	skillAnimationNode = get_skill_animation_node()
	current_animation_tree.active = true
	stance = STANCE.FIST

# left and right movement
func move():
	if velocity.x != 0 && is_on_floor():
		if sprinting:
			play_animation("sprint")
			emit_foot_dust()
		else:
			if stance == STANCE.FIST:
				play_animation("run")
			elif stance == STANCE.SWORD:
				play_animation("sword_run")

func play_run_animation():
	if stance == STANCE.FIST:
		play_animation("run")
	elif stance == STANCE.SWORD:
		play_animation("sword_run")
				


## player jumps in air 
#func jump():
#	if velocity.y < 0 && !is_on_floor():
#		play_animation("jump")
#

# player jumps in air 
func jump():
	if is_on_floor():
		velocity.y = -jump_speed
			

# player enters fall state while mid air
func fall():
	var isOnFloor = is_on_floor()
	if velocity.y > 0 && !isOnFloor:
		play_animation("fall")
#	elif isOnFloor and :
#		$JumpCooldown.start()
		

# player is in idle state when they are not moving
func idle():
	if velocity.length() == 0: 
		if stance == STANCE.FIST:
			play_animation("idle_fist")
		elif stance == STANCE.SWORD:
			play_animation("idle_sword")

func play_idle_animation():
	if stance == STANCE.FIST:
		play_animation("idle_fist")
	elif stance == STANCE.SWORD:
		play_animation("idle_sword")

func set_attack_flag(flag):
	is_attacking = flag

func set_skill_flag(flag):
	is_using_skill = flag

# regular attack
func attack():
	if stance == STANCE.FIST:
		play_animation("fist_attack4")
	elif stance == STANCE.SWORD:
		play_animation("sword_attack3")

func is_attacking():
	return is_attacking
	
func is_using_skill():
	return is_using_skill
	
# send skill inputs
func detect_skill_activation():	
	pass
#	if stance == STANCE.SWORD:
#		skill0(skill[0])
#		skill1(skill[1])
#		skill2(skill[2])
#		skill3(skill[3])
#		skill4(skill[4])
#		skill5(skill[5])
#		skill6(skill[6])

# distance blade
func skill1():
	if stance == STANCE.SWORD and skill_slot_off_cooldown[1]:
		if mana >= skill_mana_cost[1]:
			skill_bar.skill_slot1.start_cooldown()
			skill_slot_off_cooldown[1] = false
			skillAnimationNode.set_animation("distance_blade")
			play_animation("skill_placeholder")

func skill2():
	if stance == STANCE.SWORD and skill_slot_off_cooldown[2]:
		if mana >= skill_mana_cost[2]:
			skill_bar.skill_slot2.start_cooldown()
			skill_slot_off_cooldown[2] = false
			skillAnimationNode.set_animation("whirlwind_slash")
			play_animation("skill_placeholder")

func skill3():
	if stance == STANCE.SWORD and skill_slot_off_cooldown[3]:
		if mana >= skill_mana_cost[3]:
			skill_bar.skill_slot3.start_cooldown()
			skill_slot_off_cooldown[3] = false
			skillAnimationNode.set_animation("bleed_slash")
			play_animation("skill_placeholder")

func skill4():
	if stance == STANCE.SWORD and skill_slot_off_cooldown[4]:
		if mana >= skill_mana_cost[4]:
			skill_bar.skill_slot4.start_cooldown()
			skill_slot_off_cooldown[4] = false
			skillAnimationNode.set_animation("dash_slash")
			play_animation("skill_placeholder")

func skill5():
#	var _placeholder = skill5
	pass

func skill6():
#	var _placeholder = skill6
	pass

# ultimate move
func skill0():
#	var _placeholder = skill0
	pass

# restore player health when not in cooldown
func use_health_potion():
	
	if item_slot_off_cooldown[0]:
		item_bar.item_slot1.start_cooldown()
		item_slot_off_cooldown[0] = false
		play_potion_sfx()
		# potion fully heals the player's health
		UI.health_bar.increase(health, max_hp - health)
		health = max_hp
	
# restore player mana when not in cooldown	
func use_mana_potion():
	
	if item_slot_off_cooldown[1]:
		item_bar.item_slot2.start_cooldown()
		item_slot_off_cooldown[1] = false
		play_potion_sfx()
		# potion fully heals the player's mana
		mana = max_mp
		UI.mana_bar.update_bar(mana)


## changes the stance and weapon of the player
#func stance_update(switch):
#	if switch and weapon_change_off_cooldown and movement_enabled and !isTouchingLedge and is_on_floor():
#		if stance == STANCE.FIST:
#			play_animation("sword_draw")
#		elif stance == STANCE.SWORD:
#			play_animation("sword_sheath")

func switch_to_sword():
	if stance != STANCE.SWORD:
		if weapon_change_off_cooldown and movement_enabled and !isTouchingLedge and is_on_floor():
			play_animation("sword_draw")

func switch_to_fist():
	if stance != STANCE.FIST:
		if weapon_change_off_cooldown and movement_enabled and !isTouchingLedge and is_on_floor():
			play_animation("sword_sheath")

func switch_stance():
	if stance == STANCE.FIST:
		play_animation("sword_draw")
	else:
		play_animation("sword_sheath")

func is_switching_stance():
	return is_switching_stance
	
func set_switch_stance_flag(flag):
	is_switching_stance = flag
	print("switch stance flag:", is_switching_stance)
	
# translates the player downwards every frame at the rate of gravity
func apply_gravity():
	velocity.y += gravity

func is_sword_stance():
	return stance == STANCE.SWORD

func is_fist_stance():
	return stance == STANCE.FIST
		
		
func apply_horizontal_deceleration():
#	base_speed -= acceleration_rate *2
#	if base_speed < min_speed:
#	if base_speed < min_speed:
#		base_speed = min_speed
	if velocity.x > 0:
		velocity.x -= acceleration_rate * 2
		if velocity.x < 0:
			velocity.x = 0
	elif velocity.x < 0:
		velocity.x += acceleration_rate * 2
		if velocity.x > 0:
			velocity.x = 0

		
# applies a acceleration and deceeleration effect
func apply_accel_decel(left, right):
	if !left && !right:
		base_speed -= acceleration_rate *2
		if base_speed < min_speed:
			base_speed = min_speed
	else:
		base_speed += acceleration_rate
		if base_speed > max_speed:
			base_speed = max_speed
	
	
# restricts the movement ability of the player depending on actions
func update_speed_modifier(attack):
	if !sprinting:
		if attack and is_on_floor():
			movement_speed = base_speed * atkmove_speed_modifier
		else:
			 movement_speed = base_speed * run_speed_modifier

# update velocity and vectors
func apply_translation(left, right, attack):
	# translates player horizontally when left or right key is pressed
	velocity.x = (-int(left) + int(right)) * movement_speed
	# restrict movement during certain attack/skill
	if dashing:
		velocity.x = 500 if dir == DIRECTION.E else -500
	if attack:
		velocity.x = 0
		
	# apply translations to the player
	velocity = move_and_slide(velocity, Vector2(0,-1))

var is_flip = false
func update_horizontal_scale():
	if dir == DIRECTION.E and is_flip:
		is_flip = false
		scale.x = -1
	elif dir == DIRECTION.W and not is_flip:
		is_flip = true
		scale.x = -1

func apply_movement():
	# apply translations to the player
	velocity = move_and_slide(velocity, Vector2(0,-1))

# upon receiving damage player sprite blinks
func blinking_damage_effect():
	$IFrame.start()
	# blinks 4 times in 0.1 second intervals
	for i in 4:
		$Sprite.set_modulate(Color(1,1,1,0.5)) 
		yield(get_tree().create_timer(0.1), "timeout")
		$Sprite.set_modulate(Color(1,1,1,1)) 
		yield(get_tree().create_timer(0.1), "timeout")

###############################################################################
# sound effects
###############################################################################

# plays a sword swing sfx
func play_atk_sfx():
	SoundManager.play("res://audio/sfx/sword_swing.ogg")

# plays a swoosh sfx
func play_swoosh_sfx():
	SoundManager.play("res://audio/sfx/swoosh.ogg")

# plays a rock sfx
func play_rock_sfx():
	SoundManager.play("res://audio/sfx/rock.ogg")

# plays a footstep sfx
func play_footstep_sfx():
	SoundManager.play("res://audio/sfx/footstep.ogg")

# plays a hurt sfx
func play_hurt_sfx():
	SoundManager.play("res://audio/sfx/hurt.ogg")

# plays a invalid sfx
func play_death_sfx():
	SoundManager.play("res://audio/sfx/death.ogg")
	
# plays a potion sfx
func play_potion_sfx():
	SoundManager.play("res://audio/sfx/potion.ogg")
	
# plays a punch sfx
func play_punch_sfx():
	SoundManager.play("res://audio/sfx/punch.ogg")
	
# plays a buff sfx
func play_buff_sfx():
	SoundManager.play("res://audio/sfx/buff.ogg")
	
# plays a dash sfx
func play_dash_sfx():
	SoundManager.play("res://audio/sfx/dash.ogg")

# freezes the frame if the player hit something
# freezes frame for 100 milliseconds
func freeze_hit_frame():
	if recentHit:
		OS.delay_msec(50)
		recentHit = false

# creates dust particles after player movements
func emit_foot_dust():
	var dust_particles = preload("res://scenes/player/DustParticle.tscn").instance()
	dust_particles.set_as_toplevel(true)
	if dir == DIRECTION.E:
		dust_particles.scale.x = 1
	elif dir == DIRECTION.W:
		dust_particles.scale.x = -1
	dust_particles.global_position = $FeetPosition.global_position
	add_child(dust_particles)

func dash():
	if mana > 0 and movement_enabled:
		play_dash_sfx()
		consume_mp(1)
		gravity = 0
		velocity.y = 0
		movement_speed = base_speed * dash_speed_modifier
		dashing = true
		$DashTimer.start()

# new player dash
func do_dash():
	play_dash_sfx()
	gravity = 0
	velocity.y = 0
	velocity.x = 500
	if dir == DIRECTION.W:
		velocity.x *= -1
	dashing = true
	$DashTimer.start()

func is_dashing():
	return dashing
	
func _on_DashTimer_timeout():
	gravity = DEFAULT_GRAVITY
	dashing = false
	
func sprint():
	if !sprinting:
		sprinting = true
		$GhostInterval.start()
		movement_speed = max_speed * boost_speed_modifier
		play_animation("buff")
		$SprintTimer.start()
 
func _on_SprintTimer_timeout():
	sprinting = false
	$GhostInterval.stop()
	movement_speed = max_speed * run_speed_modifier
	
func activate_special_movement_skill(left, right):
	if stance == STANCE.FIST:
		sprint()
	elif stance == STANCE.SWORD and (left or right):
		dash()

func detect_ledge():
	if not isTouchingLedge and stance == STANCE.FIST:
		isTouchingLedge = is_ledge_detected()
		if isTouchingLedge:
			start_ledge_grab()
			movement_enabled = false
	
# TODO: needs a better way to identify blocks in the stage
# detects whether an player is close to an edge
# an edge is detected when lower raycast intersects with a block while upper ray cast does not
func is_ledge_detected():
	return $CollisionShape2D/LowerEdgeDetect.is_colliding() and not $CollisionShape2D/HigherEdgeDetect.is_colliding()

# TODO: needs a better way to identify blocks in the stage
# detects whether an player is close to an edge
# an edge is detected when lower raycast intersects with a block while upper ray cast does not
func is_touching_ledge():
	return $CollisionShape2D/LowerEdgeDetect.is_colliding() and not $CollisionShape2D/HigherEdgeDetect.is_colliding()

# ** PRECONDITION: this function should only be called if a ledge has been detected **
# teleports the player to the edge of a platform then initiates the ledge grab animation
func start_ledge_grab():
	var lowerRC = $CollisionShape2D/LowerEdgeDetect
	if lowerRC.get_collider().get_name() == "Blocks":
		var lowerCollisionPoint = lowerRC.get_collision_point()
		# y translation
		var new_y = 0
		var int_y = int(lowerCollisionPoint.y)
		if lowerCollisionPoint.y >= 0:
			new_y = int_y + 16 - (int_y % 16)
		else:
			var abs_y = abs(int_y)
			new_y = int_y + (abs_y % 16)
			
		# x translation
		var int_x = int(lowerCollisionPoint.x)
		# pushes player to the closest left block
		var new_x = int_x - (int_x % 16)
		
		if dir == DIRECTION.E:
			new_x -= 1
		else:
			new_x += 1
		
		lowerCollisionPoint.y = new_y - 3
		lowerCollisionPoint.x = new_x

		self.position = lowerCollisionPoint 
		velocity = Vector2.ZERO
	
# TODO: refactor since this function does too much 
func end_ledge_grab():
	var new_pos = self.position
	new_pos.y -= 31
	if dir == DIRECTION.E:
		new_pos.x += 7
	else:
		new_pos.x -= 7
	position = new_pos
	isTouchingLedge = false
	movement_enabled = true
	
func grab_ledge():
	if isTouchingLedge and stance == STANCE.FIST:
		play_animation("ledge_grab")

func default_player_parameters():
	dir = DIRECTION.E
	self.scale = Vector2(1, 1)
	default_player_sprite_parameters()
	default_player_hitbox_parameters()

func default_player_sprite_parameters():
	$Sprite.offset = Vector2.ZERO

func default_player_hitbox_parameters():
	$CollisionShape2D.position = Vector2(0, 6)
	$CollisionShape2D.scale = Vector2(1, 1)

# timer that countsdown until player can switch stances again, currently set at 2 seconds
func _on_WeaponChangeCD_timeout():
	weapon_change_off_cooldown = true
 
func set_label(label):
	$Label.set_text(label)

func get_animation_state_machine():
	return state_machine
	
func get_stance():
	return stance

#func _on_AnimationPlayer_animation_started(anim_name):
#	print("animatioon started: " + anim_name)
#	var is_attack_animation_playing = attack_animation_map[anim_name]
#	if is_attack_animation_playing:
#		print(anim_name + " is playing")
##	else:
##		set_attack_flag(false)
#
#func _on_AnimationPlayer_animation_finished(anim_name):
#	print(anim_name)
#	var is_attack_animation_playing = attack_animation_map[anim_name]
#	if is_attack_animation_playing:
#		print(anim_name + " is playing")
##	else:
##		set_attack_flag(false)


func _on_AnimationPlayer_animation_started(anim_name):
	print("animation started: " + anim_name)


func _on_AnimationPlayer_animation_finished(anim_name):
	print("animation finished: " + anim_name)


func _on_AnimationPlayer_animation_changed(old_name, new_name):
	print("old animation: " + old_name)
	print("new animation: " + new_name)

func get_animation_node(animation_node):
	return $AnimationPlayer.get_animation(animation_node)
