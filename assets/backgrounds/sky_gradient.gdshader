shader_type canvas_item;

// Sky gradient matching JS SKY_GRADIENTS[0]
// #0d1f3c -> #2a5a8c -> #6aa5d4 -> #d8ecf8
// Positions: 0.0, 0.4, 0.75, 1.0

void fragment() {
	vec4 color;
	float t = UV.y;
	if (t < 0.4) {
		float f = t / 0.4;
		color = mix(vec4(0.051, 0.122, 0.235, 1.0), vec4(0.165, 0.353, 0.549, 1.0), f);
	} else if (t < 0.75) {
		float f = (t - 0.4) / 0.35;
		color = mix(vec4(0.165, 0.353, 0.549, 1.0), vec4(0.416, 0.647, 0.831, 1.0), f);
	} else {
		float f = (t - 0.75) / 0.25;
		color = mix(vec4(0.416, 0.647, 0.831, 1.0), vec4(0.847, 0.925, 0.973, 1.0), f);
	}
	COLOR = color;
}
