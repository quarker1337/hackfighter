shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.25, 1.15, 0.20, 1.0);
uniform vec4 shine_color : source_color = vec4(0.85, 1.35, 0.65, 1.0);
uniform float shine_pos : hint_range(0.0, 1.0) = 0.35;
uniform float shine_width : hint_range(0.01, 0.4) = 0.18;
uniform float scan_strength : hint_range(0.0, 0.2) = 0.055;
uniform float damage_flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    // The fill is a NinePatchRect using the same shaped track texture as the HUD bar.
    // Do not draw a procedural capsule here: damage should clip a fixed full-width
    // healthbar shape, not move/stretch an ellipse inside the bar.
    vec4 tex = texture(TEXTURE, UV);
    float mask = tex.a;
    float drift = 0.5 + 0.15 * sin(TIME * 0.8);
    float band = smoothstep(shine_width, 0.0, abs(UV.y - shine_pos * drift * 2.0));
    vec3 col = mix(base_color.rgb, shine_color.rgb, band);
    col *= 1.0 - scan_strength * (0.5 + 0.5 * sin(UV.y * 90.0));
    col *= 0.96 + 0.04 * sin(TIME * 6.0 + UV.x * 12.0);
    float edge = smoothstep(0.0, 0.08, UV.y) * smoothstep(1.0, 0.92, UV.y);
    col *= 0.54 + 0.46 * edge;
    col = mix(col, vec3(1.0, 1.0, 1.0), damage_flash * 0.85);
    COLOR = vec4(col, mask);
}
