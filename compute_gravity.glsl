#[compute]
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

struct ObjectData {
	vec2 pos;
	float mass;
	float _pad;
};

layout(set = 0, binding = 0, std430) restrict readonly buffer InputBuffer {
	ObjectData objects[];
}
input_buffer;

layout(set = 0, binding = 1, std430) restrict writeonly buffer OutputBuffer {
	vec2 force[];
}
output_buffer;

layout(push_constant, std430) uniform Params {
	int num_objects;
	float gravity_constant;
	float _pad0;
	float _pad1;
}
params;

void main() {
	uint idx = gl_GlobalInvocationID.x;
	if (idx >= uint(params.num_objects)) {
		return;
	}

	vec2 my_pos = input_buffer.objects[idx].pos;
	float my_mass = input_buffer.objects[idx].mass;
	vec2 total_force = vec2(0.0);

	for (uint j = 0; j < uint(params.num_objects); j++) {
		if (j == idx) {
			continue;
		}

		vec2 other_pos = input_buffer.objects[j].pos;
		float other_mass = input_buffer.objects[j].mass;

		vec2 diff = other_pos - my_pos;
		float dist_sq = dot(diff, diff);
		float inv_dist = inversesqrt(dist_sq);
		float inv_dist3 = inv_dist * inv_dist * inv_dist;

		total_force += params.gravity_constant * my_mass * other_mass * inv_dist3 * diff;
	}

	output_buffer.force[idx] = total_force;
}
