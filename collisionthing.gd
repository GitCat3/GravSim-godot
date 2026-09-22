extends RigidBody2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is RigidBody2D:
		if body.mass < mass:
			mass += body.mass
			body.free()
			
		elif body.mass == mass:
			var velocity = linear_velocity + body.linear_velocity
