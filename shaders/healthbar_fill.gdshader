shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.25, 1.15, 0.20, 1.0);
uniform vec4 shine_color : source_color = vec4(0.85, 1.35, 0.65, 1.0);
uniform float shine_pos : hint_range(0.0, 1.0) = 0.35;
uniform float shine_width : hint_range(0.01, 0.6) = 0.26;
uniform float scan_strength : hint_range(0.0, 0.2) = 0.028;
uniform float damage_flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    // The fill is a NinePatchRect using the same shaped track texture as the HUD bar.
    // Do not draw a procedural capsule here: damage should clip a fixed full-width
    // healthbar shape, not move/stretch an ellipse inside the bar.
    vec4 tex = texture(TEXTURE, UV);
    float mask = tex.a;

    float drift = 0.5 + 0.10 * sin(TIME * 0.55);
    float band_center = shine_pos + (drift - 0.5) * 0.16;
    float band = smoothstep(shine_width, 0.0, abs(UV.y - band_center));
    band = pow(band, 1.35);

    vec3 col = mix(base_color.rgb, shine_color.rgb, band * 0.72);
    col *= 1.0 - scan_strength * (0.5 + 0.5 * sin(UV.y * 48.0));
    col *= 0.98 + 0.02 * sin(TIME * 4.2 + UV.x * 8.0);

    float top_soft = smoothstep(0.0, 0.14, UV.y);
    float bottom_soft = smoothstep(1.0, 0.84, UV.y);
    float edge = top_soft * bottom_soft;
    col *= 0.72 + 0.28 * edge;
    col = mix(col, vec3(1.0, 1.0, 1.0), damage_flash * 0.75);
    COLOR = vec4(col, mask);
}
