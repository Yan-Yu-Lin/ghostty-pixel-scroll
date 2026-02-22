// Built-in preset: flat full-screen amber monochrome glass terminal.

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec3 src = texture(iChannel0, uv).rgb;
    float luma = dot(src, vec3(0.2126, 0.7152, 0.0722));

    float beam = smoothstep(0.05, 1.0, luma);
    vec3 amber_dark = vec3(0.16, 0.06, 0.0);
    vec3 amber_mid = vec3(0.9, 0.45, 0.03);
    vec3 amber_hot = vec3(1.0, 0.82, 0.12);

    vec3 color = mix(amber_dark, amber_mid, beam);
    color = mix(color, amber_hot, pow(beam, 2.2));

    float scan = 0.82 + 0.18 * sin(fragCoord.y * 3.14159);
    float shadow_mask = 0.9 + 0.1 * sin(fragCoord.x * 1.0);

    float vignette = 16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vignette = 0.9 + 0.1 * pow(clamp(vignette, 0.0, 1.0), 0.24);

    color *= scan * shadow_mask * vignette;
    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
