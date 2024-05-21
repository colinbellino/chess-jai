Simp  :: #import "Simp";
Input :: #import "Input";
File  :: #import "File";
#import "stb_image_write";
#import "Window_Creation";
#import "Basic";
#import "Math";
#import "System";
#import "String";

Color :: Vector4;
Vector2s32 :: struct {
    x, y: s32;

    #place x;
    component: [2] s32 = ---;
}

Piece :: struct {
    type:   u8;
    color:  u8;
}
Play_Mode :: enum {
    Init;
    Start_Turn;
    Select_Move;
    Perform_Move;
    End_Turn;
    Game_Over;
}

FEN :: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
BOARD_COLOR_WHITE :: #run(hex_to_color(0xd5ddedff));
BOARD_COLOR_BLACK :: #run(hex_to_color(0x5a738fff));
TICK_PERIOD : float64 : 1.0 / 60.0;
WANTED_MSAA :: 8;
window: Window_Type;
window_size := Vector2s32.{ 1920, 1080 };
texture_pieces: Simp.Texture;
async_read: *Simp.Pixel_Read;
last_time: float64;
elapsed_time: float64;
dt: float;
my_font: *Simp.Dynamic_Font;
font_data := #run(load_file_or_exit("./assets/fonts/OpenSans-BoldItalic.ttf"));
image_data := #run(load_file_or_exit("./assets/art/pieces.png"));
zoom := 48.0;
board_cell_size: float;
board_offset: Vector2;

#run {
    #if OS == .WINDOWS {
        WR :: #import "Windows_Resources";
        WR.disable_runtime_console();
    }
}

main :: () {
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();
        Windows.timeBeginPeriod(1);
    }

    window = create_window(window_size.x, window_size.y, "Chess", wanted_msaa = WANTED_MSAA);
    msaa := Simp.prepare_window(window, wanted_msaa = WANTED_MSAA);
    window_size.x, window_size.y = Simp.get_render_dimensions(window);

    Simp.set_render_target(window, .LEFT_HANDED);

    init_fonts();
    success := Simp.texture_load_from_memory(*texture_pieces, xx image_data);
    assert(success);

    quit := false;
    while !quit {
        Input.update_window_events();

        for record : Input.get_window_resizes() {
            Simp.update_window(record.window);

            if record.window == window {
                window_size.x  = record.width;
                window_size.y = record.height;

                if window_size.x > window_size.y {
                    zoom = window_size.y / 24.0;
                } else {
                    zoom = window_size.x / 24.0;
                }

                should_reinit := (record.width != window_size.x) || (record.height != window_size.y);
                if should_reinit {
                    init_fonts();
                }
            }
        }

        for event : Input.events_this_frame {
            if event.type == {
                case .QUIT; {
                    quit = true;
                }
                case .KEYBOARD; {
                    if event.key_pressed && event.key_code == .ESCAPE {
                        quit = true;
                    }
                }
            }
        }

        frame_begin();
        frame_update();
        frame_draw();
        frame_end();
    }
}

frame_begin :: () {
    while true {
        if elapsed_time >= TICK_PERIOD {
            elapsed_time -= TICK_PERIOD;
            break;
        }

        now := seconds_since_init();
        if last_time{
            dt = cast(float) (now - last_time);
        }
        last_time = now;

        elapsed_time += dt;
        sleep_milliseconds(2);
    }
}

frame_update :: () {
    // TODO: port this
    // if game_mode_entering() {
    //     _mem.play.game = {}
    //     _mem.play.moves = make([dynamic]Move, _mem.game_mode.arena.allocator)
    //     board = fen_to_board(FEN);
    //     controllers[.Black] = .CPU;
    //     rand.init(&_mem.play.rand, _mem.play.seed);

    //     play_mode_transition(.Start_Turn)
    // }
}

