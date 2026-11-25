shader_type sky;

uniform sampler2D cirrus_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D altocumulus_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D cloud_normals_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D overcast_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D moon_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D stars_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 moon_color = vec3(0.68, 0.80, 0.96);
uniform float moon_intensity = 0.95;
uniform float moon_size = 0.042;
uniform float stars_intensity = 1.45;

uniform vec3 sun_color = vec3(1.0, 0.992222, 0.985294);
uniform float sun_intensity = 1.41;
uniform float sky_tint = 1.54;
uniform float day_brightness = 8.0;
uniform float day_haziness = 0.18;
uniform float night_haziness = 0.50;
uniform float mie_g = 0.85;
uniform float one_over_gamma = 0.454545;

// Original Stranded Deep 4 Clouds_MAT (PID=5) + AtmosphereClouds Controls
uniform float storm_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.45;
uniform float altocumulus_density = 0.80;
uniform float cirrus_density = 0.35;
uniform float cloud_scattering_intensity = 7.0;
uniform float edge_blur_20 = 0.20;

// Cloud Position & Controlled Wind Path (Original _WindDirection = 2,1,2 & Speed1=0.2, Speed2=0.4)
uniform vec2 cloud_position_offset = vec2(0.18, -0.12);
uniform vec2 wind_dir = vec2(2.0, 2.0);
uniform float wind_speed = 0.05;
uniform float cloud_speed_1 = 0.20;
uniform float cloud_speed_2 = 0.40;

float phase_rayleigh(float mu) {
    return (3.0 / (16.0 * PI)) * (1.0 + mu * mu);
}

float phase_mie(float mu, float g) {
    float g2 = g * g;
    float denom = max(0.001, 1.0 + g2 - 2.0 * g * mu);
    return (3.0 / (8.0 * PI)) * ((1.0 - g2) * (1.0 + mu * mu)) / ((2.0 + g2) * pow(denom, 1.5));
}

float edge_mask_20(vec2 uv) {
    vec2 d = min(uv, 1.0 - uv);
    float m = smoothstep(0.0, edge_blur_20, min(d.x, d.y));
    float r = length(uv - 0.5) * 2.0;
    return m * smoothstep(1.05, 1.05 - edge_blur_20 * 1.4, r);
}

vec4 sample_blurred_ac(vec2 uv) {
    float mask = edge_mask_20(uv);
    if (mask <= 0.001) return vec4(0.5, 0.5, 1.0, 0.0);
    float b = 0.012 * (1.0 - mask * 0.65);
    float d = (
        texture(altocumulus_tex, uv).r * 0.40 +
        texture(altocumulus_tex, clamp(uv + vec2(b, 0.0), 0.002, 0.998)).r * 0.15 +
        texture(altocumulus_tex, clamp(uv - vec2(b, 0.0), 0.002, 0.998)).r * 0.15 +
        texture(altocumulus_tex, clamp(uv + vec2(0.0, b), 0.002, 0.998)).r * 0.15 +
        texture(altocumulus_tex, clamp(uv - vec2(0.0, b), 0.002, 0.998)).r * 0.15
    ) * mask;
    return vec4(texture(cloud_normals_tex, uv).xyz, d);
}

