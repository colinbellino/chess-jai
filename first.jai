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
    // FIXME: the base metaprogram already has a -release flag, use this instead?
    arg_release := array_find(args_main, "-release");
    target := ifx arg_release then "RELEASE" else "DEBUG";

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
                        // FIXME: remove this
                        add_build_string(tprint("DEBUG :: %;", arg_release == false), workspace);
                        add_build_string("ANIMATION_ENABLE :: true;", workspace);
                        generated_code = true;
                    }
                }
            }
            case .ERROR;    { exit(1); }
            case .COMPLETE; { break; }
        }
    }
    compiler_end_intercept(workspace);

    if arg_open {
        log("------------------------------");
        log("Starting game.");
        run_command(tprint("./%/%", full_output_path, OUTPUT_EXECUTABLE_NAME));
    }
};
