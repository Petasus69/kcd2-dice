shader_type spatial;
render_mode diffuse_burley;
// Separate walnut tray with transverse grain and a restrained brass inlay.
uniform sampler2D grain_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D relief : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_map : filter_linear_mipmap, repeat_enable;
uniform vec4 wood_color : source_color = vec4(0.40, 0.26, 0.15, 1.0);
varying vec2 wood_uv;
void vertex() { wood_uv = VERTEX.xz; }
void fragment() {
    vec2 p = wood_uv;
    float plank = fract((p.y + 3.17) / 1.585);
    float seam = smoothstep(0.0, 0.006, min(plank, 1.0 - plank));
    float worn = 1.0 - smoothstep(0.0, 2.8, length(p * vec2(1.0, 0.65)));
    vec2 coordinates = vec2(p.y * 0.45 + 0.17, p.x * 0.16 + 0.39);
    vec3 color = wood_color.rgb * texture(grain_map, coordinates).rgb;
    color *= (0.94 + worn * 0.17) * mix(0.66, 1.0, seam);
    vec2 border = abs(p) - vec2(2.43, 2.93);
    float inlay = 1.0 - smoothstep(0.009, 0.022, abs(max(border.x, border.y)));
    vec2 corner = abs(p) - vec2(2.22, 2.72);
    float ornament = 1.0 - smoothstep(0.008, 0.018, abs(length(corner) - 0.105));
    inlay = max(inlay, ornament * 0.75);
    ALBEDO = mix(color, vec3(0.24, 0.15, 0.055), inlay * 0.65);
    NORMAL_MAP = texture(relief, coordinates).rgb;
    NORMAL_MAP_DEPTH = 0.32;
    ROUGHNESS = mix(clamp(texture(roughness_map, coordinates).g + 0.24, 0.66, 0.9), 0.52, inlay);
}
