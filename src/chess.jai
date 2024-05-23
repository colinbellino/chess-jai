Simp       :: #import "Simp";
Input      :: #import "Input";
File       :: #import "File";
Hash_Table :: #import "Hash_Table";
GetRect    :: #import "GetRect";
#import "Math";
#import "stb_image_write";
#import "Window_Creation";
#import "Basic";
#import "System";
#import "String";

FEN :: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

MAX_HALFMOVES_WITHOUT_CAPTURE :: 100;
BOARD_SIZE :: 8;
BOARD_SIZE_V2 :: Vector2s32.{ BOARD_SIZE, BOARD_SIZE };
BOARD_COLOR_WHITE :: #run(hex_to_color(0xd5ddedff));
BOARD_COLOR_BLACK :: #run(hex_to_color(0x5a738fff));
PIECE_TEXTURE_SIZE :: Vector2.{ 7, 2 };
// BOARD_CELL_SIZE     :: 8;
// PIECE_TEXTURE_SIZE  :: Vector2s32.{ 213, 213 };
// PIECE_SIZE          :: Vector2.{ 8, 8 };
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
    /* .South_West */ +BOARD_SIZE - 1,
    /* .South_East */ +BOARD_SIZE + 1,
];
TICK_PERIOD : float64 : 1.0 / 60.0;
WANTED_MSAA :: 8;
COLOR_WHITE :: Color.{ 1, 1, 1, 1 };
COLOR_BLACK :: Color.{ 0, 0, 0, 1 };
#placeholder ANIMATION_ENABLE;
#placeholder DEBUG;

// Directions :: bit_set[Direction]
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
// Piece_Types :: bit_set[Piece_Type]
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
// Move_Flags :: bit_set[Move_Flag]
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

Game :: struct {
    board:                  Board;
    drag_in_progress:       bool;
    valid_moves:            [..]Move;
    drag_start:             int;
    drag_end:               int;
    hide_move_piece:        bool;
    victor:                 Victor;
    moves:                  [..]Move;
    // move_animation:         *e.Animation;
    move_world_position:    Vector2;
    movelist_scroll:        int;
}

