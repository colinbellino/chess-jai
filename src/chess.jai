#import "Basic";
#import "Math";
#import "Window_Creation";
Simp  :: #import "Simp";
Input :: #import "Input";

my_window: Window_Type;
window_width  : s32 = 1920;
window_height : s32 = 1080;

main :: () {
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();

        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows.timeBeginPeriod(1);
    }

    WANTED_MSAA :: 8;
    // On Linux, we need to pass the MSAA value to create_window
    my_window = create_window(window_width, window_height, "Chess", wanted_msaa = WANTED_MSAA);

    msaa := Simp.prepare_window(my_window, wanted_msaa = WANTED_MSAA);
    // log("Wanted MSAA: %\nChosen MSAA: %", WANTED_MSAA, msaa);

    window_width, window_height = Simp.get_render_dimensions(my_window);

    Simp.set_render_target(my_window, .LEFT_HANDED);

    quit := false;
    // want_screenshot := false;
    while !quit {
        Input.update_window_events();

        for Input.get_window_resizes() {
            Simp.update_window(it.window);  // Simp will do nothing if it doesn't care about this window.

            if it.window == my_window {
                window_width  = it.width;
                window_height = it.height;

                should_reinit := (it.width != window_width) || (it.height != window_height);
                // if should_reinit my_init_fonts();  // Resize the font for the new window size.
            }
        }

        for Input.events_this_frame {
            if it.type == .QUIT then quit = true;

            if it.type == {
              case .KEYBOARD;
                if it.key_pressed && it.key_code == .ESCAPE {
                    quit = true;
                }

                // if it.key_pressed && it.key_code == #char " " {  // Press spacebar to take a screenshot.
                //     want_screenshot = true;
                // }
            }
        }

        draw();

        sleep_milliseconds(10);
        reset_temporary_storage();
    }
}

draw :: () {
    Simp.clear_render_target(.15, .08, .08, 1);

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

    // // Draw some text.
    // {
    //     // Do a bunch of wacky math to figure out the text color.
    //     theta := cast(float) fmod_cycling(time*3, TAU);

    //     color: Vector4;
    //     color.x = cos(theta)*.5+.5;
    //     Clamp(*color.x, 0, 1);
    //     color.y = 1;
    //     color.z = sin(theta)*-.5+.5;
    //     Clamp(*color.z, 0, 1);
    //     color.w = 1;

    //     // Now, to draw the text:
    //     text := "Simp!";

    //     // We could just call Simp.draw_text to draw text! But we want to know the width
    //     // so that we can center the text, and to find the width, we have to do all the
    //     // text layout. So it makes sense just to draw the prepared text after that,
    //     // so there's a special routine, "draw_prepared_text", that draws the thing
    //     // you just prepared and got the width of.

    //     text_width := Simp.prepare_text(my_font, text);

    //     text_x := (window_width - text_width) / 2;
    //     text_y := window_height/2 + my_font.character_height/4;

    //     Simp.draw_prepared_text(my_font, text_x, text_y, color);
    // }


    // if image_test.width && image_test.height {
    //     // Draw the texture test, to make sure
    //     // it comes out right-side-up.

    //     Simp.set_shader_for_images(*image_test);
    //     Simp.immediate_begin();

    //     w := window_height/8.0;
    //     y0 := cast(float) window_height;

    //     Simp.immediate_quad(.{0, y0-w}, .{w, y0-w}, .{w, y0}, .{0, y0});
    //     Simp.immediate_flush();
    // }

    Simp.swap_buffers(my_window);
}
