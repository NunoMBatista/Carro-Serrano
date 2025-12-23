shader_type canvas_item;
render_mode unshaded;

// Screen texture (automatic in Godot). Use nearest filtering for cheaper sampling.
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
// Fog color (not used in this shader but left declared in original)
uniform vec4 fog_color: source_color;

/// How many screen pixels each block covers.
/// - Larger values = bigger square "pixels" (stronger pixelation / lower resolution).
/// - hint_range(1.0, 64.0, 1.0) = (min, max, step):
///     - min = 1.0: prevents zero or negative block size (at least one pixel).
///     - max = 64.0: sensible upper bound to avoid excessively large blocks.
///     - step = 1.0: slider increments in whole-pixel steps so the value behaves like an integer.
/// - Typical range: 1 (no pixelation) to 64 (very blocky). Default = 8.
uniform float resolution_downsampling: hint_range(1.0, 64.0, 1.0) = 8.0;
/// Number of discrete color levels per channel after posterization.
/// - Smaller values = fewer colors (more posterized / GIF-like).
/// - This is "levels per channel"; e.g. 2 => fully binary per channel, 4 => 4 possible values per channel.
/// - hint_range(2.0, 64.0, 1.0) meaning:
///     - 2.0  = minimum allowed levels per channel.
///     - 64.0 = maximum allowed levels per channel in the editor.
///     - 1.0  = slider step increment (keeps the value integer-like).
/// - Range shown in editor: 2..64. Default = 4.
uniform float bit_depth: hint_range(2.0, 64.0, 1.0) = 4.0;
/// Strength of the Bayer dithering pattern applied before posterization.
/// - 0 = no dithering. ~1 = visible dithering. >1 increases effect (may produce negative/overflow before clamp).
/// - hint_range(0.0, 2.0, 0.1) meaning:
///     - 0.0 = minimum (dithering disabled).
///     - 2.0 = maximum value shown on the slider (upper experimental bound).
///     - 0.1 = slider step increment (fine-grained control).
/// - Values above 1 can be used experimentally to exaggerate dither influence.
uniform float dither_strength: hint_range(0.0, 2.0, 0.1) = 1.0;
// Optional desaturation: set to 0.0 to disable (faster when disabled)
uniform float desaturate_amount: hint_range(0.0, 1.0, 0.05) = 0.15;

/// 4x4 Bayer threshold map pre-scaled to roughly center around 0.
/// Values are offsets applied to color channels prior to quantization.
/// The matrix values are in the range ~[-0.5, +0.5].
// Flattened 4x4 Bayer map (row-major). Using a 1D const array avoids mat4 indexing overhead.
const float bayer[16] = float[](
    -0.5,  0.0,   -0.375,  0.125,
     0.25, -0.25,  0.375, -0.125,
    -0.3125, 0.1875, -0.4375, 0.0625,
     0.4375, -0.0625, 0.3125, -0.1875
);

void fragment() {
    // Compute the size of each pixel block in UV space.
    // SCREEN_PIXEL_SIZE is the size of one screen pixel in UV coordinates (Vec2).
    vec2 pixel_size = SCREEN_PIXEL_SIZE * resolution_downsampling;

    // Compute block coordinates and center sample UV
    vec2 block_coords = floor(SCREEN_UV / pixel_size);
    vec2 UV_block = (block_coords + vec2(0.5)) * pixel_size;

    // Single texture fetch (nearest filter), cheap when using integer-aligned UVs
    vec3 tex = texture(SCREEN_TEXTURE, UV_block).rgb;

    // Bayer index (0..3 for x and y), then flatten: idx = x*4 + y
    int ix = int(mod(block_coords.x, 4.0));
    int iy = int(mod(block_coords.y, 4.0));
    int idx = ix * 4 + iy;
    float bayer_shift = bayer[idx];

    // Apply dithering offset and posterize
    float inv_levels = 1.0 / max(bit_depth, 2.0);
    tex += vec3(bayer_shift) * (dither_strength * inv_levels);
    float levels_minus1 = max(bit_depth, 2.0) - 1.0;
    tex = floor(tex * levels_minus1 + 0.5) / levels_minus1;

    // Optional mild desaturation to mimic compressed/GIF look.
    if (desaturate_amount > 0.001) {
        float luma = dot(tex, vec3(0.299, 0.587, 0.114));
        tex = mix(vec3(luma), tex, 1.0 - desaturate_amount);
    }

    // Output color (opaque).
    COLOR.rgb = tex;
    COLOR.a = 1.0;
}
