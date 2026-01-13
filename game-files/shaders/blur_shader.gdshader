shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 10.0) = 5.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec4 color = vec4(0.0);

    // Gaussian blur with 9 samples
    float blur = blur_amount * 0.001;

    // Sample offsets and weights for Gaussian blur
    color += texture(screen_texture, uv + vec2(-blur, -blur)) * 0.05;
    color += texture(screen_texture, uv + vec2(0.0, -blur)) * 0.09;
    color += texture(screen_texture, uv + vec2(blur, -blur)) * 0.05;

    color += texture(screen_texture, uv + vec2(-blur, 0.0)) * 0.09;
    color += texture(screen_texture, uv + vec2(0.0, 0.0)) * 0.46;
    color += texture(screen_texture, uv + vec2(blur, 0.0)) * 0.09;

    color += texture(screen_texture, uv + vec2(-blur, blur)) * 0.05;
    color += texture(screen_texture, uv + vec2(0.0, blur)) * 0.09;
    color += texture(screen_texture, uv + vec2(blur, blur)) * 0.05;

    COLOR = color;
}
