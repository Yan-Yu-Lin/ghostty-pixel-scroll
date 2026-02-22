// Built-in preset: curve-only CRT geometry pass for shader stacking.
// Use with another preset, for example: phosphor-green+crt-curve

vec2 crtWarp(vec2 uv, float amount) {
    vec2 p = uv * 2.0 - 1.0;
    float r2 = dot(p, p);
    p *= 1.0 + amount * r2;
    return p * 0.5 + 0.5;
}

float edgeMask(vec2 uv, float soft) {
    vec2 d = min(uv, 1.0 - uv);
    float e = min(d.x, d.y);
    return smoothstep(0.0, soft, e);
}

float curvedFalloff(vec2 warped_uv) {
    vec2 d = abs(warped_uv * 2.0 - 1.0);
    float m = max(d.x, d.y);
    return 1.0 - smoothstep(1.0, 1.2, m);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 warped = crtWarp(uv, 0.07);
    vec2 sample_uv = clamp(warped, vec2(0.001), vec2(0.999));

    vec3 color = texture(iChannel0, sample_uv).rgb;

    float vignette = 16.0 * sample_uv.x * sample_uv.y * (1.0 - sample_uv.x) * (1.0 - sample_uv.y);
    vignette = 0.95 + 0.05 * pow(clamp(vignette, 0.0, 1.0), 0.22);

    float curve = curvedFalloff(warped);
    float edge = edgeMask(sample_uv, 0.008);

    color *= vignette;
    color *= mix(0.9, 1.0, curve * edge);

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