Play_Mode :: enum {
    Init;
    Start_Turn;
    Select_Move;
    Perform_Move;
    End_Turn;
    Game_Over;
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

// Window
window: Window_Type;
window_size := Vector2s32.{ 1920, 1080 };
last_time: float64;
now: float64;
elapsed_time: float64;
dt: float;
// Renderer
texture_pieces: Simp.Texture;
my_font: *Simp.Dynamic_Font;
font_data := #run(load_file_or_exit("./assets/fonts/OpenSans-BoldItalic.ttf"));
image_data := #run(load_file_or_exit("./assets/art/pieces.png"));
zoom := 48.0;
button_theme: GetRect.Button_Theme;
// Play_State
mode: Play_Mode;
// turn_arena: tools.Named_Virtual_Arena,
// board_input: cstring,
// rand: rand.Rand,
// seed: u64,
controllers: [#run(count_of(Piece_Color))]Controller;
board_cell_size: float;
board_offset: Vector2;
game: Game;
any_input_was_used: bool;
mouse_window_position: Vector2;
mouse_world_position: Vector2;
mouse_board_position: Vector2s32;

// #run {
//     #if OS == .WINDOWS {
//         WR :: #import "Windows_Resources";
//         WR.disable_runtime_console();
//     }
// }

main :: () {
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();
        Windows.timeBeginPeriod(1);
    }

    Hash_Table.table_add(*SYMBOL_TO_PIECE, #char ".", .None);
    Hash_Table.table_add(*SYMBOL_TO_PIECE, #char "K", .King);
    Hash_Table.table_add(*SYMBOL_TO_PIECE, #char "P", .Pawn);
    Hash_Table.table_add(*SYMBOL_TO_PIECE, #char "N", .Knight);
    Hash_Table.table_add(*SYMBOL_TO_PIECE, #char "B", .Bishop);
    Hash_Table.table_add(*SYMBOL_TO_PIECE, #char "R", .Rook);
    Hash_Table.table_add(*SYMBOL_TO_PIECE, #char "Q", .Queen);

    window = create_window(window_size.x, window_size.y, "Chess", wanted_msaa = WANTED_MSAA);
    msaa := Simp.prepare_window(window, wanted_msaa = WANTED_MSAA);
    window_size.x, window_size.y = Simp.get_render_dimensions(window);

    Simp.set_render_target(window, .LEFT_HANDED);

    GetRect.ui_init();

    init_fonts();
    success := Simp.texture_load_from_memory(*texture_pieces, xx image_data);
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
            dt = cast(float) (now - last_time);
        }
        last_time = now;

        elapsed_time += dt;
        sleep_milliseconds(2);
    }

    Simp.clear_render_target(BOARD_COLOR_BLACK.x - 0.25, BOARD_COLOR_BLACK.y - 0.25, BOARD_COLOR_BLACK.z - 0.25, BOARD_COLOR_BLACK.w);

    {
        GetRect.ui_per_frame_update(window, window_size.x, window_size.y, now);

        proc := GetRect.default_theme_procs[GetRect.Default_Themes.Freddie_Freeloader];
        my_theme := proc();
        my_theme.font = my_font;
        GetRect.set_default_theme(my_theme);

        button_theme = my_theme.button_theme;
        button_theme.font = my_font;
        button_theme.enable_variable_frame_thickness = true;
    }
}

frame_update :: () {
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

    mouse_window_position = get_mouse_window_position();
    mouse_world_position = window_to_world_position(mouse_window_position);
    mouse_board_position = world_to_board_position(mouse_world_position);
    mouse_board_index, mouse_piece, mouse_in_bounds := board_position_to_index(*game.board, mouse_board_position);

    board_cell_size = zoom * 2.5;
    board_offset = .{
        window_size.x / 2.0 - board_cell_size * 8 / 2,
        window_size.y / 2.0 - board_cell_size * 8 / 2,
    };

    if #complete mode == {
        case .Init; {
            game.board = fen_to_board(FEN);
            // controllers[Piece_Color.Black] = .CPU; // FIXME:
            //     rand.init(&_mem.rand, _mem.seed);
            //     play_mode_transition(.Start_Turn)
            mode = .Start_Turn;
        }
        case .Start_Turn; {
            game.hide_move_piece = false;

            {
                // free_all(_mem.play.turn_arena.allocator)
                game.valid_moves = generate_valid_moves(*game.board/* ,, allocator = turn_allocator */); // FIXME: allocator
                // #reverse for &move, i in _mem.play.valid_moves {
                //     if move_leads_to_check(move) {
                //         ordered_remove(&_mem.play.valid_moves, i)
                //     }
                // }
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
                // move = cpu_best_move(board, _mem.play.valid_moves);
            } else {
                if mouse_button_is_pressed(.MOUSE_BUTTON_LEFT) {
                    log("drag_start: %", mouse_board_index);
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
                    log("drag_end: % -> %", mouse_board_position, move.*);

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
                // e.audio_play_sound(_mem.asset_sound_take_piece);
            } else {
                game.board.halfmoves_without_capture += 1;
                // e.audio_play_sound(_mem.asset_sound_place_piece);
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
            // ui_rect(window_to_ui_position({ 1, (window_size.y / 2) - (box_height / 2) }), window_to_ui_position({ window_size.x - 2, box_height }), { 0, 0, 0, 0.8 }, layer = 1);
            draw_button(.{ 0, cast(float) (window_size.y / 2) - 60 }, "Checkmate", size = 8, layer = 1);
            // draw_button(.{ (window_size.x / 2) - (text_width / 2) + 3, cast(float) (window_size.y / 2) - 60 }, "Checkmate", size = 8, layer = 1);
            victor_text: string;
            if game.victor == {
                case .White; { victor_text = "- Victory: white -"; }
                case .Black; { victor_text = "- Victory: black -"; }
                case .Draw;  { victor_text = "-      Draw      -"; }
            }
            draw_button(.{ 0, cast(float) (window_size.y / 2) + 30 }, victor_text, size = 4, layer = 1);
            // draw_button(.{ (window_size.x / 2) - (text_width / 2), cast(float) (window_size.y / 2) + 30 }, victor_text, size = 4, layer = 1);

            if any_input_was_used {
                // _mem.debug_force_transition = .Title;
                // FIXME: restart game
                log("restart");
            }
        }
    }

    Simp.set_shader_for_color();

    time := seconds_since_init();

    {
        theta := cast(float) fmod_cycling(time * 3, TAU);
        color: Vector4 = ---;
        color.x = clamp(cos(theta) * 0.5 + 0.5, 0, 1);
        color.y = 1;
        color.z = clamp(sin(theta) * -0.5 + 0.5, 0, 1);
        color.w = 1;

        draw_text(.{ 50, cast(float) window_size.y - 75 }, tprint("zoom: % | mode: %", zoom, mode), color);
    }
    // draw_text(.{ 50, 10 }, tprint("mouse_window_position: % | mouse_world_position: % | mouse_board_position: %", mouse_window_position, mouse_world_position, mouse_board_position));
    draw_text(.{ 10, 30 }, tprint("active_color: %", game.board.active_color));
    draw_text(.{ 10, 50 }, tprint("mouse_board_position: %", mouse_board_position));
    draw_text(.{ 10, 80 }, tprint("controllers: %", controllers));

    for y : 0 .. BOARD_SIZE-1 {
        for x : 0 .. BOARD_SIZE-1 {
            color := BOARD_COLOR_WHITE;
            if (y + x) % 2 == 1 {
                color = BOARD_COLOR_BLACK;
            }
            draw_rect(.{ board_offset.x + (x * board_cell_size), board_offset.y + (y * board_cell_size) }, .{ board_cell_size, board_cell_size }, color);
            #if DEBUG {
                draw_text(.{ board_offset.x + (x * board_cell_size) + 10, board_offset.y + (y * board_cell_size) + (board_cell_size * 0.2) }, tprint("%,%", x, y), .{ 0, 0, 0, 0.5 });
                draw_text(.{ board_offset.x + (x * board_cell_size) + (board_cell_size * 0.7), board_offset.y + (y * board_cell_size) + (board_cell_size * 0.2) }, tprint("%", grid_position_to_index(.{ xx x, xx y }, BOARD_SIZE)), .{ 0, 0, 0, 0.5 });
            }
        }
    }

    for piece, board_index : game.board.pieces {
        board_position := grid_index_to_position(board_index, BOARD_SIZE_V2);
        draw_piece(board_position, piece);
    }
}

frame_end :: () {
    Simp.swap_buffers(window);
    reset_temporary_storage();
}

init_fonts :: () {
    pixel_height := 20;
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

draw_piece :: (position: Vector2s32, piece: Piece) {
    tw := 1.0 / PIECE_TEXTURE_SIZE.x;
    th := 1.0 / PIECE_TEXTURE_SIZE.y;
    tx := cast(float) piece.type * tw;
    ty := cast(float) piece.color * th;
    x := board_offset.x + board_cell_size * position.x;
    y := board_offset.y + board_cell_size * position.y;
    w := board_cell_size;
    h := board_cell_size;
    // log("piece: %, pos: % | size: %,% | tpos: %,% | tsize: %,%", piece, position, w, h, tx, ty, tw, th);

    Simp.set_shader_for_images(*texture_pieces);
    Simp.immediate_begin();
    Simp.immediate_quad(.{ x + 0, y + 0 }, .{ x + w, y + 0 }, .{ x + w, y + h }, .{ x + 0, y + h }, .{ 1, 1, 1, 1 }, .{ tx + 0, ty + 0 }, .{ tx + tw, ty + 0 }, .{ tx + tw, ty + th }, .{ tx + 0, ty + th });
    Simp.immediate_flush();
}
draw_text :: (position: Vector2, text: string, color: Color = .{ 1, 1, 1, 1 }) {
    text_width := Simp.prepare_text(my_font, text);
    Simp.draw_prepared_text(my_font, xx position.x, xx position.y, color);
}
draw_button :: (position: Vector2, text: string, color := COLOR_WHITE, size: u8, layer := 0, loc := #caller_location) {
    // FIXME: use layer so we don't draw below the board
    k := window_size.y * 0.1;
    rect := GetRect.get_rect(position.x, position.y, 4*k, k);
    pressed := GetRect.button(rect, text, *button_theme, loc = loc);
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
rank_to_digit :: (value: u8) -> int {
    return (cast(int) value) - #char "a";
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
            // case .King, .Bishop, .Rook, .Queen: {
            //     directions := board.squares_to_edges[board_index]
            //     for value, direction in directions {
            //         move_range := value
            //         if piece.type == .Rook && direction in (Directions { .North_East, .North_West, .South_East, .South_West }) {
            //             continue
            //         } else if piece.type == .Bishop && direction in (Directions { .North, .South, .West, .East }) {
            //             continue
            //         } else if piece.type == .King {
            //             move_range = min(value, 1)
            //         }

            //         for i in 1 ..= move_range {
            //             target_index := board_index + DIRECTION_TO_INDEX[direction] * int(i)
            //             target_piece := &board.pieces[target_index]

            //             if target_piece.type != .None && target_piece.color == board.active_color {
            //                 break
            //             }

            //             move := Move {
            //                 start        = board_index,
            //                 start_piece  = piece,
            //                 target       = target_index,
            //                 target_piece = target_piece^,
            //                 flags        = { target_piece.type == .King ? .Check : .None }
            //             }
            //             append(&valid_moves, move)

            //             if target_piece.type != .None && target_piece.color != board.active_color {
            //                 break
            //             }
            //         }
            //     }

            //     // TODO: Castling
            //     // - Your king can not pass through check
            //     if piece.type == .King {
            //         CASTLE_RANGE :: 2
            //         if board.check[piece.color] == false {
            //             king_side: {
            //                 can_castle := board.castling_right_king[piece.color]
            //                 for x in 1 ..= CASTLE_RANGE {
            //                     target_index, target_piece, target_found := board_position_to_index(board, start_position + { i32(x), 0 })
            //                     if target_found == false || target_piece.type != .None {
            //                         can_castle = false
            //                         break
            //                     }
            //                 }

            //                 if can_castle {
            //                     target_index, target_piece, target_found := board_position_to_index(board, start_position + { CASTLE_RANGE, 0 })
            //                     move := Move {
            //                         start        = board_index,
            //                         start_piece  = piece,
            //                         target       = target_index,
            //                         target_piece = target_piece^,
            //                         flags        = { .Castle, target_piece.type == .King ? .Check : .None }
            //                     }
            //                     append(&valid_moves, move)
            //                 }
            //             }
            //             queen_side: {
            //                 can_castle := board.castling_right_queen[piece.color]
            //                 for x in 1 ..= (CASTLE_RANGE + 1) {
            //                     target_index, target_piece, target_found := board_position_to_index(board, start_position - { i32(x), 0 })
            //                     if target_found == false || target_piece.type != .None {
            //                         can_castle = false
            //                         break
            //                     }
            //                 }

            //                 if can_castle {
            //                     target_index, target_piece, target_found := board_position_to_index(board, start_position - { CASTLE_RANGE, 0 })
            //                     move := Move {
            //                         start        = board_index,
            //                         start_piece  = piece,
            //                         target       = target_index,
            //                         target_piece = target_piece^,
            //                         flags        = { .Castle, target_piece.type == .King ? .Check : .None }
            //                     }
            //                     append(&valid_moves, move)
            //                 }
            //             }
            //         }
            //     }
            // }
            // case .Knight: {
            //     knight_moves := [?]Vector2s32 {
            //         { +2, +1 }, { +2, -1 },
            //         { -2, +1 }, { -2, -1 },
            //         { +1, +2 }, { -1, +2 },
            //         { +1, -2 }, { -1, -2 },
            //     }

            //     for move in knight_moves {
            //         target_index, target_piece, target_found := board_position_to_index(board, start_position + move)
            //         if target_found == false {
            //             continue
            //         }
            //         if target_piece.type != .None && target_piece.color == board.active_color {
            //             continue
            //         }

            //         move := Move {
            //             start        = board_index,
            //             start_piece  = piece,
            //             target       = target_index,
            //             target_piece = target_piece^,
            //             flags        = { target_piece.type == .King ? .Check : .None }
            //         }
            //         append(&valid_moves, move)
            //     }
            // }
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

    log("print_board: \n%", print_board(board,, allocator = temp));

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
