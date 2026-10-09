shader_type spatial;
render_mode diffuse_burley;
uniform vec4 wood_color : source_color = vec4(0.27, 0.15, 0.075, 1.0);
uniform sampler2D table_grain : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D table_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D table_roughness : filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
varying vec2 tabletop;

void vertex() { tabletop = VERTEX.xz; }

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
        mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
    vec2 p = tabletop + vec2(8.0, 7.0);
    float board = floor(p.x / 1.18);
    float warp = noise(p * vec2(2.3, 0.35)) * 0.34;
    float grain = noise(vec2(p.x * 80.0 + warp * 45.0, p.y * 1.7));
    float rings = sin((p.x + warp) * 145.0 + sin(p.y * 0.7) * 2.0);
    float plank_edge = fract(p.x / 1.18);
    float seam = smoothstep(0.0, 0.014, min(plank_edge, 1.0 - plank_edge));
    float worn = noise(p * 2.3);
    float scratches = step(0.975, noise(p * vec2(110.0, 2.0)));
    float tone = (0.76 + grain * 0.14 + rings * 0.018 + worn * 0.15
        + hash(vec2(board, 8.0)) * 0.10) * mix(0.35, 1.0, seam);
    ALBEDO = wood_color.rgb * tone + vec3(0.022, 0.017, 0.010) * scratches;
    if (use_texture) {
        vec2 coordinates = vec2(fract(p.x / 1.18) * 0.8 + hash(vec2(board, 3.0)) * 4.0,
            p.y * 0.15 + hash(vec2(board, 19.0)));
        ALBEDO *= texture(table_grain, coordinates).rgb;
        NORMAL_MAP = texture(table_normal, coordinates).rgb;
        NORMAL_MAP_DEPTH = 0.48;
    }
    ROUGHNESS = 0.79 + grain * 0.15;
    if (use_texture) {
        // glTF metallic/roughness image: roughness is the green channel.
        ROUGHNESS = clamp(texture(table_roughness, tabletop * 0.2).g + 0.30, 0.72, 0.96);
    }
}