frame_draw :: () {
    Simp.clear_render_target(BOARD_COLOR_BLACK.x - 0.25, BOARD_COLOR_BLACK.y - 0.25, BOARD_COLOR_BLACK.z - 0.25, BOARD_COLOR_BLACK.w);

    Simp.set_shader_for_color();

    time := seconds_since_init();

    {
        theta := cast(float) fmod_cycling(time * 3, TAU);

        color: Vector4 = ---;
        color.x = clamp(cos(theta) * 0.5 + 0.5, 0, 1);
        color.y = 1;
        color.z = clamp(sin(theta) * -0.5 + 0.5, 0, 1);
        color.w = 1;

        text := tprint("zoom: %", zoom);
        text_width := Simp.prepare_text(my_font, text);
        text_x := (window_size.x - text_width) / 2;
        text_y := 50 + my_font.character_height / 4;

        Simp.draw_prepared_text(my_font, text_x, text_y, color);
    }

    board_cell_size = zoom * 2.5;
    board_offset = .{
        window_size.x / 2.0 - board_cell_size * 8 / 2,
        window_size.y / 2.0 - board_cell_size * 8 / 2,
    };

    for y : 0 .. 7 {
        for x : 0 .. 7 {
            color := BOARD_COLOR_WHITE;
            if (y + x) % 2 == 0 {
                color = BOARD_COLOR_BLACK;
            }
            draw_rect(.{ board_offset.x + (x * board_cell_size), board_offset.y + (y * board_cell_size) }, .{ board_cell_size, board_cell_size }, color);
        }
    }

    draw_piece(.{ 0, 0 }, .{ 1, 1 });
    draw_piece(.{ 1, 1 }, .{ 2, 1 });
}

frame_end :: () {
    Simp.swap_buffers(window);
    reset_temporary_storage();
}

init_fonts :: () {
    pixel_height := window_size.y / 24;
    my_font = Simp.get_font_at_size(xx font_data, pixel_height);
    assert(my_font != null);
}

load_file_or_exit :: (name: string) -> string {
    data, ok := File.read_entire_file(name);
    assert(ok, tprint("Couldn't load file: %.", name));
    return data;
}

hex_to_color :: (hex_value: s64) -> Color {
    color: Color;
    color.x = cast(float) (cast(u8) (hex_value >> 24) & 0xff) / 255;
    color.y = cast(float) (cast(u8) (hex_value >> 16) & 0xff) / 255;
    color.z = cast(float) (cast(u8) (hex_value >> 8) & 0xff) / 255;
    color.w = cast(float) (cast(u8) (hex_value) & 0xff) / 255;
    return color;
}

draw_rect :: (position: Vector2, size: Vector2, color: Color) {
    Simp.set_shader_for_color();
    Simp.immediate_begin();
    Simp.immediate_quad(position.x, position.y, position.x + size.x, position.y + size.y, color);
    Simp.immediate_flush();
}

draw_piece :: (position: Vector2, piece: Piece) {
    PIECE_TEXTURE_SIZE :: Vector2s32.{ 7, 2 };
    tw := 1.0 / PIECE_TEXTURE_SIZE.x;
    th := 1.0 / PIECE_TEXTURE_SIZE.y;
    tx := cast(float) piece.type * tw;
    ty := cast(float) piece.color * th;
    x := board_offset.x + board_cell_size * position.x;
    y := board_offset.y + board_cell_size * position.y;
    w := board_cell_size;
    h := board_cell_size;

    Simp.set_shader_for_images(*texture_pieces);
    Simp.immediate_begin();
    Simp.immediate_quad(.{ x + 0, y + 0 }, .{ x + w, y + 0 }, .{ x + w, y + h }, .{ x + 0, y + h }, .{ 1, 1, 1, 1 }, .{ tx + 0, ty + 0 }, .{ tx + tw, ty + 0 }, .{ tx + tw, ty + th }, .{ tx + 0, ty + th });
    Simp.immediate_flush();
}
