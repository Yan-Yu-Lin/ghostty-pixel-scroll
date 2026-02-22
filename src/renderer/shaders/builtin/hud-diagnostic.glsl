// Built-in preset: dark HUD monitor with purple highlights and overlay grid.

vec2 warp(vec2 uv) {
    vec2 p = uv * 2.0 - 1.0;
    p *= 1.0 + 0.05 * dot(p, p);
    return p * 0.5 + 0.5;
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 warped = warp(uv);

    if (warped.x < 0.0 || warped.x > 1.0 || warped.y < 0.0 || warped.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.01, 1.0);
        return;
    }

    vec3 src = texture(iChannel0, warped).rgb;
    float luma = dot(src, vec3(0.2126, 0.7152, 0.0722));

    vec3 base_tint = vec3(0.05, 0.08, 0.18);
    vec3 signal = mix(vec3(0.4, 0.2, 0.8), vec3(0.8, 0.65, 1.0), smoothstep(0.1, 1.0, luma));
    vec3 color = base_tint + signal * (luma * 1.2);

    float scan = 0.9 + 0.1 * sin(warped.y * iResolution.y * 3.14159);
    float gridx = smoothstep(0.45, 0.5, abs(fract(warped.x * 24.0) - 0.5));
    float gridy = smoothstep(0.45, 0.5, abs(fract(warped.y * 16.0) - 0.5));
    float grid = 0.92 + 0.08 * max(gridx, gridy);

    vec2 centered = warped - 0.5;
    float crosshair_x = exp(-abs(centered.x) * iResolution.x * 0.01);
    float crosshair_y = exp(-abs(centered.y) * iResolution.y * 0.01);
    vec3 crosshair = vec3(0.2, 0.5, 1.0) * (crosshair_x + crosshair_y) * 0.08;

    float noise = (hash12(floor(fragCoord) + iTime * 31.0) - 0.5) * 0.02;

    float vignette = 16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vignette = pow(clamp(vignette, 0.0, 1.0), 0.2);

    color *= scan * grid * vignette;
    color += crosshair;
    color += noise;

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
