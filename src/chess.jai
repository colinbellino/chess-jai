Simp       :: #import "Simp";
Input      :: #import "Input";
File       :: #import "File";
Hash_Table :: #import "Hash_Table";
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
PIECE_TEXTURE_SIZE :: Vector2s32.{ 7, 2 };
// BOARD_CELL_SIZE     :: 8;
// PIECE_TEXTURE_SIZE  :: Vector2s32.{ 213, 213 };
// PIECE_SIZE          :: Vector2.{ 8, 8 };
// PIECE_TO_SYMBOL := [Piece_Type]rune {
//     .None   = '.',
//     .King   = 'K',
//     .Pawn   = 'P',
//     .Knight = 'N',
//     .Bishop = 'B',
//     .Rook   = 'R',
//     .Queen  = 'Q',
// }
SYMBOL_TO_PIECE: Hash_Table.Table(s64, Piece_Type);
// SYMBOL_TO_PIECE := map[rune]Piece_Type {
//     '.' = .None,
//     'K' = .King,
//     'P' = .Pawn,
//     'N' = .Knight,
//     'B' = .Bishop,
//     'R' = .Rook,
//     'Q' = .Queen,
// }
// DIRECTION_TO_INDEX := [Direction]int {
//     .North      = -BOARD_SIZE,
//     .South      = +BOARD_SIZE,
//     .East       = +1,
//     .West       = -1,
//     .North_East = -BOARD_SIZE + 1,
//     .North_West = -BOARD_SIZE - 1,
//     .South_West = +BOARD_SIZE - 1,
//     .South_East = +BOARD_SIZE + 1,
// }
TICK_PERIOD : float64 : 1.0 / 60.0;
WANTED_MSAA :: 8;

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
    // flags:          Move_Flags;
}
// Move_Flags :: bit_set[Move_Flag]
// Move_Flag :: enum {
//     None,
//     En_Passant,
//     Push2,
//     Castle,
//     Check,
// }

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

// Window
window: Window_Type;
window_size := Vector2s32.{ 1920, 1080 };
last_time: float64;
elapsed_time: float64;
dt: float;
// Renderer
texture_pieces: Simp.Texture;
my_font: *Simp.Dynamic_Font;
font_data := #run(load_file_or_exit("./assets/fonts/OpenSans-BoldItalic.ttf"));
image_data := #run(load_file_or_exit("./assets/art/pieces.png"));
zoom := 48.0;
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
                    if event.key_code == .F4 && event.alt_pressed {
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
    board_cell_size = zoom * 2.5;
    board_offset = .{
        window_size.x / 2.0 - board_cell_size * 8 / 2,
        window_size.y / 2.0 - board_cell_size * 8 / 2,
    };

    if mode == {
        case .Init; {
            game.board = fen_to_board(FEN);
            controllers[Piece_Color.Black] = .CPU;
            //     rand.init(&_mem.rand, _mem.seed);
            //     play_mode_transition(.Start_Turn)
            mode = .Start_Turn;
        }
    }
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

    for y : 0 .. BOARD_SIZE-1 {
        for x : 0 .. BOARD_SIZE-1 {
            color := BOARD_COLOR_WHITE;
            if (y + x) % 2 == 1 {
                color = BOARD_COLOR_BLACK;
            }
            draw_rect(.{ board_offset.x + (x * board_cell_size), board_offset.y + (y * board_cell_size) }, .{ board_cell_size, board_cell_size }, color);
        }
    }

    for piece, board_index : game.board.pieces {
        board_position := grid_index_to_position(board_index, BOARD_SIZE_V2);
        draw_piece(board_position, piece);
    }

    // draw_piece(.{ 0, 0 }, .{ .Black, .King });
    // draw_piece(.{ 1, 1 }, .{ .Black, .Pawn });
    // draw_piece(.{ 7, 7 }, .{ .White, .Knight });
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

count_of :: ($E: Type) -> int {
    return type_info(E).values.count;
}

// FIXME:
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
