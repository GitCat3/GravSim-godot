extends Node2D


var force = Vector2()
const GRAVITATIONAL_CONSTANT = 1.0
var stars: Array[RigidBody2D]

func _ready() -> void:
	Engine.time_scale = 15.0

func _physics_process(_delta: float) -> void:
	stars.assign(get_children())
	for star in stars:
		var m1: float  = star.mass
		for otherstar in stars:
			if otherstar != star:
				var m2: float = otherstar.mass
				var distancescalarcubed = pow(otherstar.global_position.distance_to(star.global_position), 3.0)
				var distancevector = (star.global_position - otherstar.global_position)
				force += (-GRAVITATIONAL_CONSTANT * ((m1 * m2)/distancescalarcubed))*distancevector
				
		star.apply_central_force(force * 100)
		force = Vector2(0, 0)
