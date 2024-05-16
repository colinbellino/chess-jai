#import "Basic";
#import "SDL";
#import "Math";
#import "GL";

#load "imgui_sdl_gl.jai";
#load "imgui_custom.jai";

EnumTest :: enum s32 { Value1; Value2; Value3; Value4; }
Weird_Structure :: struct {
    name: string;
    v4: Vector4;
    v3: Vector3;
    b: bool;
    i32: s32;
    i64: int;
    unsigned: u32;
    float_array : [4]float;
    enum_test : EnumTest;
}

weird_structure : Weird_Structure;
show_inspector := true;

main :: () {
    SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMECONTROLLER);

    window := SDL_CreateWindow("ImGui SDL2+OpenGL example", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 1280, 720, SDL_WINDOW_OPENGL|SDL_WINDOW_RESIZABLE);
    if window == null {
        print("Could not create window: %\n", to_string(SDL_GetError()));
        return;
    }

    //SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    //SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);

    gl_context := SDL_GL_CreateContext(window);
    if !gl_context {
        print( "Could not create OpenGL context: %\n", to_string(SDL_GetError()));
        return;
    }

    gl_load(*gl, SDL_GL_GetProcAddress);

    imgui_context := ImGui.CreateContext();
    ImGui_ImplSdl_Init(window);
    // ImGui.StyleColorsClassic();
    // ImGui.StyleColorsLight();

    io := ImGui.GetIO();
    clear_color := rgba(0.45, 0.55, 0.60, 1.00);

    done := false;
    while !done {
        // You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
        // - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application.
        // - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application.
        // Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.
        event: SDL_Event;
        while SDL_PollEvent(*event) {
            ImGui_ImplSdl_ProcessEvent(*event);
            if event.type == SDL_QUIT {
                done = true;
            }
            if event.type == SDL_WINDOWEVENT && event.window.event == SDL_WINDOWEVENT_CLOSE && event.window.windowID == SDL_GetWindowID(window) {
                done = true;
            }
        }

        ImGui_ImplSdl_NewFrame(window);
        ImGui.NewFrame();
        {
            if ImGui.Button("Inspector", size=.{0,0}) {
                show_inspector ^= true;
            }
            ImGui.Text("Application average % ms/frame (% FPS)", formatFloat(1000.0 / io.Framerate), cast(u32) io.Framerate);
        }

        if show_inspector {
            imgui_inspect("weird_structure", *weird_structure);
        }

        if ImGui.GetMouseCursor() == {
            case .Arrow;         SDL_SetCursor(cursor_arrow);
            case .TextInput;     SDL_SetCursor(cursor_text_input);
            case .Hand;          SDL_SetCursor(cursor_move);
            case .ResizeNS;      SDL_SetCursor(cursor_resize_ns);
            case .ResizeEW;      SDL_SetCursor(cursor_resize_ew);
            case .ResizeNESW;    SDL_SetCursor(cursor_resize_nesw);
            case .ResizeNWSE;    SDL_SetCursor(cursor_resize_nwse);
        }

        ImGui.Render();
        glViewport(0, 0, xx io.DisplaySize.x, xx io.DisplaySize.y);
        glClearColor(clear_color.x, clear_color.y, clear_color.z, clear_color.w);
        glClear(GL_COLOR_BUFFER_BIT);
        ImGui_ImplSdl_RenderDrawLists(ImGui.GetDrawData());
        SDL_GL_SwapWindow(window);
    }

    // ImGui_ImplSdl_Shutdown();
    // ImGui.DestroyContext(imgui_context);
    // SDL_GL_DeleteContext(gl_context);
    // SDL_DestroyWindow(window);
    // SDL_Quit();
}
