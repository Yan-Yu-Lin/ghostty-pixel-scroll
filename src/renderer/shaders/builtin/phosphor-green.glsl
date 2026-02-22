// Built-in preset: green phosphor monitor with strong glow and scanlines.

vec2 crtWarp(vec2 uv, float amount) {
    vec2 p = uv * 2.0 - 1.0;
    float r2 = dot(p, p);
    p *= 1.0 + amount * r2;
    return p * 0.5 + 0.5;
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 warped = crtWarp(uv, 0.1);

    if (warped.x < 0.0 || warped.x > 1.0 || warped.y < 0.0 || warped.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec2 px = vec2(1.0) / iResolution.xy;
    vec3 base = texture(iChannel0, warped).rgb;
    vec3 ghost_a = texture(iChannel0, warped + vec2(0.0, px.y * 2.5)).rgb;
    vec3 ghost_b = texture(iChannel0, warped + vec2(px.x * 1.2, px.y * 1.5)).rgb;

    float luma = dot(base, vec3(0.2126, 0.7152, 0.0722));
    float ghost_luma = dot(ghost_a, vec3(0.2126, 0.7152, 0.0722)) * 0.35;
    ghost_luma += dot(ghost_b, vec3(0.2126, 0.7152, 0.0722)) * 0.2;
    luma = max(luma, ghost_luma);

    float scan = 0.78 + 0.22 * sin((warped.y * iResolution.y) * 3.14159);
    float column = 0.88 + 0.12 * sin((warped.x * iResolution.x) * 1.2);

    float glow = smoothstep(0.0, 1.0, luma);
    vec3 color = vec3(0.0, 0.08, 0.0);
    color += vec3(0.05, 0.95, 0.25) * pow(glow, 1.05);
    color += vec3(0.02, 0.4, 0.08) * pow(glow, 2.3);

    float noise = (hash12(floor(fragCoord) + iTime * 13.0) - 0.5) * 0.02;

    float vignette = 16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vignette = pow(clamp(vignette, 0.0, 1.0), 0.25);

    color *= scan * column;
    color *= vignette;
    color += noise;

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
