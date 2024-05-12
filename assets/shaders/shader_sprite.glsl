@header package shader_sprite
@header import sg "external:sokol-odin/sokol/gfx"
@header import "src:shaders"; @(init) shader_init :: proc() { shaders.shaders["shader_sprite"] = sprite_shader_desc }
@header import "core:math/linalg"
@ctype mat4 linalg.Matrix4x4f32

@vs vs
uniform vs_uniform {
    mat4 mvp;
};

in vec2 position;
in vec2 uv;

in vec2 i_position;
in vec2 i_scale;
in vec4 i_color;
in vec2 i_t_position;
in vec2 i_t_size;
in float i_palette;
in float i_z_index;

out vec4 f_color;
out vec2 f_uv;
out vec2 f_t_position;
out vec2 f_t_size;
out float f_palette;

void main() {
    vec4 position_v4 = vec4(position * i_scale, 0.0, 1.0);
    vec4 i_position_v4 = vec4(i_position, 0.0, 1.0);
    gl_Position.a = i_z_index; // We use i_z_index here even if it does nothing, just so it doesn't get removed by sokol codegen (or that would change the memory layout)
    gl_Position = mvp * (i_position_v4 + position_v4);
    f_color = i_color;
    f_uv = uv;
    f_t_position = i_t_position;
    f_t_size = i_t_size;
    f_palette = i_palette;
}
@end

@fs fs
const int PALETTE_SIZE = 8;
const int PALETTE_MAX = 4;

uniform texture2D tex;
uniform sampler smp;

uniform fs_uniform {
    vec4[PALETTE_SIZE * PALETTE_MAX] palettes;
};

in vec4 f_color;
in vec2 f_uv;
in vec2 f_t_position;
in vec2 f_t_size;
in float f_palette;

out vec4 frag_color;

bool vec4_approx_equal(vec4 a, vec4 b) {
    float ESPILON = 0.1;
    return (
        abs(a.r - b.r) <= ESPILON &&
        abs(a.g - b.g) <= ESPILON &&
        abs(a.b - b.b) <= ESPILON &&
        abs(a.a - b.a) <= ESPILON
    );
}

/*
Resources concerning this shader:
- https://hero.handmade.network/episode/chat/chat018/
- https://jorenjoestar.github.io/post/pixel_art_filtering/
- https://www.shadertoy.com/view/MlB3D3
- https://medium.com/@michelotti.matthew/rendering-pixel-art-c07a85d2dc43
- https://colececil.io/blog/2017/scaling-pixel-art-without-destroying-it/
*/
void main() {
    vec2 texture_size = vec2(textureSize(sampler2D(tex, smp), 0));

    vec2 uv = f_t_position + f_t_size * f_uv;

    { // Fat pixel AA
        vec2 pix = uv * texture_size;
        vec2 fat_pixel = vec2(
            floor(pix.x) + smoothstep(0.0, 1.0, fract(pix.x) / fwidth(pix.x)) - 0.5,
            floor(pix.y) + smoothstep(0.0, 1.0, fract(pix.y) / fwidth(pix.y)) - 0.5
        );
        // uv = fat_pixel / texture_size;
    }

    frag_color = texture(sampler2D(tex, smp), uv);

    int palette_index = int(f_palette);
    int color_index = 0;
    for (int i = 0; i < PALETTE_SIZE; i += 1) {
        if (vec4_approx_equal(palettes[i].rgba, frag_color.rgba)) {
            color_index = i;
            break;
        }
    }

    float t = clamp(palette_index, 0, 1);
    frag_color.xyz = mix(frag_color.xyz, palettes[(palette_index * PALETTE_SIZE) + color_index].xyz, t);

    frag_color *= f_color;
}
@end

@program sprite vs fs
