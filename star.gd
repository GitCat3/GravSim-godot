extends RigidBody2D

var can_merge = true # Prevents both stars from trying to merge at the same time
@export var color_of_line = Color(1, 1, 1, 1)

func _ready():
	# Connect the built-in collision signal
	body_entered.connect(_on_body_entered)
	var line2d: Line2D = get_node("Line2D")
	line2d.default_color = color_of_line

func _on_body_entered(body):
	# Check if the thing we hit is another star and neither has merged yet
	if body is RigidBody2D and can_merge and body.can_merge:
		
		# Lock both so they don't try to merge with multiple bodies simultaneously
		can_merge = false
		body.can_merge = false
		
		# 1. Calculate conservation of momentum
		var total_mass = mass + body.mass
		var new_velocity = (linear_velocity * mass + body.linear_velocity * body.mass) / total_mass
		
		# 2. Absorb the smaller star into the larger one
		if mass >= body.mass:
			# This star is bigger, it absorbs the other
			mass = total_mass
			linear_velocity = new_velocity
			
			# Optional: Visually scale up the star to match the new mass
			scale += Vector2(0.2, 0.2) 
			
			body.queue_free() # Delete the smaller star
			can_merge = true
			
		else:
			# The other star is bigger, it absorbs this one
			body.mass = total_mass
			body.linear_velocity = new_velocity
			body.scale += Vector2(0.2, 0.2)
			
			queue_free() # Delete this star