void sky() {
    vec3 v = normalize(EYEDIR);
    vec3 s = normalize(LIGHT0_DIRECTION);
    float mu = dot(v, s);
    float vh = clamp(v.y, 0.0, 1.0);
    float sh = s.y;
    float day = clamp((sh + 0.12) / 0.35, 0.0, 1.0);

    float haz = mix(night_haziness, mix(day_haziness, 0.72, storm_intensity), day);
    vec3 z_clr = vec3(0.022, 0.175, 0.56) * sky_tint;
    vec3 h_clr = mix(vec3(0.36, 0.68, 0.96), vec3(1.0, 0.52, 0.22), pow(1.0 - clamp(sh * 2.5, 0.0, 1.0), 2.5));

    vec3 zen = mix(vec3(0.004, 0.010, 0.024), mix(z_clr, vec3(0.09, 0.12, 0.17), storm_intensity), day);
    vec3 hor = mix(vec3(0.012, 0.025, 0.048), mix(h_clr, vec3(0.22, 0.26, 0.32), storm_intensity), day);

    vec3 base_sky = mix(zen, hor, pow(1.0 - vh, mix(4.5, 2.5, haz)));
    vec3 scatter = base_sky * (0.72 + phase_rayleigh(mu) * 1.15);
    vec3 mie_glow = sun_color * phase_mie(mu, mie_g) * mix(0.01, 0.10, day) * sun_intensity * (1.0 - storm_intensity * 0.85);

    float disc = smoothstep(0.99945, 0.99985, mu) * day * 12.0 * (1.0 - storm_intensity * 0.95);
    float cor = pow(max(mu, 0.0), 115.0) * day * 1.0 * (1.0 - storm_intensity * 0.85);

    vec3 sky_col = (scatter * mix(0.35, day_brightness * 0.17, day)) + mie_glow + sun_color * (disc + cor) * sun_intensity;
    vec3 m_dir = -s;
    float mu_moon = dot(v, m_dir);
    float night = (1.0 - day) * (1.0 - storm_intensity * 0.85);
    if (v.y > -0.05 && night > 0.001) {
        vec2 star_uv = vec2(atan(v.z, v.x) / (2.0 * PI) + 0.5 + TIME * 0.0004, asin(clamp(v.y, -1.0, 1.0)) / (0.5 * PI));
        sky_col += texture(stars_tex, star_uv * vec2(3.0, 1.5)).rgb * smoothstep(0.0, 0.25, v.y) * night * stars_intensity;
        float m_up_vis = smoothstep(-0.04, 0.08, m_dir.y);
        sky_col += moon_color * (pow(max(mu_moon, 0.0), 28.0) * 0.28 + pow(max(mu_moon, 0.0), 180.0) * 0.65) * moon_intensity * m_up_vis * night;
        if (mu_moon > 0.985 && m_up_vis > 0.001) {
            vec3 up_ref = abs(m_dir.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
            vec3 mr = normalize(cross(up_ref, m_dir));
            vec3 mu_v = cross(m_dir, mr);
            vec2 m_uv = vec2(dot(v - m_dir, mr), dot(v - m_dir, mu_v)) / (moon_size * 2.0) + 0.5;
            if (m_uv.x >= 0.0 && m_uv.x <= 1.0 && m_uv.y >= 0.0 && m_uv.y <= 1.0) {
                vec4 mt = texture(moon_tex, m_uv);
                float cmask = 1.0 - smoothstep(0.46, 0.50, length(m_uv - 0.5));
                sky_col = mix(sky_col, mt.rgb * moon_color * 2.4 * moon_intensity, mt.a * cmask * m_up_vis * night);
            }
        }
    }
    vec3 col = sky_col;

    if (v.y > 0.015) {
        vec2 uv = (v.xz / (v.y + 0.22)) + cloud_position_offset;
        float hfade = smoothstep(0.015, 0.24, v.y);

        // Controlled Wind Path (Original Speed1 = 0.20, Speed2 = 0.40)
        vec2 wdir = normalize(wind_dir + vec2(0.0001));
        float spd = wind_speed * mix(1.0, 2.4, storm_intensity);
        vec2 drift1 = wdir * (TIME * spd * cloud_speed_1);
        vec2 drift2 = wdir * (TIME * spd * cloud_speed_2);

        // 1. High-altitude Cirrus Layer (Separate position & faster wind path)
        vec2 cuv = fract(uv * 0.24 + drift2 + vec2(0.31, 0.67));
        float cir = texture(cirrus_tex, cuv).r * edge_mask_20(cuv) * cirrus_density * (1.0 - storm_intensity * 0.7) * hfade;
        col = mix(col, mix(sky_col, sun_color * 1.15, 0.65 * day), clamp(cir, 0.0, 0.45));

        // 2. Spatially Separated AltoCumulus Clusters (Separated by quadrant offset so blue sky shows between!)
        vec2 uv1 = fract(uv * 0.28 + drift1);
        vec2 uv2 = fract(vec2(uv.y, -uv.x) * 0.25 + drift1 * 0.85 + vec2(0.47, 0.53));
        vec4 ac1 = sample_blurred_ac(uv1);
        vec4 ac2 = sample_blurred_ac(uv2);

        vec4 best = (ac1.a >= ac2.a) ? ac1 : ac2;
        float fair_d = max(ac1.a, ac2.a * 0.92);

        // 3. Seasonal Overcast Deck (Overcast_ID108)
        vec2 ouv = fract(uv * 0.18 + drift1 * 0.7 + vec2(0.15, 0.25));
        float ov = texture(overcast_tex, ouv).r * edge_mask_20(ouv);

        // Season Coverage Thresholding (0.0 = Sparse Clear -> 1.0 = Full Overcast Storm)
        float eff_cov = mix(cloud_coverage, 1.0, storm_intensity);
        float thresh = mix(0.42, 0.02, eff_cov);
        float raw_d = mix(fair_d, max(fair_d * 0.75, ov * 1.3), storm_intensity);
        float alpha = smoothstep(thresh, thresh + 0.48, raw_d * altocumulus_density * 1.35) * hfade;

        vec3 nrm = normalize((best.xyz * 2.0 - 1.0) * vec3(1.2, 1.2, 1.0));
        float lit = clamp(dot(vec3(nrm.x, nrm.z, nrm.y), s) * 0.55 + 0.48, 0.0, 1.0);
        float rim = (1.0 - raw_d) * pow(max(mu, 0.0), 5.0) * (cloud_scattering_intensity * 0.13) * (1.0 - storm_intensity * 0.85);

        vec3 c_bot = mix(vec3(0.015, 0.025, 0.05), mix(vec3(0.30, 0.44, 0.64), vec3(0.07, 0.09, 0.13), storm_intensity), day);
        vec3 c_top = mix(vec3(0.05, 0.08, 0.15), mix(sun_color * 1.14, vec3(0.24, 0.28, 0.35), storm_intensity), day);

        vec3 cloud_col = mix(c_bot, c_top, lit) + sun_color * rim * day;
        cloud_col = mix(sky_col, cloud_col, smoothstep(0.015, 0.26, v.y));
        col = mix(col, cloud_col, clamp(alpha * mix(0.92, 0.98, storm_intensity), 0.0, 0.98));
    } else {
        col = mix(hor * mix(0.25, 0.85, day), vec3(0.01, 0.04, 0.08) * max(day, 0.12), clamp(-v.y * 6.0, 0.0, 1.0));
    }

    col = col / (1.0 + col * 0.45);
    COLOR = pow(max(col, vec3(0.0)), vec3(one_over_gamma * 2.2));
}
