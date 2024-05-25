// FIXME: Bundle into an .app file (mac)
// FIXME: Allocators & leaks

Simp         :: #import "Simp";
Input        :: #import "Input";
File         :: #import "File";
Hash_Table   :: #import "Hash_Table";
GetRect      :: #import "GetRect_LeftHanded";
Sound_Player :: #import "Sound_Player";
#import "Sort";
#import "Random";
#import "Math";
#import "stb_image_write";
#import "Window_Creation";
#import "Basic";
#import "System";
#import "String";

#placeholder ANIMATION_ENABLE;
#placeholder DEBUG;
FEN :: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
BASE_LAYER :: 100;
MAX_HALFMOVES_WITHOUT_CAPTURE :: 100;
BOARD_SIZE :: 8;
BOARD_SIZE_V2 :: Vector2s32.{ BOARD_SIZE, BOARD_SIZE };
BOARD_COLOR_WHITE :: #run(hex_to_color(0xd5ddedff));
BOARD_COLOR_BLACK :: #run(hex_to_color(0x5a738fff));
PIECE_TEXTURE_SIZE :: Vector2.{ 1.0 / 7, 1.0 / 2 };
PIECE_SIZE          :: Vector2.{ 8, 8 };
PIECE_TO_SYMBOL :: u8.[
    /* .None */   #char ".",
    /* .King */   #char "K",
    /* .Pawn */   #char "P",
    /* .Knight */ #char "N",
    /* .Bishop */ #char "B",
    /* .Rook */   #char "R",
    /* .Queen */  #char "Q",
];
SYMBOL_TO_PIECE: Hash_Table.Table(s64, Piece_Type);
DIRECTION_TO_INDEX := int.[
    /* .North */      -BOARD_SIZE,
    /* .South */      +BOARD_SIZE,
    /* .East */       +1,
    /* .West */       -1,
    /* .North_East */ -BOARD_SIZE + 1,
    /* .North_West */ -BOARD_SIZE - 1,
    /* .South_East */ +BOARD_SIZE + 1,
    /* .South_West */ +BOARD_SIZE - 1,
];
TICK_PERIOD : float64 : 1.0 / 60.0;
WANTED_MSAA :: 8;
COLOR_WHITE :: Color.{ 1, 1, 1, 1 };
COLOR_BLACK :: Color.{ 0, 0, 0, 1 };

Direction :: enum u8 {
    North;
    South;
    East;
    West;
    North_East;
    North_West;
    South_East;
    South_West;
}

Piece :: struct {
    color: Piece_Color;
    type:  Piece_Type;
}
Piece_Color :: enum u8 {
    White;
    Black;
}
Piece_Type :: enum u8 {
    None   :: 0;
    King   :: 1;
    Pawn   :: 2;
    Knight :: 3;
    Bishop :: 4;
    Rook   :: 5;
    Queen  :: 6;
}

Controller :: enum {
    Player;
    CPU;
}

