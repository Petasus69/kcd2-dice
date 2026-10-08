shader_type spatial;
render_mode diffuse_burley;
// Separate dark walnut insert, not the photographic oak of the outer table.
varying vec2 wood_uv;
void vertex() { wood_uv = VERTEX.xz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
        mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
    vec2 p = wood_uv;
    float warp = noise(p * vec2(0.6, 1.3)) * 0.24;
    float grain = noise(vec2(p.y * 52.0 + warp * 65.0, p.x * 2.4));
    float figure = noise(p * vec2(0.4, 2.5));
    float lines = sin((p.y + warp) * 48.0) * 0.011;
    float seam = smoothstep(0.0, 0.01, abs(fract((p.y + 3.17) / 1.05) - 0.5));
    float worn = 1.0 - smoothstep(0.0, 2.8, length(p * vec2(1.0, 0.65)));
    vec3 walnut = mix(vec3(0.052, 0.027, 0.014), vec3(0.14, 0.086, 0.043), grain * 0.5 + figure * 0.5);
    vec2 knot = (p - vec2(0.9, -0.3)) * vec2(0.5, 1.6);
    float knot_radius = length(knot);
    float knot_mask = 1.0 - smoothstep(0.08, 0.65, knot_radius);
    walnut *= 1.0 - knot_mask * (0.24 + sin(knot_radius * 42.0) * 0.06);
    ALBEDO = (walnut + lines + worn * vec3(0.018, 0.014, 0.009)) * mix(0.55, 1.0, seam);
    ROUGHNESS = 0.67 + grain * 0.19;
    NORMAL_MAP = vec3(0.5, 0.5 + (grain - 0.5) * 0.14, 1.0);
    NORMAL_MAP_DEPTH = 0.22;
}
