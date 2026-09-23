extends Camera2D
class_name AutoZoomCamera2D

## Nodes to keep in frame.
@export var tracked_nodes: Array[Node2D] = []

## Extra margin (in world units) added around the bounding box.
@export var padding: Vector2 = Vector2(100, 100)

## Zoom limits. Note: higher zoom = closer in Godot 4.
@export var min_zoom: float = 0.1
@export var max_zoom: float = 5.0

## How quickly the camera catches up. Set to 0 for instant snap.
@export var smoothing: float = 5.0

## Keep aspect ratio correct (recommended - prevents stretching).
@export var keep_aspect: bool = true


func _process(delta: float) -> void:
	if tracked_nodes.is_empty():
		return

	var target := _compute_target()

	if smoothing <= 0.0:
		global_position = target.position
		zoom = target.zoom
	else:
		var t: float = clampf(smoothing * delta, 0.0, 1.0)
		global_position = global_position.lerp(target.position, t)
		zoom = zoom.lerp(target.zoom, t)


## Returns {"position": Vector2, "zoom": Vector2} for the desired camera state.
func _compute_target() -> Dictionary:
	var bounds: Rect2 = _get_bounds(tracked_nodes)

	# Nothing visible - keep current state.
	if bounds.size == Vector2.ZERO:
		return {"position": global_position, "zoom": zoom}

	var viewport_size: Vector2 = get_viewport_rect().size
	var padded_size: Vector2 = bounds.size + padding * 2.0

	# To fit padded_size into the viewport:
	#   zoom >= viewport_size / padded_size ... wait, zoom = 1 / scale,
	# so the required zoom is viewport_size / padded_size.
	var desired_zoom: Vector2 = viewport_size / padded_size

	if keep_aspect:
		# Use the smaller component so both axes fit.
		var uniform: float = minf(desired_zoom.x, desired_zoom.y)
		desired_zoom = Vector2(uniform, uniform)

	desired_zoom.x = clampf(desired_zoom.x, min_zoom, max_zoom)
	desired_zoom.y = clampf(desired_zoom.y, min_zoom, max_zoom)

	return {"position": bounds.get_center(), "zoom": desired_zoom}


## Merges the bounding rects of every tracked node.
func _get_bounds(nodes: Array[Node2D]) -> Rect2:
	var bounds := Rect2()
	var first := true

	for node in nodes:
		if not is_instance_valid(node):
			continue
		var r := _get_node_rect(node)
		if first:
			bounds = r
			first = false
		else:
			bounds = bounds.merge(r)

	return bounds


## Best-effort visual bounds of a single node, in global coordinates.
## Override or extend this for custom node types.
func _get_node_rect(node: Node2D) -> Rect2:
	# Sprite2D with a texture: use the texture size.
	if node is Sprite2D and node.texture:
		var scaled: Vector2 = node.texture.get_size() * node.global_scale.abs()
		var top_left: Vector2 = node.global_position - scaled * 0.5
		return Rect2(top_left, scaled)

	# CollisionObject2D: merge all child collision shape rects.
	if node is CollisionObject2D:
		var rect := Rect2()
		var has_shape := false
		for child in node.get_children():
			if child is CollisionShape2D and child.shape:
				var extents: Vector2 = _shape_extents(child.shape)
				var child_rect := Rect2(child.global_position - extents, extents * 2.0)
				rect = child_rect if not has_shape else rect.merge(child_rect)
				has_shape = true
		if has_shape:
			return rect

	# Fallback: just the node's origin.
	return Rect2(node.global_position, Vector2.ZERO)


## Approximate half-extents of a shape in world units.
func _shape_extents(shape: Shape2D) -> Vector2:
	if shape is RectangleShape2D:
		return shape.size * 0.5
	if shape is CircleShape2D:
		return Vector2(shape.radius, shape.radius)
	if shape is CapsuleShape2D:
		return Vector2(shape.radius, shape.height * 0.5)
	return Vector2.ZERO
