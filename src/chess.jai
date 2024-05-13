Simp  :: #import "Simp";
Input :: #import "Input";
File  :: #import "File";
#import "stb_image_write";
#import "Window_Creation";
#import "Basic";
#import "Math";
#import "System";
#import "String";

TICK_PERIOD : float64 : 1.0 / 60.0; // time between game updates
WANTED_MSAA :: 8;

window: Window_Type;
window_width  : s32 = 1920;
window_height : s32 = 1080;
image_test: Simp.Texture;
screenshot_index := 0;
async_read: *Simp.Pixel_Read;
last_time: float64;
elapsed_time: float64;
dt: float;
my_font: *Simp.Dynamic_Font;
font_data, ok := #run(load_assert("./assets/fonts/OpenSans-BoldItalic.ttf"));

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
        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows.timeBeginPeriod(1);
    }

    window = create_window(window_width, window_height, "A Window", wanted_msaa = WANTED_MSAA);
    msaa := Simp.prepare_window(window, wanted_msaa = WANTED_MSAA);
    window_width, window_height = Simp.get_render_dimensions(window);

    Simp.set_render_target(window, .LEFT_HANDED);

    set_working_directory(path_strip_filename(get_path_of_running_executable()));

    init_fonts();
    image_data := #run(load_assert("./assets/art/pieces.png"));
    success := Simp.texture_load_from_memory(*image_test, xx image_data);
    assert(success);

    quit := false;
    want_screenshot := false;
    while !quit {
        Input.update_window_events();

        for record : Input.get_window_resizes() {
            Simp.update_window(record.window);

            if record.window == window {
                window_width  = record.width;
                window_height = record.height;

                should_reinit := (record.width != window_width) || (record.height != window_height);
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

                    if event.key_pressed && event.key_code == #char " " {  // Press spacebar to take a screenshot.
                        want_screenshot = true;
                    }
                }
            }
        }

        frame_begin();

        if want_screenshot {
            screenshot_index += 1;
            async_read = Simp.pixel_read_begin(null, .RGBA8);
        }

        if async_read && Simp.pixel_read_is_done(async_read) {
            bitmap := Simp.pixel_read_end(async_read);
            filename := tprint("screenshot_%.png\0", screenshot_index);
            // Hardcoded to 4 channels because we know we requested .BGRA8 above.
            stbi_write_png(filename.data, bitmap.width, bitmap.height, 4, bitmap.data.data, xx (bitmap.width * Simp.get_image_bytes_per_texel(bitmap.format)));
            want_screenshot = false;
            Simp.deinit(*bitmap);
            async_read = null;
            log("Screenshot taken: %", filename);
        }

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

    reset_temporary_storage();

    Simp.clear_render_target(.15, .08, .08, 1);
}

frame_draw :: () {
    Simp.set_shader_for_color();

    time := seconds_since_init();

    // This is our own code to set up a rotating square:
    {
        b := cast(float)window_height / 10;
        p: Vector2;
        p.x = cast(float)(window_width  / 2);
        p.y = cast(float)(window_height / 2);

        theta := cast(float) fmod_cycling(time, TAU);

        ct := cos(theta);
        st := sin(theta);

        w := Vector2.{b*ct, b*st};
        h := Vector2.{b*st, -b*ct};

        p0 := p - w - h;
        p1 := p + w - h;
        p2 := p + w + h;
        p3 := p - w + h;

        a :: 1.0;
        c0 := Vector4.{1, 0, 0, a};
        c1 := Vector4.{0, 1, 0, a};
        c2 := Vector4.{0, 0, 1, a};
        c3 := Vector4.{1, 1, 1, a};

        Simp.immediate_quad(p0, p1, p2, p3, c0, c1, c2, c3);
    }

    // Draw some text.
    {
        // Do a bunch of wacky math to figure out the text color.
        theta := cast(float) fmod_cycling(time*3, TAU);

        color: Vector4;
        color.x = cos(theta)*.5+.5;
        Clamp(*color.x, 0, 1);
        color.y = 1;
        color.z = sin(theta)*-.5+.5;
        Clamp(*color.z, 0, 1);
        color.w = 1;

        // Now, to draw the text:
        text := tprint("Simp! %", dt);

        // We could just call Simp.draw_text to draw text! But we want to know the width
        // so that we can center the text, and to find the width, we have to do all the
        // text layout. So it makes sense just to draw the prepared text after that,
        // so there's a special routine, "draw_prepared_text", that draws the thing
        // you just prepared and got the width of.

        text_width := Simp.prepare_text(my_font, text);

        text_x := (window_width - text_width) / 2;
        text_y := window_height/2 + my_font.character_height/4;

        Simp.draw_prepared_text(my_font, text_x, text_y, color);
    }


    if image_test.width && image_test.height {
        // Draw the texture test, to make sure
        // it comes out right-side-up.

        Simp.set_shader_for_images(*image_test);
        Simp.immediate_begin();

        w := window_height/8.0;
        y0 := cast(float) window_height;

        Simp.immediate_quad(.{0, y0-w}, .{w, y0-w}, .{w, y0}, .{0, y0});
        Simp.immediate_flush();
    }
}

frame_end :: () {
    Simp.swap_buffers(window);
}

init_fonts :: () {
    pixel_height := window_height / 24;
    my_font = Simp.get_font_at_size(xx font_data, pixel_height);
    assert(my_font != null);
}

load_assert :: (name: string) -> string {
    data, ok := File.read_entire_file(name);
    assert(ok, tprint("Couldn't load file: %.", name));
    return data;
}
