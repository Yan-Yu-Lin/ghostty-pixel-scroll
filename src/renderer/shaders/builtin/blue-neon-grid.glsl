// Built-in preset: cobalt + magenta cyber look with coarse pixels and glow.

vec2 warp(vec2 uv) {
    vec2 p = uv * 2.0 - 1.0;
    p *= 1.0 + 0.07 * dot(p, p);
    return p * 0.5 + 0.5;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 warped = warp(uv);

    if (warped.x < 0.0 || warped.x > 1.0 || warped.y < 0.0 || warped.y > 1.0) {
        fragColor = vec4(0.01, 0.02, 0.08, 1.0);
        return;
    }

    vec2 block = floor(warped * iResolution.xy / 2.0) * 2.0 / iResolution.xy;
    vec3 src = texture(iChannel0, block).rgb;

    float luma = dot(src, vec3(0.2126, 0.7152, 0.0722));
    float quant = floor(luma * 8.0) / 8.0;

    vec3 cyan = vec3(0.12, 0.95, 1.0);
    vec3 magenta = vec3(1.0, 0.25, 0.9);
    vec3 tone = mix(cyan, magenta, smoothstep(0.15, 0.9, quant));

    vec3 color = tone * (quant * 1.35 + 0.1);

    float scan = 0.88 + 0.12 * sin(warped.y * iResolution.y * 3.14159);
    float grid_x = smoothstep(0.0, 0.65, abs(fract(warped.x * iResolution.x * 0.5) - 0.5));
    float grid_y = smoothstep(0.0, 0.65, abs(fract(warped.y * iResolution.y * 0.5) - 0.5));
    float grid = 0.9 + 0.1 * (grid_x * grid_y);

    vec2 px = vec2(1.0) / iResolution.xy;
    vec3 bloom = texture(iChannel0, warped + vec2(px.x * 2.0, 0.0)).rgb;
    bloom += texture(iChannel0, warped - vec2(px.x * 2.0, 0.0)).rgb;
    bloom += texture(iChannel0, warped + vec2(0.0, px.y * 2.0)).rgb;
    bloom += texture(iChannel0, warped - vec2(0.0, px.y * 2.0)).rgb;
    bloom *= 0.25;

    float bloom_luma = dot(bloom, vec3(0.2126, 0.7152, 0.0722));
    color += mix(cyan, magenta, 0.5) * bloom_luma * 0.25;

    float vignette = 16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vignette = pow(clamp(vignette, 0.0, 1.0), 0.2);

    color *= scan * grid * vignette;
    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
