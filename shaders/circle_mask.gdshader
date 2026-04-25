shader_type canvas_item;

void fragment() {
    float d = distance(UV, vec2(0.5));
    float a = smoothstep(0.50, 0.48, d);
    COLOR = texture(TEXTURE, UV);
    COLOR.a *= a;
}
