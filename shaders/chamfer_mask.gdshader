shader_type canvas_item;

uniform float cut = 0.18;
uniform float edge_softness = 0.015;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    float x = UV.x;
    float y = UV.y;
    float c = cut;

    // Cyberpunk monitor silhouette: rectangle with all four corners cut off.
    // The diagonal corner tests keep the body rectangular, not circular.
    float top_left = x + y - c;
    float top_right = (1.0 - x) + y - c;
    float bottom_left = x + (1.0 - y) - c;
    float bottom_right = (1.0 - x) + (1.0 - y) - c;
    float d = min(min(top_left, top_right), min(bottom_left, bottom_right));
    float mask = smoothstep(0.0, edge_softness, d);

    COLOR = tex;
    COLOR.a *= mask;
}
