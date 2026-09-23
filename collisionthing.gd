extends RigidBody2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is RigidBody2D:
		Engine.time_scale = 0
