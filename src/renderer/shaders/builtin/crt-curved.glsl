// Built-in preset: strong curved CRT screen with chromatic split, scanlines,
// and subtle phosphor grille.

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

vec3 sampleRgbSplit(vec2 uv) {
    float px = 1.5 / iResolution.x;
    return vec3(
        texture(iChannel0, uv + vec2(px, 0.0)).r,
        texture(iChannel0, uv).g,
        texture(iChannel0, uv - vec2(px, 0.0)).b
    );
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 warped = crtWarp(uv, 0.14);

    if (warped.x < 0.0 || warped.x > 1.0 || warped.y < 0.0 || warped.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec2 px = vec2(1.0) / iResolution.xy;
    vec3 color = sampleRgbSplit(warped);

    vec3 bloom = vec3(0.0);
    bloom += texture(iChannel0, warped + vec2(px.x * 1.5, 0.0)).rgb;
    bloom += texture(iChannel0, warped - vec2(px.x * 1.5, 0.0)).rgb;
    bloom += texture(iChannel0, warped + vec2(0.0, px.y * 1.5)).rgb;
    bloom += texture(iChannel0, warped - vec2(0.0, px.y * 1.5)).rgb;
    bloom *= 0.25;

    color = mix(color, bloom, 0.33);

    float scanline = 0.9 + 0.1 * sin(warped.y * iResolution.y * 3.14159);

    float stripe = mod(floor(warped.x * iResolution.x), 3.0);
    vec3 grille = vec3(0.9);
    if (stripe < 1.0) {
        grille.r = 1.0;
    } else if (stripe < 2.0) {
        grille.g = 1.0;
    } else {
        grille.b = 1.0;
    }

    float vignette = 16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vignette = pow(clamp(vignette, 0.0, 1.0), 0.23);

    float flicker = 1.0 + 0.012 * sin(iTime * 59.0) + 0.008 * sin(iTime * 23.0);
    float noise = (hash12(floor(fragCoord) + iTime) - 0.5) * 0.03;

    color *= scanline;
    color *= grille;
    color *= vignette * flicker;
    color += noise;
    color *= edgeMask(warped, 0.03);

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
