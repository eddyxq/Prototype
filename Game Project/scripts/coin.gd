extends RigidBody2D

# detects if coin touches the player
# TODO: add score
func _on_Area2D_body_entered(body):
	if "Player" in body.name:
		queue_free()