Board :: struct {
    active_color:               Piece_Color;
    pieces:                     [BOARD_SIZE * BOARD_SIZE]Piece;
    squares_to_edges:           [BOARD_SIZE * BOARD_SIZE][#run(count_of(Direction))]s32;
    en_passant:                 int;
    halfmoves_without_capture:  s32;
    fullmove_count:             s32;
    castling_right_queen:       [#run(count_of(Piece_Color))]bool;
    castling_right_king:        [#run(count_of(Piece_Color))]bool;
    check:                      [#run(count_of(Piece_Color))]bool;
}

Move :: struct {
    start:          int;
    start_piece:    Piece;
    target:         int;
    target_piece:   Piece;
    flags:          Move_Flag;
}
Move_Flag :: enum u8 {
    None        :: 0;
    En_Passant  :: 1 << 0;
    Push2       :: 1 << 1;
    Castle      :: 1 << 2;
    Check       :: 1 << 3;
}

Victor :: enum {
    White;
    Black;
    Draw;
}

Game_State :: struct {
    board:                  Board;
    drag_in_progress:       bool;
    valid_moves:            [..]Move;
    drag_start:             int;
    drag_end:               int;
    hide_move_piece:        bool;
    victor:                 Victor;
    moves:                  [..]Move;
    move_animation:         Animation;
    move_world_position:    Vector2;
    movelist_scroll:        int;
}

Game_Mode :: enum {
    Init;
    Start_Turn;
    Select_Move;
    Perform_Move;
    End_Turn;
    Game_Over;
}

Animation_Frame :: struct {
    timestamp: s32;
    position:  Vector2;
    target:    *Vector2;
}
Animation :: struct {
    active: bool;
    t:      float;
    frames: [2]Animation_Frame;
}

Color :: Vector4;
Vector2s32 :: struct {
    x, y: s32;
    #place x;
    component: [2] s32 = ---;
}
operator + :: (a: Vector2s32, b: Vector2s32) -> Vector2s32 {
    return .{ a.x + b.x, a.y + b.y };
}
operator - :: (a: Vector2s32, b: Vector2s32) -> Vector2s32 {
    return .{ a.x - b.x, a.y - b.y };
}
operator == :: inline (a: Vector2s32, b: Vector2s32) -> bool {
    return (a.x == b.x) && (a.y == b.y);
}

UI_Item :: struct {
    type:       enum { Rect; Text; Piece; };
    layer:      int = 1;
    union {
        rect:   Draw_Rect;
        text:   Draw_Text;
        piece:  Draw_Piece;
    }
};
Draw_Rect :: struct {
    position:   Vector2;
    size:       Vector2;
    color:      Color;
}
Draw_Text :: struct {
    position:   Vector2;
    text:       string;
    color:      Color = .{ 1, 1, 1, 1 };
}
Draw_Piece :: struct {
    position:   Vector2;
    piece:      Piece;
}

// Window
window: Window_Type;
window_size := Vector2s32.{ 1920, 1080 };
last_time: float64;
now: float64;
elapsed_time: float64;
delta_time: float;
// Renderer
texture_pieces: Simp.Texture;
font_main: *Simp.Dynamic_Font;
font_data_main := #run(load_file_or_exit("./assets/fonts/OpenSans-BoldItalic.ttf"));
font_size_main: s32;
image_data_pieces := #run(load_file_or_exit("./assets/art/pieces.png"));
zoom := 48.0;
button_theme: GetRect.Button_Theme;
text_input_theme: GetRect.Text_Input_Theme;
number_input_theme: GetRect.Number_Input_Theme;
draw_calls: [..]UI_Item;
board_cell_size: float;
board_offset: Vector2;
// Audio
sound_data_place_piece := #run(load_file_or_exit("./assets/sounds/chipLay1.wav"));
sound_place_piece: Sound_Player.Sound_Data;
sound_data_take_piece  := #run(load_file_or_exit("./assets/sounds/chipsHandle6.wav"));
sound_take_piece: Sound_Player.Sound_Data;
// Game
mode: Game_Mode;
game: Game_State;
seed: u64;
controllers: [#run(count_of(Piece_Color))]Controller;
any_input_was_used: bool;
mouse_window_position: Vector2;
mouse_world_position: Vector2;
mouse_board_position: Vector2s32;

#run {
    #if DEBUG == false && OS == .WINDOWS {
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

    audio_success := Sound_Player.sound_player_init(.{ update_from_a_thread = true });
    assert(audio_success);

    sound_place_piece = load_audio_data("chipLay1", sound_data_place_piece);
    sound_take_piece  = load_audio_data("chipsHandle6", sound_data_take_piece);

    Hash_Table.table_add(*SYMBOL_TO_PIECE, #char ".", .None);
    Hash_Table.table_add(*SYMBOL_TO_PIECE, #char "K", .King);
    Hash_Table.table_add(*SYMBOL_TO_PIECE, #char "P", .Pawn);
    Hash_Table.table_add(*SYMBOL_TO_PIECE, #char "N", .Knight);
    Hash_Table.table_add(*SYMBOL_TO_PIECE, #char "B", .Bishop);
    Hash_Table.table_add(*SYMBOL_TO_PIECE, #char "R", .Rook);
    Hash_Table.table_add(*SYMBOL_TO_PIECE, #char "Q", .Queen);

    GetRect.ui_init();

    init_fonts();
    success := Simp.texture_load_from_memory(*texture_pieces, xx image_data_pieces);
    assert(success);

    quit := false;
    while !quit {
        Input.update_window_events();
        any_input_was_used = false;

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
            GetRect.getrect_handle_event(event);

            if event.type == {
                case .QUIT; {
                    quit = true;
                }
                case .KEYBOARD; {
                    if event.key_pressed == 0 {
                        any_input_was_used = true;
                    }

                    if event.key_pressed && event.key_code == .ESCAPE {
                        quit = true;
                    }
                    if event.key_code == .F4 && event.alt_pressed {
                        quit = true;
                    }
                }
            }
        }

        frame_begin();
            frame_update();
        frame_end();
    }
}

frame_begin :: () {
    while true {
        if elapsed_time >= TICK_PERIOD {
            elapsed_time -= TICK_PERIOD;
            break;
        }

        now = seconds_since_init();
        if last_time{
            delta_time = cast(float) (now - last_time);
        }
        last_time = now;

        elapsed_time += delta_time;
        sleep_milliseconds(2);
    }

    Sound_Player.update();

    Simp.clear_render_target(BOARD_COLOR_BLACK.x - 0.25, BOARD_COLOR_BLACK.y - 0.25, BOARD_COLOR_BLACK.z - 0.25, BOARD_COLOR_BLACK.w);

    {
        GetRect.ui_per_frame_update(window, window_size.x, window_size.y, now);

        proc := GetRect.default_theme_procs[GetRect.Default_Themes.Freddie_Freeloader];
        my_theme := proc();
        my_theme.font = font_main;
        GetRect.set_default_theme(my_theme);

        button_theme = my_theme.button_theme;
        button_theme.font = font_main;
        button_theme.enable_variable_frame_thickness = true;

        text_input_theme = my_theme.text_input_theme;
        text_input_theme.font = font_main;

        // number_input_theme = my_theme.button_theme;
        // number_input_theme.font = font_main;
    }
}

frame_update :: () {
    mouse_window_position = get_mouse_window_position();
    mouse_world_position = window_to_world_position(mouse_window_position);
    mouse_board_position = world_to_board_position(mouse_world_position);
    mouse_board_index, mouse_piece, mouse_in_bounds := board_position_to_index(*game.board, mouse_board_position);

    board_cell_size = zoom * 2.5;
    board_offset = .{
        window_size.x / 2.0 - board_cell_size * 8 / 2,
        window_size.y / 2.0 - board_cell_size * 8 / 2,
    };

    king_index: int;
    game.board.check[game.board.active_color], king_index = is_in_check(*game.board,, allocator = temp);

    if #complete mode == {
        case .Init; {
            game.board = fen_to_board(FEN);
            controllers[Piece_Color.Black] = .CPU;
            #if DEBUG {
                random_seed(*context.random_state, seed);
            }
            mode = .Start_Turn;
        }
        case .Start_Turn; {
            game.hide_move_piece = false;

            {
                // free_all(_mem.play.turn_arena.allocator)
                game.valid_moves = generate_valid_moves(*game.board/* ,, allocator = turn_allocator */); // FIXME: allocator
                for < move, i : game.valid_moves {
                    if move_leads_to_check(move) {
                        array_unordered_remove_by_index(*game.valid_moves, i);
                    }
                }
            }

            if game.valid_moves.count == 0 {
                if game.board.check[game.board.active_color] {
                    game.victor = ifx(game.board.active_color == .White) then .Black else .White;
                } else {
                    game.victor = .Draw; // Stalemate
                }
                mode = .Game_Over;
            } else {
                if game.board.halfmoves_without_capture >= MAX_HALFMOVES_WITHOUT_CAPTURE {
                    game.victor = .Draw; // 50-Move Rule
                    mode = .Game_Over;
                } else {
                    mode = .Select_Move;
                }
            }
        }
        case .Select_Move; {
            #if DEBUG {
                if mouse_button_is_released(.SPACEBAR) {
                    game.board.active_color = ifx(game.board.active_color == .White) then .Black else .White;
                    mode = .Start_Turn;
                }
            }

            move: *Move;
            if controllers[game.board.active_color] == .CPU {
                move = cpu_best_move(*game.board, game.valid_moves);
                assert(move != null, "Not best move found for CPU?!");
            } else {
                #if DEBUG {
                    if mouse_button_is_pressed(.MOUSE_BUTTON_RIGHT) {
                        piece_start := board_index_to_piece(*game.board, mouse_board_index);
                        if piece_start != null {
                            piece_start.type = .None;
                        }
                    }
                }
                if mouse_button_is_pressed(.MOUSE_BUTTON_LEFT) {
                    piece_start := board_index_to_piece(*game.board, mouse_board_index);
                    if piece_start != null && piece_start.type != .None && piece_start.color == game.board.active_color {
                        game.drag_in_progress = true;
                        game.drag_start = mouse_board_index;
                    }
                }
                if mouse_button_is_released(.MOUSE_BUTTON_LEFT) {
                    game.drag_in_progress = false;
                    game.drag_end = mouse_board_index;

                    for valid_move : game.valid_moves {
                        if valid_move.start == game.drag_start && valid_move.target == game.drag_end {
                            move = *valid_move;
                            break;
                        }
                    }
                    game.drag_start = -1;
                    game.drag_end = -1;

                    if move == null {
                        // TODO: play error sound or something
                    }
                }
            }

            if move != null {
                array_add(*game.moves, move.*);
                game.hide_move_piece = true;

                if controllers[game.board.active_color] == .CPU && ANIMATION_ENABLE {
                    mode = .Perform_Move;
                } else {
                    mode = .End_Turn;
                }
            }
        }
        case .Perform_Move; {
            move := game.moves[game.moves.count - 1];

            if game.move_animation.active == false {
                start_board_position := grid_index_to_position(move.start, BOARD_SIZE_V2);
                start_world_position := board_offset + Vector2.{ cast(float) start_board_position.x, cast(float) start_board_position.y } * board_cell_size;
                target_board_position := grid_index_to_position(move.target, BOARD_SIZE_V2);
                target_world_position := board_offset + Vector2.{ cast(float) target_board_position.x, cast(float) target_board_position.y } * board_cell_size;
                game.move_world_position = start_world_position;

                // FIXME: turn allocator
                game.move_animation = Animation.{ active = true, t = 0 };
                game.move_animation.frames[0] = .{ 0, start_world_position,  *game.move_world_position };
                game.move_animation.frames[1] = .{ 1, target_world_position, *game.move_world_position };
            }

            {
                push_piece_world_position(game.move_world_position, game.board.pieces[move.start], 2);
                push_cell_highlight(move.start, .{ 0.9, 0.9, 0.01, 0.6 });
                push_cell_highlight(move.target, .{ 0.9, 0.9, 0.01, 0.6 });

                if game.move_animation.t == 1 {
                    game.move_animation.active = false;
                    mode = .End_Turn;
                }
            }
        }
        case .End_Turn; {
            move := game.moves[game.moves.count - 1];

            // Castling
            if move.start_piece.type == .Rook {
                if move.start == 0 { game.board.castling_right_queen[Piece_Color.Black] = false; }
                if move.start == 7 { game.board.castling_right_king[Piece_Color.Black] = false; }
                if move.start == 56 { game.board.castling_right_queen[Piece_Color.White] = false; }
                if move.start == 63 { game.board.castling_right_king[Piece_Color.White] = false; }
            } else if move.start_piece.type == .King {
                if move.start_piece.color == .White {
                    game.board.castling_right_queen[Piece_Color.White] = false;
                    game.board.castling_right_king[Piece_Color.White] = false;
                } else {
                    game.board.castling_right_queen[Piece_Color.Black] = false;
                    game.board.castling_right_king[Piece_Color.Black] = false;
                }
            }

            captured_a_piece := board_make_move(*game.board, move);
            if captured_a_piece {
                game.board.halfmoves_without_capture = 0;
                play_sound(*sound_take_piece);
            } else {
                game.board.halfmoves_without_capture += 1;
                play_sound(*sound_place_piece);
            }

            if game.board.active_color == .Black {
                game.board.fullmove_count += 1;
            }
            game.board.active_color = ifx(game.board.active_color == .White) then .Black else .White;
            mode = .Start_Turn;
        }
        case .Game_Over; {
            box_height :: 280.0;
            text_width :: 10.0;
            push_rect(.{ 0, (window_size.y / 2) - (box_height / 2) }, .{ cast(float) window_size.x, box_height }, .{ 0, 0, 0, 0.8 }, layer = 10);
            push_text(.{ 0, cast(float) (window_size.y / 2) - 60 }, "Checkmate", layer = 11);
            victor_text: string;
            if game.victor == {
                case .White; { victor_text = "- Victory: white -"; }
                case .Black; { victor_text = "- Victory: black -"; }
                case .Draw;  { victor_text = "-      Draw      -"; }
            }
            push_text(.{ 0, cast(float) (window_size.y / 2) + 30 }, victor_text, layer = 11);

            if any_input_was_used {
                mode = .Init;
            }
        }
    }

    #if DEBUG {
        time := seconds_since_init();
        {
            theta := cast(float) fmod_cycling(time * 3, TAU);
            color: Vector4 = ---;
            color.x = clamp(cos(theta) * 0.5 + 0.5, 0, 1);
            color.y = 1;
            color.z = clamp(sin(theta) * -0.5 + 0.5, 0, 1);
            color.w = 1;

            push_text(.{ 50, cast(float) window_size.y - 75 }, tprint("zoom: % | mode: %", zoom, mode), color);
        }
        push_text(.{ 10, font_size_main * 1.2 * 1 }, tprint("active_color: %", game.board.active_color));
        push_text(.{ 10, font_size_main * 1.2 * 2 }, tprint("mouse_board_position: %", mouse_board_position));
        push_text(.{ 10, font_size_main * 1.2 * 3 }, tprint("controllers: %", controllers));

        if draw_button(.{ 10, font_size_main * 1.2 * 10 }, 2, "Trigger Game over") { mode = .Game_Over; }
        if draw_button(.{ 10, font_size_main * 1.2 * 12 }, 2, tprint("White: %", controllers[Piece_Color.White])) { controllers[Piece_Color.White] = ifx(controllers[Piece_Color.White] == .Player) then .CPU else .Player; }
        if draw_button(.{ 10, font_size_main * 1.2 * 14 }, 2, tprint("Black: %", controllers[Piece_Color.Black])) { controllers[Piece_Color.Black] = ifx(controllers[Piece_Color.Black] == .Player) then .CPU else .Player; }
        GetRect.number_input(.{ 10, font_size_main * 1.2 * 16, font_size_main * 10.0, font_size_main * 2.0 }, tprint("%", seed), *seed, 0, 10000, *number_input_theme);
        // GetRect.text_input(.{ 10, font_size_main * 1.2 * 16, 200, 50 }, "", *text_input_theme);
    }

    for y : 0 .. BOARD_SIZE-1 {
        for x : 0 .. BOARD_SIZE-1 {
            color := BOARD_COLOR_WHITE;
            if (y + x) % 2 == 1 {
                color = BOARD_COLOR_BLACK;
            }
            push_rect(.{ board_offset.x + (x * board_cell_size), board_offset.y + (y * board_cell_size) }, .{ board_cell_size, board_cell_size }, color);
            #if DEBUG {
                push_text(.{ board_offset.x + (x * board_cell_size) + (board_cell_size * 0.1), board_offset.y + (y * board_cell_size) + (board_cell_size * 0.2) }, tprint("%,%", x, y), .{ 0, 0, 0, 0.5 }, 2);
                push_text(.{ board_offset.x + (x * board_cell_size) + (board_cell_size * 0.8), board_offset.y + (y * board_cell_size) + (board_cell_size * 0.2) }, tprint("%", grid_position_to_index(.{ xx x, xx y }, BOARD_SIZE)), .{ 0, 0, 0, 0.6 }, 2);
            }
        }
    }

    #if DEBUG {
        for y : 0 .. BOARD_SIZE-1 {
            push_text(board_offset + .{ -0.4,             xx y + 0.4 } * board_cell_size, tprint("%", digit_to_rune(xx(BOARD_SIZE - y))));
            push_text(board_offset + .{ BOARD_SIZE + 0.2, xx y + 0.4 } * board_cell_size, tprint("%", digit_to_rune(xx(BOARD_SIZE - y))));
        }
        for x : 0 .. BOARD_SIZE-1 {
            push_text(board_offset + .{ xx(x) + 0.4,             -0.35 } * board_cell_size, tprint("%", digit_to_rank(xx(x))));
            push_text(board_offset + .{ xx(x) + 0.4, BOARD_SIZE + 0.15 } * board_cell_size, tprint("%", digit_to_rank(xx(x))));
        }
    }

    for piece, board_index : game.board.pieces {
        board_position := grid_index_to_position(board_index, BOARD_SIZE_V2);
        if game.drag_in_progress && game.drag_start == board_index {
            continue;
        }
        if game.hide_move_piece {
            last_move := game.moves[game.moves.count-1];
            if (last_move.target == board_index || last_move.start == board_index) {
                continue;
            }
        }

        push_piece_grid_position(board_position, piece, 1);
    }

    highlighted_piece_index := -1;
    piece_start := board_index_to_piece(*game.board, game.drag_start);
    if game.drag_in_progress && piece_start != null {
        highlighted_piece_index = game.drag_start;
    }
    if highlighted_piece_index != -1 {
        push_cell_highlight(highlighted_piece_index, .{ 0.9, 0.9, 0.01, 0.6 });
        for move : game.valid_moves {
            if move.start == highlighted_piece_index {
                push_cell_highlight(move.target, .{ 0.9, 0.3, 0.3, 0.6 });
                if move.flags & .Check {
                    push_cell_highlight(move.target, .{ 1, 0, 0, 1 });
                }
            }
        }
    }
    #if DEBUG {
        if game.board.en_passant != -1 {
            push_cell_highlight(game.board.en_passant, .{ 0.01, 0.1, 0.9, 0.6 });
        }
    }
    if game.drag_in_progress {
        push_piece_world_position(mouse_world_position + board_offset - (.{ board_cell_size, board_cell_size } / 2), board_index_to_piece(*game.board, game.drag_start).*, 2);
    }
    if game.board.check[game.board.active_color] {
        push_cell_highlight(king_index, .{ 0.9, 0.1, 0.1, 0.7 });
    }

    sorted_calls := quick_sort(draw_calls, x => x.layer);
    for item : sorted_calls {
        if #complete item.type == {
            case .Rect;  { draw_rect(item.rect); }
            case .Text;  { draw_text(item.text); }
            case .Piece; { draw_piece(item.piece); }
        }
    }
}

frame_end :: () {
    animation_update();
    array_reset(*draw_calls);
    Simp.swap_buffers(window);
    reset_temporary_storage();
}

init_fonts :: () {
    font_size_main = window_size.y / 42;
    font_main = Simp.get_font_at_size(xx font_data_main, font_size_main);
    assert(font_main != null);
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

push_text :: (position: Vector2, text: string, color: Color = .{ 1, 1, 1, 1 }, layer := 0) {
    array_add(*draw_calls, .{ type = .Text, layer = BASE_LAYER + layer, text = .{ position, text, color } });
}
push_rect :: (position: Vector2, size: Vector2, color: Color, layer := 0) {
    array_add(*draw_calls, .{ type = .Rect, layer = BASE_LAYER + layer, rect = .{ position, size, color } });
}
push_cell_highlight :: (board_index: int, color: Color, layer := 1) {
    board_position := grid_index_to_position(board_index, BOARD_SIZE_V2);
    position := Vector2.{
        board_offset.x + cast(float) board_position.x * board_cell_size,
        board_offset.y + cast(float) board_position.y * board_cell_size,
    };
    push_rect(position, .{ board_cell_size, board_cell_size }, color, layer);
}
push_piece_world_position :: (world_position: Vector2, piece: Piece, layer := 0) {
    array_add(*draw_calls, .{ type = .Piece, layer = BASE_LAYER + layer, piece = .{ world_position, piece } });
}
push_piece_grid_position :: (grid_position: Vector2s32, piece: Piece, layer := 0) {
    x := board_offset.x + board_cell_size * grid_position.x;
    y := board_offset.y + board_cell_size * grid_position.y;
    world_position := Vector2.{ x, y };
    array_add(*draw_calls, .{ type = .Piece, layer = BASE_LAYER + layer, piece = .{ world_position, piece } });
}

draw_text :: (using draw_text: Draw_Text) {
    text_width := Simp.prepare_text(font_main, text);
    Simp.draw_prepared_text(font_main, xx position.x, xx position.y, color);
}
draw_rect :: (using draw_rect: Draw_Rect) {
    Simp.set_shader_for_color(enable_blend = true);
    Simp.immediate_begin();
    Simp.immediate_quad(position.x, position.y, position.x + size.x, position.y + size.y, color);
    Simp.immediate_flush();
}
draw_piece :: (using draw_piece: Draw_Piece) {
    tw := PIECE_TEXTURE_SIZE.x;
    th := PIECE_TEXTURE_SIZE.y;
    tx := cast(float) piece.type * tw;
    ty := cast(float) piece.color * th;
    // log("piece: %, pos: % | size: %,% | tpos: %,% | tsize: %,%", piece, position, w, h, tx, ty, tw, th);

    Simp.set_shader_for_images(*texture_pieces);
    Simp.immediate_begin();
    Simp.immediate_quad(
        .{ position.x + 0,               position.y + 0 },
        .{ position.x + board_cell_size, position.y + 0 },
        .{ position.x + board_cell_size, position.y + board_cell_size },
        .{ position.x + 0,               position.y + board_cell_size },
        .{ 1, 1, 1, 1 },
        .{ tx + 0,  ty + 0 },
        .{ tx + tw, ty + 0 },
        .{ tx + tw, ty + th },
        .{ tx + 0,  ty + th },
    );
    Simp.immediate_flush();
}

draw_button :: (position: Vector2, size: u8, text: string, color := COLOR_WHITE, layer := 0, loc := #caller_location) -> (was_just_pressed: bool) {
    rect := GetRect.get_rect(position.x, position.y, font_size_main * 10.0, font_size_main * 2.0);
    was_just_pressed, state, was_just_released := GetRect.button(rect, text, *button_theme, loc = loc);
    return was_just_released;
}

count_of :: ($E: Type) -> int {
    return type_info(E).values.count;
}

// Source: https://www.chess.com/terms/fen-chess#castling-rights
fen_to_board :: (input: string) -> Board {
    input_parts := split(input, " ",, allocator = temp);
    assert(input_parts.count > 0, "Invalid input.");

    board: Board;
    board.en_passant = -1;

    { // Piece Placement
        ranks := split(input_parts[0], "/",, allocator = temp);
        y: int;
        for rank : ranks {
            x: int;
            for i : 0..rank.count-1 {
                symbol := rank[i];
                board_index := (y * BOARD_SIZE) + x;
                if is_number(symbol) {
                    x += rune_to_digit(symbol);
                } else {
                    board_index := (y * BOARD_SIZE) + x;
                    board.pieces[board_index].color = ifx is_upper(symbol) then .White else .Black;
                    piece_type, found := Hash_Table.table_find(*SYMBOL_TO_PIECE, to_upper(symbol));
                    if found {
                        board.pieces[board_index].type = piece_type;
                    }
                    x += 1;
                }
            }
            y += 1;
        }
    }
    if input_parts.count > 1 { // Active Color
        color_string := input_parts[1];
        board.active_color = ifx(color_string == "w") then .White else .Black;
    }
    if input_parts.count > 2 { // Castling Rights
        castling_string := input_parts[2];
        for i : 0..castling_string.count-1 {
            part := castling_string[i];
            if part == #char "K" { board.castling_right_king [Piece_Color.White] = true; }
            if part == #char "Q" { board.castling_right_queen[Piece_Color.White] = true; }
            if part == #char "k" { board.castling_right_king [Piece_Color.Black] = true; }
            if part == #char "q" { board.castling_right_queen[Piece_Color.Black] = true; }
        }
    }
    if input_parts.count > 3 { // Possible En Passant Targets
        en_passant_string := input_parts[3];
        if en_passant_string.count == 2 {
            rank := cast(s32) rank_to_digit(en_passant_string[0]);
            file := cast(s32) rune_to_digit(en_passant_string[1]) - 1;
            index, piece, found := board_position_to_index(*game.board, .{ rank, (BOARD_SIZE - 1) - file });
            if found {
                board.en_passant = index;
            }
        }
    }
    if input_parts.count > 4 { // Halfmove Clock
        halfmove_string := input_parts[4];
        halfmove, ok := parse_int(*halfmove_string);
        if ok {
            board.halfmoves_without_capture = cast(s32) halfmove;
        }
    }
    if input_parts.count > 5 { // Fullmove Number
        move_string := input_parts[5];
        move, ok := parse_int(*move_string);
        if ok {
            board.fullmove_count = cast(s32) move;
        }
    }
    compute_move_data(*board);
    // log("board: %", board);
    return board;
}

compute_move_data :: (board: *Board) {
    for y : 0 .. BOARD_SIZE-1 {
        for x : 0 .. BOARD_SIZE-1 {
            north := cast(s32) y;
            south := cast(s32) (BOARD_SIZE - 1 - y);
            east := cast(s32) (BOARD_SIZE - 1 - x);
            west := cast(s32) x;

            board_index := grid_position_to_index(.{ cast(s32) x, cast(s32) y }, BOARD_SIZE);

            board.squares_to_edges[board_index] = .[
                /* North */      north,
                /* South */      south,
                /* East */       east,
                /* West */       west,
                /* North_East */ min(north, east),
                /* North_West */ min(north, west),
                /* South_East */ min(south, east),
                /* South_West */ min(south, west),
            ];
        }
    }
}

grid_index_to_position :: (grid_index: int, grid_size: Vector2s32) -> Vector2s32 {
    return .{ cast(s32) (grid_index) % grid_size.x, cast(s32) (grid_index) / grid_size.x };
}
grid_position_is_in_bounds :: (grid_position: Vector2s32, grid_size: Vector2s32) -> bool {
    return grid_position.x >= 0 && grid_position.x < grid_size.x && grid_position.y >= 0 && grid_position.y < grid_size.y;
}
grid_index_is_in_bounds :: (grid_index: int, grid_size: Vector2s32) -> bool {
    return grid_index >= 0 && grid_index < cast(int) (grid_size.x * grid_size.y);
}
grid_position_to_index :: (grid_position: Vector2s32, grid_width: s32) -> int {
    return cast(int) (grid_position.y * grid_width) + grid_position.x;
}

is_upper :: (byte: u8) -> bool {
    return byte >= #char "A" && byte <= #char "Z";
}
is_number :: (byte: u8) -> bool {
    return byte >= #char "0" && byte <= #char "9";
}
rune_to_digit :: (byte: u8) -> u8 {
    return byte - #char "0";
}
digit_to_rune :: (digit: u8) -> string {
    return .{1, *(digit + #char "0") };
}
rank_to_digit :: (value: u8) -> int {
    return (cast(int) value) - #char "a";
}
digit_to_rank :: (digit: u8) -> string {
    return .{1, *(digit + #char "a") };
}

board_position_to_index :: (board: *Board, board_position: Vector2s32) -> (int, *Piece, bool) {
    if grid_position_is_in_bounds(board_position, BOARD_SIZE_V2) == false {
        return -1, null, false;
    }
    index := grid_position_to_index(board_position, BOARD_SIZE);
    return index, *board.pieces[index], true;
}
board_index_to_piece :: (board: *Board, board_index: int) -> *Piece {
    if grid_index_is_in_bounds(board_index, BOARD_SIZE_V2) == false {
        return null;
    }
    return *board.pieces[board_index];
}

generate_valid_moves :: (board: *Board) -> [..]Move {
    color_direction_y := cast(s32) (ifx board.active_color == .Black then 1 else -1);

    valid_moves: [..]Move;
    for piece, board_index : board.pieces {
        start_position := grid_index_to_position(board_index, BOARD_SIZE_V2);

        if piece.color != board.active_color {
            continue;
        }

        if piece.type == {
            case .King; #through;
            case .Bishop; #through;
            case .Rook; #through;
            case .Queen; {
                directions := board.squares_to_edges[board_index];
                for range, direction_raw : directions {
                    direction := cast(Direction) direction_raw;
                    move_range := range;
                    if piece.type == .Rook && (direction == .North_East || direction == .North_West || direction == .South_East || direction == .South_West) {
                        continue;
                    } else if piece.type == .Bishop && (direction == .North || direction == .South || direction == .West || direction == .East) {
                        continue;
                    } else if piece.type == .King {
                        move_range = min(range, 1);
                    }

                    for i : 1 .. move_range {
                        target_index := board_index + (DIRECTION_TO_INDEX[direction] * i);
                        target_piece := *board.pieces[target_index];

                        if target_piece.type != .None && target_piece.color == board.active_color {
                            break;
                        }

                        move := Move.{
                            start        = board_index,
                            start_piece  = piece,
                            target       = target_index,
                            target_piece = target_piece.*,
                            flags        = ifx(target_piece.type == .King) then .Check else .None,
                        };
                        array_add(*valid_moves, move);

                        if target_piece.type != .None && target_piece.color != board.active_color {
                            break;
                        }
                    }
                }

                // TODO: Castling
                // - Your king can not pass through check
                if piece.type == .King {
                    CASTLE_RANGE :: 2;
                    if board.check[piece.color] == false {
                        for king_side: 0..0 {
                            can_castle := board.castling_right_king[piece.color];
                            for x : 1 .. CASTLE_RANGE {
                                target_index, target_piece, target_found := board_position_to_index(board, start_position + .{ xx x, 0 });
                                if target_found == false || target_piece.type != .None {
                                    can_castle = false;
                                    break;
                                }
                            }

                            if can_castle {
                                target_index, target_piece, target_found := board_position_to_index(board, start_position + .{ CASTLE_RANGE, 0 });
                                move := Move.{
                                    start        = board_index,
                                    start_piece  = piece,
                                    target       = target_index,
                                    target_piece = target_piece.*,
                                    flags        = ifx(target_piece.type == .King) then .Check | .Castle else .Castle,
                                };
                                array_add(*valid_moves, move);
                            }
                        }
                        for queen_side: 0..0 {
                            can_castle := board.castling_right_queen[piece.color];
                            for x : 1 .. (CASTLE_RANGE + 1) {
                                target_index, target_piece, target_found := board_position_to_index(board, start_position - .{ xx x, 0 });
                                if target_found == false || target_piece.type != .None {
                                    can_castle = false;
                                    break;
                                }
                            }

                            if can_castle {
                                target_index, target_piece, target_found := board_position_to_index(board, start_position - .{ CASTLE_RANGE, 0 });
                                move := Move.{
                                    start        = board_index,
                                    start_piece  = piece,
                                    target       = target_index,
                                    target_piece = target_piece.*,
                                    flags        = ifx(target_piece.type == .King) then .Check | .Castle else .Castle,
                                };
                                array_add(*valid_moves, move);
                            }
                        }
                    }
                }
            }
            case .Knight; {
                knight_moves :: Vector2s32.[
                    .{ +2, +1 }, .{ +2, -1 },
                    .{ -2, +1 }, .{ -2, -1 },
                    .{ +1, +2 }, .{ -1, +2 },
                    .{ +1, -2 }, .{ -1, -2 },
                ];

                for knight_move : knight_moves {
                    target_index, target_piece, target_found := board_position_to_index(board, start_position + knight_move);
                    if target_found == false {
                        continue;
                    }
                    if target_piece.type != .None && target_piece.color == board.active_color {
                        continue;
                    }

                    move := Move.{
                        start        = board_index,
                        start_piece  = piece,
                        target       = target_index,
                        target_piece = target_piece.*,
                        flags        = ifx(target_piece.type == .King) then .Check else .None,
                    };
                    array_add(*valid_moves, move);
                }
            }
            case .Pawn; {
                for push1: 0..0 {
                    target_index, target_piece, target_found := board_position_to_index(board, start_position + Vector2s32.{ 0, color_direction_y });
                    if target_found == false {
                        break push1;
                    }
                    if target_piece.type != .None {
                        break push1;
                    }

                    move := Move.{
                        start        = board_index,
                        start_piece  = piece,
                        target       = target_index,
                        target_piece = target_piece.*,
                        flags        = ifx (target_piece.type == .King) then .Check else .None,
                    };
                    array_add(*valid_moves, move);
                }

                for push2: 0..0 {
                    PAWN_START_Y :: 1;
                    is_rank_valid := start_position.y == (BOARD_SIZE - 1 - PAWN_START_Y) || start_position.y == PAWN_START_Y;
                    if is_rank_valid == false {
                        break push2;
                    }

                    { // Prevent jumping over pieces
                        target_index, target_piece, target_found := board_position_to_index(board, start_position + .{ 0, 1 * color_direction_y });
                        if target_piece.type != .None {
                            break push2;
                        }
                    }

                    target_index, target_piece, target_found := board_position_to_index(board, start_position + .{ 0, 2 * color_direction_y });
                    if target_found == false {
                        break push2;
                    }
                    if target_piece.type != .None {
                        break push2;
                    }

                    move := Move.{
                        start        = board_index,
                        start_piece  = piece,
                        target       = target_index,
                        target_piece = target_piece.*,
                        flags        = ifx(target_piece.type == .King) then .Check | .Push2 else .Push2
                    };
                    array_add(*valid_moves, move);
                }

                for capture: 0..0 {
                    pawn_capture_moves := Vector2s32.[
                        .{ +1, color_direction_y },
                        .{ -1, color_direction_y },
                    ];
                    for capture_move : pawn_capture_moves {
                        target_index, target_piece, target_found := board_position_to_index(board, start_position + capture_move);
                        if target_found == false {
                            continue;
                        }
                        if target_piece.type == .None || target_piece.color == board.active_color {
                            continue;
                        }

                        move := Move.{
                            start        = board_index,
                            start_piece  = piece,
                            target       = target_index,
                            target_piece = target_piece.*,
                            flags        = ifx(target_piece.type == .King) then .Check else .None,
                        };
                        array_add(*valid_moves, move);
                    }
                }

                for en_passant: 0..0 {
                    pawn_en_passant_moves := Vector2s32.[
                        .{ +1, color_direction_y },
                        .{ -1, color_direction_y },
                    ];
                    for en_passant_move : pawn_en_passant_moves {
                        target_index, target_piece, target_found := board_position_to_index(board, start_position + en_passant_move);
                        if target_found == false {
                            continue;
                        }
                        if board.en_passant != target_index {
                            continue;
                        }

                        move := Move.{
                            start        = board_index,
                            start_piece  = piece,
                            target       = target_index,
                            target_piece = target_piece.*,
                            flags        = ifx(target_piece.type == .King) then .Check | .En_Passant else .En_Passant,
                        };
                        array_add(*valid_moves, move);
                    }
                }
            }
            case .None; {}
        }
    }

    return valid_moves;
}

mouse_button_is_pressed :: (button: Input.Key_Code) -> bool {
    return Input.input_button_states[button] == .DOWN | .START;
}
mouse_button_is_released :: (button: Input.Key_Code) -> bool {
    return Input.input_button_states[button] == .END;
}

get_mouse_window_position :: () -> Vector2 {
    x, y := get_mouse_pointer_position();
    Clamp(*x, 0, window_size.x);
    Clamp(*y, 0, window_size.y);

    return .{ xx x, xx y };
}

board_make_move :: (board: *Board, move: Move) -> (captured_a_piece: bool) {
    captured_a_piece := false;
    piece_start := board_index_to_piece(board, move.start);
    piece_target := board_index_to_piece(board, move.target);

    {
        captured_a_piece = piece_target.type != .None;
        en_passant_direction : Direction = ifx(board.active_color == .White) then .South else .North;
        board.en_passant = -1;

        if move.flags & .En_Passant {
            captured_piece := board_index_to_piece(board, move.target + DIRECTION_TO_INDEX[en_passant_direction]);
            captured_piece.* = .{};
            captured_a_piece = true;
        }
        if move.flags & .Push2 {
            board.en_passant = move.target + DIRECTION_TO_INDEX[en_passant_direction];
        }
    }

    if move.flags & .Castle {
        start_position := grid_index_to_position(move.start, BOARD_SIZE_V2);
        target_position := grid_index_to_position(move.target, BOARD_SIZE_V2);
        king_direction : Direction = ifx(target_position.x - start_position.x > 0) then .East else .West;

        rook_start_offset := ifx(king_direction == .East) then +1 else -2;
        rook_start_piece := board_index_to_piece(board, move.target + rook_start_offset);
        rook_target_offset := ifx(king_direction == .East) then -1 else +1;
        rook_target_piece := board_index_to_piece(board, move.target + rook_target_offset);
        rook_target_piece.* = rook_start_piece.*;
        rook_start_piece.* = .{};
    }

    piece_target.* = piece_start.*;
    piece_start.* = .{};

    target_position := grid_index_to_position(move.target, BOARD_SIZE_V2);
    promotion_rank_y := ifx(board.active_color == .White) then 0 else (BOARD_SIZE - 1);
    if piece_target.type == .Pawn && target_position.y == promotion_rank_y {
        piece_target.type = .Queen;
    }

    return captured_a_piece;
}

print_board :: (board: *Board) -> string {
    builder: String_Builder;
    for piece, i : board.pieces {
        board_position := grid_index_to_position(i, BOARD_SIZE_V2);
        symbol := PIECE_TO_SYMBOL[piece.type];
        if piece.color == .Black {
            symbol = to_lower(symbol);
        }
        if i > 0 && board_position.x % BOARD_SIZE == 0 {
            append(*builder, "\n");
        }
        append(*builder, " ");
        append(*builder, symbol);
        append(*builder, " ");
    }
    return builder_to_string(*builder);
}

window_to_world_position :: (window_position: Vector2) -> Vector2 {
    return .{
        window_position.x - board_offset.x,
        window_position.y - board_offset.y,
    };
}
world_to_board_position :: (world_position: Vector2) -> Vector2s32 {
    return .{
        cast(s32) floor(world_position.x / cast(float) board_cell_size),
        cast(s32) floor(world_position.y / cast(float) board_cell_size),
    };
}

cpu_best_move :: (board: *Board, valid_moves: [..]Move) -> (best_move: *Move) {
    if valid_moves.count < 1 {
        return null;
    }

    best_score := 0;
    best_move: *Move;
    for move : valid_moves {
        score := 0;
        if move.flags & .Check {
            score += 10;
        }
        if move.target_piece.color != board.active_color {
            if move.target_piece.type == {
                case .Queen;            { score += 9; }
                case .Rook;             { score += 5; }
                case .Bishop; #through;
                case .Knight;           { score += 3; }
                case .Pawn;             { score += 3; }
            }
        }
        if score > best_score {
            best_score = score;
            best_move = *move;
        }
    }

    if best_move == null {
        random_move_index := cast(int) random_get_within_range(*context.random_state, 0, cast(float) valid_moves.count);
        best_move = *valid_moves[random_move_index];
    }

    return best_move;
}

is_in_check :: (board: *Board) -> (in_check: bool, king_board_index: int) {
    temp_board := board.*;
    temp_board.active_color = ifx(temp_board.active_color == .White) then .Black else .White;
    opponent_valid_moves := generate_valid_moves(*temp_board);
    for opponent_move : opponent_valid_moves {
        if opponent_move.flags & .Check {
            return true, opponent_move.target;
        }
    }
    return false, -1;
}
move_leads_to_check :: (move: Move) -> bool {
    temp_board : Board = game.board;
    temp_board.active_color = ifx(temp_board.active_color == .White) then .Black else .White;
    board_make_move(*temp_board, move);

    opponent_valid_moves := generate_valid_moves(*temp_board,, allocator = temp);
    for opponent_move : opponent_valid_moves {
        if opponent_move.flags & .Check {
            return true;
        }
    }

    return false;
}

play_sound :: (data: *Sound_Player.Sound_Data, perturb: bool = true, category := Sound_Player.Sound_Category.GENERAL_SFX) -> *Sound_Player.Sound_Stream {
    stream := Sound_Player.make_stream(data, category);

    if perturb {
        stream.user_volume_scale = random_get_within_range(0.5,  1);
        stream.rate_scale        = random_get_within_range(0.75, 1.22);
    }

    Sound_Player.start_playing(stream);
    return stream;
}

// This is a patched version of modules/Sound_Player/load.jai.
// The original is missing the `#import "Wav_File";`, making it impossible to use `load_audio_data` directly (ie: without `load_audio_file`).
load_audio_data :: (name_for_error_reporting: string, data: string) -> Sound_Player.Sound_Data {
    #import "Wav_File";
    using Sound_Player :: #import "Sound_Player";
    result: Sound_Data;

    name := name_for_error_reporting;

    if data.count < 12 {
        log_error("Unable to parse '%' as wav or ogg.\n", name);
        return .{};
    }

    magic0 := get_magic4(data, 0);
    if magic0 == 0x46464952 {
        result.name = copy_string(name);
        result.buffer = data;

        format, samples, success2, extra := get_wav_header(result.buffer);
        if !success2 {
            log_error("Unable to parse '%' as wav.\n", name);
            return result;
        }

        if format.wFormatTag == WAVE_FORMAT_PCM {
            result.type                     = .LINEAR_SAMPLE_ARRAY;
            result.nchannels                = cast(u16) format.nChannels;
            result.nsamples_times_nchannels = samples.count/2;
        } else if format.wFormatTag == WAVE_FORMAT_DVI_ADPCM {
            result.type             = .ADPCM_COMPRESSED;
            result.wSamplesPerBlock = extra.wSamplesPerBlock;
            result.nBlockAlign      = format.nBlockAlign;

            result.nchannels = cast(u16) format.nChannels;
            // The value in the FACT chunk is number of samples by time.
            result.nsamples_times_nchannels = extra.wSamplesAccordingToFactChunk * result.nchannels;
        } else {
            assert(false);
        }

        result.samples       = cast(*s16) samples.data;
        result.sampling_rate = cast(u32) format.nSamplesPerSec;

        result.loaded = true;
    } else if magic0 == 0x5367674f {
        result.name   = copy_string(name);
        result.buffer = data;
        result.type   = .OGG_COMPRESSED;

        result.loaded = true;
    } else {
        // Unsupported format.
        log_error("Unknown or unsupported format in %\n", name);
    }

    return result;
}

animation_update :: () {
    for _ : 0..0 { // In a real project, we would have multiple animations, but here we keep it simple
        animation := *game.move_animation;
        if animation.active {
            start := animation.frames[0].position;
            end := animation.frames[1].position;
            animation.frames[0].target.* = start + ((end - start) * animation.t);
            animation.t = clamp(animation.t + delta_time, 0, 1);
        }
    }
}
