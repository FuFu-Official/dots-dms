#language slang 2026

import kitty_custom_shader_types;

// Adapted from patricorgi/kitty-sliding-tabs, dd9a95fd49576bc8296c55fb7a7814744a1a3e11.
// Python supplies dimensions and the live DMS palette in ten spare cells.
// No theme colors or font/DPI assumptions are compiled into this shader.
static const float CORNER_RADIUS = 24.8;

int read_marker(float3 color, int signature) {
    if (any(color < 0.10)) return -1;
    float3 srgb = 1.055 * pow(color, float3(1.0 / 2.4)) - 0.055;
    int3 levels = int3(round((srgb * 255.0 - 96.0) / 5.0));
    if (any(levels < 0) || any(levels > 31)) return -1;
    int value = (levels.x << 10) | (levels.y << 5) | levels.z;
    return (value >> 13) == signature ? value & 8191 : -1;
}

float4 record_cell(KittyTextures t, float2 pixel, float y, float cell_width, int offset) {
    return t.backbuffer.Sample(float2(1.0 - (float(offset) + 0.5) * cell_width * pixel.x, y));
}

float coverage_of(float3 color, float3 background, float3 ink) {
    float3 delta = ink - background;
    return saturate(dot(color - background, delta) / max(dot(delta, delta), 0.00001));
}

float rounded_fill(float x, float y, float height, float2 bounds) {
    float inset = min(0.5, (height - 1.0) * 0.5);
    float radius = clamp(CORNER_RADIUS * height / 53.0, 0.0, height * 0.75);
    float vertical_radius = max(0.001, min(radius * (23.1 / 24.8), height * 0.5 - inset));
    float4 sample_y = y + float4(-0.375, -0.125, 0.125, 0.375);
    float4 edge = min(sample_y, height - sample_y) - inset;
    float4 u = 1.0 - sqrt(saturate(edge / vertical_radius));
    float4 corner_inset = radius * pow(u, float4(2.14));
    float distance_to_side = min(x - bounds.x, bounds.y - x);
    return dot(step(float4(0.0), edge) * saturate(distance_to_side - corner_inset + 0.5), float4(0.25));
}

public float4 fragment_main(float4 color, KittyTextures t, uniform KittyCustomShaderData d) {
    float2 pixel = 1.0 / float2(d.viewport_size_pixels);
    float content_top = d.central_area.y + d.central_area.w;
    float content_bottom = d.central_area.y;
    // Find the horizontal bar outside the central content area. Comparing
    // band sizes also avoids roundoff near UV 1 when the bar is at the bottom.
    bool bar_at_top = (1.0 - content_top) > content_bottom;
    if (bar_at_top) {
        if (content_top >= 1.0 || t.pos.y < content_top) return color;
    } else {
        if (content_bottom <= 0.0 || t.pos.y >= content_bottom) return color;
    }

    // Inner margin is zero. Sample just outside the content area, toward the
    // bar: upward for a top bar and downward for a bottom bar.
    float sample_y = bar_at_top ? content_top + 0.5 * pixel.y
                                : content_bottom - 0.5 * pixel.y;
    int cw = read_marker(t.backbuffer.Sample(float2(1.0 - 0.5 * pixel.x, sample_y)).rgb, 1);
    if (cw < 1 || cw > 512) return color;
    float cell_width = float(cw);
    int ch = read_marker(record_cell(t, pixel, sample_y, cell_width, 1).rgb, 2);
    if (ch < 1 || ch > 1024) return color;
    float top = bar_at_top ? content_top + float(ch) * pixel.y : content_bottom;
    float bottom = bar_at_top ? content_top : content_bottom - float(ch) * pixel.y;
    if (t.pos.y < bottom || t.pos.y >= top) return color;

    int left = read_marker(record_cell(t, pixel, sample_y, cell_width, 2).rgb, 1);
    int right = read_marker(record_cell(t, pixel, sample_y, cell_width, 3).rgb, 2);
    int target_left = read_marker(record_cell(t, pixel, sample_y, cell_width, 4).rgb, 3);
    int target_right = read_marker(record_cell(t, pixel, sample_y, cell_width, 5).rgb, 2);
    float record_start = float(d.viewport_size_pixels.x) - 10.0 * cell_width;
    if (left < 0 || right <= left || target_left < 0 || target_right <= target_left
        || float(right) > record_start || float(target_right) > record_start) return color;

    float3 highlight = record_cell(t, pixel, sample_y, cell_width, 6).rgb;
    float3 active_ink = record_cell(t, pixel, sample_y, cell_width, 7).rgb;
    float3 inactive_ink = record_cell(t, pixel, sample_y, cell_width, 8).rgb;
    float4 background = record_cell(t, pixel, sample_y, cell_width, 9);
    float x = t.pos.x / pixel.x;
    // Kitty extends the first tab's native fill into fractional-cell padding.
    float grid_left = float(d.viewport_size_pixels.x % uint(cw));
    if (x < grid_left || x >= record_start) return background;

    bool under_target = x >= float(target_left) && x < float(target_right);
    if (!under_target && (x < float(left) || x >= float(right))) return color;
    float fill = rounded_fill(x, (top - t.pos.y) / pixel.y, float(ch), float2(float(left), float(right)));
    float3 old_background = under_target ? highlight : background.rgb;
    float3 old_ink = under_target ? active_ink : inactive_ink;
    float alpha = coverage_of(color.rgb, old_background, old_ink);
    float3 new_background = lerp(background.rgb, highlight, fill);
    float3 new_ink = lerp(inactive_ink, active_ink, fill);
    return float4(lerp(new_background, new_ink, alpha), color.a);
}
