extends Node2D

const GRAVITATIONAL_CONSTANT := 1.0
const WORKGROUP_SIZE := 64

var stars: Array[RigidBody2D]
var num_stars := 0

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var input_buffer: RID
var output_buffer: RID
var uniform_set: RID

# var starref = preload("res://Star.tscn")

func _ready() -> void:
	Engine.time_scale = 15.0
	
	'''
	for _i in range(1, 100):
		var star = starref.instantiate()
		add_child(star)
		
	for i: RigidBody2D in get_children():
		i.global_position = Vector2(randf_range(-500, 500), randf_range(-500, 500))
		i.mass = randi_range(1, 20)
		i.linear_velocity = Vector2(randf_range(0, 1), randf_range(0, 1))
	'''
	
	rd = RenderingServer.create_local_rendering_device()

	var shader_file := load("res://compute_gravity.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)

	stars.assign(get_children())
	_allocate_buffers(stars.size())

func _allocate_buffers(count: int) -> void:
	num_stars = count

	var input_bytes_size := num_stars * 4 * 4   # vec4 per star
	var output_bytes_size := num_stars * 2 * 4  # vec2 per star

	input_buffer = rd.storage_buffer_create(input_bytes_size)
	output_buffer = rd.storage_buffer_create(output_bytes_size)

	var input_uniform := RDUniform.new()
	input_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	input_uniform.binding = 0
	input_uniform.add_id(input_buffer)

	var output_uniform := RDUniform.new()
	output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	output_uniform.binding = 1
	output_uniform.add_id(output_buffer)

	uniform_set = rd.uniform_set_create([input_uniform, output_uniform], shader, 0)

func _physics_process(_delta: float) -> void:
	stars.assign(get_children())

	if stars.is_empty():
		return

	if stars.size() != num_stars:
		rd.free_rid(uniform_set)
		rd.free_rid(output_buffer)
		rd.free_rid(input_buffer)
		_allocate_buffers(stars.size())

	# --- Update input buffer with current positions/masses ---
	var data := PackedFloat32Array()
	data.resize(num_stars * 4)
	for i in num_stars:
		data[i * 4 + 0] = stars[i].global_position.x
		data[i * 4 + 1] = stars[i].global_position.y
		data[i * 4 + 2] = stars[i].mass
		data[i * 4 + 3] = 0.0

	var byte_data := data.to_byte_array()
	rd.buffer_update(input_buffer, 0, byte_data.size(), byte_data)

	# --- Push constants ---
	var push_constants := PackedByteArray()
	push_constants.resize(16)
	push_constants.encode_s32(0, num_stars)                 # int32 at offset 0
	push_constants.encode_float(4, GRAVITATIONAL_CONSTANT)   # float32 at offset 4
	push_constants.encode_float(8, 0.0)                      # padding
	push_constants.encode_float(12, 0.0)                     # padding

	# --- Dispatch ---
	var groups := ceili(num_stars / float(WORKGROUP_SIZE))

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
	rd.compute_list_dispatch(compute_list, groups, 1, 1)
	rd.compute_list_end()

	rd.submit()
	rd.sync()

	# --- Read back and apply ---
	var result_bytes := rd.buffer_get_data(output_buffer)
	var result_floats := result_bytes.to_float32_array()

	for i in num_stars:
		var force := Vector2(result_floats[i * 2], result_floats[i * 2 + 1])
		stars[i].apply_central_force(force * 100)

func _exit_tree() -> void:
	if uniform_set.is_valid():
		rd.free_rid(uniform_set)
	if output_buffer.is_valid():
		rd.free_rid(output_buffer)
	if input_buffer.is_valid():
		rd.free_rid(input_buffer)
	if pipeline.is_valid():
		rd.free_rid(pipeline)
	if shader.is_valid():
		rd.free_rid(shader)
	rd.free()
