// Built-in preset: flat full-screen green phosphor monitor.

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 px = vec2(1.0) / iResolution.xy;
    vec3 base = texture(iChannel0, uv).rgb;
    vec3 ghost_a = texture(iChannel0, clamp(uv + vec2(0.0, px.y * 2.5), vec2(0.001), vec2(0.999))).rgb;
    vec3 ghost_b = texture(iChannel0, clamp(uv + vec2(px.x * 1.2, px.y * 1.5), vec2(0.001), vec2(0.999))).rgb;

    float luma = dot(base, vec3(0.2126, 0.7152, 0.0722));
    float ghost_luma = dot(ghost_a, vec3(0.2126, 0.7152, 0.0722)) * 0.35;
    ghost_luma += dot(ghost_b, vec3(0.2126, 0.7152, 0.0722)) * 0.2;
    luma = max(luma, ghost_luma);

    float scan = 0.8 + 0.2 * sin(fragCoord.y * 3.14159);
    float column = 0.9 + 0.1 * sin(fragCoord.x * 1.2);

    float glow = smoothstep(0.0, 1.0, luma);
    vec3 color = vec3(0.0, 0.08, 0.0);
    color += vec3(0.05, 0.95, 0.25) * pow(glow, 1.05);
    color += vec3(0.02, 0.4, 0.08) * pow(glow, 2.3);

    float noise = (hash12(floor(fragCoord) + iTime * 13.0) - 0.5) * 0.02;

    float vignette = 16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vignette = 0.9 + 0.1 * pow(clamp(vignette, 0.0, 1.0), 0.25);

    color *= scan * column;
    color *= vignette;
    color += noise;

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
