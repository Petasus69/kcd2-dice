shader_type spatial;
render_mode diffuse_burley;
uniform vec4 wood_color : source_color = vec4(0.27, 0.15, 0.075, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
        mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
    vec2 p = UV * vec2(16.0, 14.0);
    float board = floor(p.x / 1.18);
    float warp = noise(p * vec2(2.3, 0.35)) * 0.34;
    float grain = noise(vec2(p.x * 80.0 + warp * 45.0, p.y * 1.7));
    float rings = sin((p.x + warp) * 145.0 + sin(p.y * 0.7) * 2.0);
    float seam = smoothstep(0.0, 0.012, abs(fract(p.x / 1.18) - 0.5));
    float worn = noise(p * 2.3);
    float scratches = step(0.975, noise(p * vec2(110.0, 2.0)));
    float tone = (0.76 + grain * 0.14 + rings * 0.018 + worn * 0.15
        + hash(vec2(board, 8.0)) * 0.10) * mix(0.35, 1.0, seam);
    ALBEDO = wood_color.rgb * tone + vec3(0.022, 0.017, 0.010) * scratches;
    ROUGHNESS = 0.79 + grain * 0.15;
}
