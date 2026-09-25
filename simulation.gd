extends Node2D


var force = Vector2()
const GRAVITATIONAL_CONSTANT = 1.0
var stars: Array[RigidBody2D]

var rd := RenderingServer.create_local_rendering_device()
var shader_file := load("res://compute_gravity.glsl")
var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
var shader := rd.shader_create_from_spirv(shader_spirv)


func _ready() -> void:
	Engine.time_scale = 15.0

func _physics_process(_delta: float) -> void:
	var starpositionsandmasses = [PackedFloat32Array(), PackedFloat32Array()]
	stars.assign(get_children())
	for i in range(0, len(stars)):
		starpositionsandmasses[i][0] = stars[i].global_position.x
		starpositionsandmasses[i][1] = stars[i].global_position.y
		starpositionsandmasses[i][2] = stars[i].mass


	var buffer := rd.storage_buffer_create(starpositionsandmasses.size(), starpositionsandmasses)
	
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = 0
	uniform.add_id(buffer)
	var uniform_set := rd.uniform_set_create([uniform], shader, 0)
	
	# Create a compute pipeline
	var pipeline := rd.compute_pipeline_create(shader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, 5, 1, 1)
	rd.compute_list_end()
	
	# Submit to GPU and wait for sync
	#rd.submit()
	#rd.sync()
	
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
