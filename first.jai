#import "Basic";
#import "Compiler";
#import "Process";
#import "File";
#import "File_Utilities";
#import "String";

OUTPUT_PATH            :: "dist";
OUTPUT_EXECUTABLE_NAME :: "chess";

#run {
    set_build_options_dc(.{ do_output = false });

    args_main := get_build_options(1).compile_time_command_line;
    arg_release := array_find(args_main, "-release");
    target := ifx arg_release then "RELEASE" else "DEBUG";
    arg_animation := !array_find(args_main, "-no-animation");

    args := get_build_options().compile_time_command_line;
    arg_open := array_find(args, "-open");
    output_target := tprint("%_%_%", OS, CPU, target);
    full_output_path := tprint("%/%", OUTPUT_PATH, output_target);
    log("Compiling for % | % | %.", OS, CPU, target);

    workspace := compiler_create_workspace("Target workspace");

    options := get_build_options(workspace);
    copy_commonly_propagated_fields(get_build_options(), *options);
    options.os_target  = OS;
    options.cpu_target = CPU;
    options.output_path = full_output_path;
    options.output_executable_name = OUTPUT_EXECUTABLE_NAME;
    if arg_release {
        options.backend = .LLVM;
        set_optimization(*options, .OPTIMIZED);
    } else {
        options.backend = .X64;
        set_optimization(*options, .DEBUG);
    }
    set_build_options(options, workspace);
    make_directory_if_it_does_not_exist(full_output_path, recursive = true);

    compiler_begin_intercept(workspace);
    add_build_file("src/chess.jai", workspace);
    generated_code := false;
    while true {
        message := compiler_wait_for_message();
        if message.kind == {
            case .PHASE;    {
                phase := cast(*Message_Phase) message;
                if phase.phase == .TYPECHECKED_ALL_WE_CAN {
                    if !generated_code {
                        // FIXME: remove this?
                        add_build_string(tprint("DEBUG            :: %;", arg_release == false), workspace);
                        add_build_string(tprint("ANIMATION_ENABLE :: %;", arg_animation), workspace);
                        generated_code = true;
                    }
                }
                if phase.phase == .POST_WRITE_EXECUTABLE {
                    #if OS == .WINDOWS {
                        #import "Windows_Resources";

                        exe_filename := tprint("%/%", full_output_path, phase.executable_name);
                        name := "./assets/icons/icon_256x256.ico";
                        success := set_icon_by_filename(exe_filename, name);
                        if !success {
                            log_error("[Icon] Failed to set the icon for exe '%' to filename '%'.\n", exe_filename, name);
                        }
                    }
                }
            }
            case .ERROR;    { exit(1); }
            case .COMPLETE; { break; }
        }
    }
    compiler_end_intercept(workspace);

    if arg_release {
        #if OS == .MACOS {
            MacOS_Bundler :: #import "MacOS_Bundler";
            MacOS_Bundler.create_app_bundle(
                app_name = "Chess",
                app_exe_path = tprint("%/%", full_output_path, OUTPUT_EXECUTABLE_NAME),
                icon_file_path = "./assets/icons/icon_256x256.icns",
                resource_directory_to_copy = "",
                only_copy_subdirectories_and_files = true,
                write_plist = true
            );
        }
    }

    if arg_open {
        log("------------------------------");
        log("Starting game.");
        run_command(tprint("./%/%", full_output_path, OUTPUT_EXECUTABLE_NAME));
    }
};
