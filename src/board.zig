const std = @import("std");
const utils = @import("utils.zig");
const position_is_valid = utils.position_is_valid;

pub const Move = packed struct {
    score: i32,             // 32 bits
    action: Action,         // 12 bits
    action_type: ActionType,// 2 bits = 46 bits -> 6 bytes (48 bits)

    pub fn move(from: Position, to: Position) Move {
        const action = Action {.move=ActionMove{.from = from, .to = to}};
        return .{
            .score = 0,
            .action = action,
            .action_type = ActionType.Move
        };
    }
};

pub const PieceType = enum(u3) {
    Pawn,
    Rook,
    Knight,
    Bishop,
    Queen,
    King
};

const PieceIndex = u4; // each player has at most 16 = 2^4 pieces

pub const ActionMove = packed struct {
    from: Position,     // to undo the move we need the initial position
    to: Position        // to execute the move we need the target
};

pub const ActionType = enum(u2) {
    Move,
    Capture,
    Promote
};

// promotion will be added automaticaly when a pawn reaches the corresponding squares
pub const ActionPromote = packed struct {
    promoted_index: PieceIndex,
    old_type: PieceType,
    new_type: PieceType
};

pub const ActionCapture = packed struct {
    from: Position,                 // we need the starting position information for undoing moves
    captured_index: PieceIndex,     // we don't need color information here, the taking piece gives it already
};

pub const Action = packed union {
    move: ActionMove,
    capture: ActionCapture,
    promote: ActionPromote,
};

pub const Position = packed struct {
    x: u3,
    y: u3,

    fn init(x: i32, y: i32) Position {
        return .{.x = @intCast(u3, x), .y = @intCast(u3, y)};
    }
};

pub const Color = enum(u1) {
    White,
    Black
};

pub const Piece = struct {
    t: PieceType,           
    position: Position,     
    color: Color,
    index: PieceIndex       
};

pub const Board = struct {
    white_pieces: [16]?Piece = [1]?Piece{null}**16,
    black_pieces: [16]?Piece = [1]?Piece{null}**16,

    used_white_pieces: usize = 0,
    used_black_pieces: usize = 0,

    moves_for_white_pawns: [8][8][]Position = undefined,
    moves_for_black_pawns: [8][8][]Position = undefined,

    moves_for_rooks: [8][8][4][]Position = undefined, // 4 directions, for skipping moves when encountering a piece
    moves_for_knights: [8][8][]Position = undefined,
    moves_for_bishops: [8][8][4][]Position = undefined,
    moves_for_queens: [8][8][8][]Position = undefined,
    moves_for_kings: [8][8][]Position = undefined,

    all_moves_buffer: [utils.MAX_MOVES]Position = undefined,

    cells: [8][8]?Piece = [1][8]?Piece{[1]?Piece{null}**8}**8,
    move_stack: std.ArrayList(Move),

    pub fn init_empty(allocator: *std.mem.Allocator) Board {
        return Board {
            .move_stack = std.ArrayList(Move).init(allocator)
        };
    }

    pub fn create_classic_game(allocator: *std.mem.Allocator) Board {
        var board = init_empty(allocator);
        var x : i32 = 0;
        while (x < 8) : (x += 1) {
            board.add_new_piece(.Pawn, .White, x, 1);
            board.add_new_piece(.Pawn, .Black, x, 6);
        }
        return board;
    }

    pub fn deinit(self: *Board) void {
        self.move_stack.deinit();
    }

    pub fn cell_is_empty(self: Board, x: i32, y: i32) bool {
        return self.cells[@intCast(usize, x)][@intCast(usize, y)] == null;
    }

    pub fn cell_is_enemy(self: Board, x: i32, y: i32, my_color: Color) bool {
        return 
            !self.cell_is_empty(x,y) and 
            self.cells[@intCast(usize, x)][@intCast(usize, y)].?.color != my_color;
    }

    pub fn piece_at(self: Board, x: i32, y: i32) Piece {
        return self.cells[@intCast(usize, x)][@intCast(usize, y)];
    }

    pub fn add_new_piece(self: *Board, piece_type: PieceType, color: Color, x: i32, y: i32) void {
        if (color == .White) {
            const piece = Piece{
                .t = piece_type,
                .position = Position.init(x,y),
                .color = color,
                .index = @intCast(u4, self.used_white_pieces)
            };
            self.white_pieces[self.used_white_pieces] = piece;
            self.cells[piece.position.x][piece.position.y] = piece;
            self.used_white_pieces += 1;
        }
        else if (color == .Black) {
            const piece = Piece{
                .t = piece_type,
                .position = Position.init(x,y),
                .color = color,
                .index = @intCast(u4, self.used_black_pieces)
            };
            self.black_pieces[self.used_black_pieces] = piece;
            self.cells[piece.position.x][piece.position.y] = piece;
            self.used_black_pieces += 1;
        }
    }

    pub fn collect_all_moves(self: *Board, moves: *std.ArrayList(Move)) !void {
        for (self.white_pieces) |piece| {
            if (piece != null) {
                switch (piece.?.t) {
                    .Pawn => {
                        try self.collect_white_pawn_moves(piece.?, moves);
                    },
                    else => {}
                }
            }
        }
    }

    pub fn collect_white_pawn_moves(self: *Board, pawn: Piece, moves: *std.ArrayList(Move)) !void {
        const x = @intCast(i32, pawn.position.x);
        const y = @intCast(i32, pawn.position.y);

        if (y == 1) {
            if (self.cell_is_empty(x, y + 1)) {
                if (self.cell_is_empty(x, y + 2)) {
                    try moves.append(Move.move(pawn.position, Position.init(x, y + 2)));
                }
            }
        }

        if (y > 0 and y < 7) {
            if (self.cell_is_empty(x, y + 1)) {
                try moves.append(Move.move(pawn.position, Position.init(x, y + 1)));
            }
            if (x > 0 and self.cell_is_enemy(x - 1, y + 1, .White)) {
                try moves.append(Move.move(pawn.position, Position.init(x - 1, y + 1)));
            }

            if (x < 7 and self.cell_is_enemy(x + 1, y + 1, .White)) {
                try moves.append(Move.move(pawn.position, Position.init(x + 1, y + 1)));
            }
        }
    }

    pub fn collect_black_pawn_moves(self: *Board, pawn: Piece, moves: *std.ArrayList(Move)) !void {
        const x = @intCast(i32, pawn.position.x);
        const y = @intCast(i32, pawn.position.y);

        if (y == 6) {
            if (self.cell_is_empty(x, y - 1)) {
                if (self.cell_is_empty(x, y - 2)) {
                    try moves.append(Move.move(pawn.position, Position.init(x, y - 2)));
                }
            }
        }

        if (y > 0 and y < 7) {
            if (self.cell_is_empty(x, y - 1)) {
                try moves.append(Move.move(pawn.position, Position.init(x, y - 1)));
            }

            if (x > 0 and self.cell_is_enemy(x - 1, y - 1, .Black)) {
                try moves.append(Move.move(pawn.position, Position.init(x - 1, y - 1)));
            }

            if (x < 7 and self.cell_is_enemy(x + 1, y - 1, .Black)) {
                try moves.append(Move.move(pawn.position, Position.init(x + 1, y - 1)));
            }
        }
    }

    pub fn precompute_all_moves(self: *Board) void {
        var moves_buffer = self.precompute_pawn_moves(self.all_moves_buffer[0..]);
        moves_buffer = self.precompute_pawn_moves(moves_buffer);
        moves_buffer = self.precompute_rook_moves(moves_buffer);
        moves_buffer = self.precompute_king_moves(moves_buffer);
        std.log.debug("moves_buffer.len = {}", .{moves_buffer.len});
    }

    fn precompute_pawn_moves(self: *Board, in_moves_buffer: []Position) []Position {
        var moves_buffer = in_moves_buffer;
        // white pawns
        for ([_]i32{0,1,2,3,4,5,6,7}) |y| {
            for ([_]i32{0,1,2,3,4,5,6,7}) |x| {
                var offset : usize = 0;
                if (y == 1) {
                    moves_buffer[offset] = Position.init(x, 3);
                    offset += 1;
                }

                if (y < 7 and y > 0) {      // pawns cannot be on y == 0
                    if (x > 0) {
                        moves_buffer[offset] = Position.init(x  - 1, y + 1);
                        offset += 1;
                    }
                    if (x < 7) {
                        moves_buffer[offset] = Position.init(x  + 1, y + 1);
                        offset += 1;
                    }
                    moves_buffer[offset] = Position.init(x, y + 1);
                    offset += 1;
                }

                self.moves_for_white_pawns[@intCast(usize, x)][@intCast(usize, y)] = moves_buffer[0..offset];
                moves_buffer = moves_buffer[offset..];
            }
        }

        // black pawns
        for ([_]i32{0,1,2,3,4,5,6,7}) |y| {
            for ([_]i32{0,1,2,3,4,5,6,7}) |x| {
                var offset : usize = 0;
                if (y == 6) {
                    moves_buffer[offset] = Position.init(x, 4);
                    offset += 1;
                }

                if (y < 7 and y > 0) {      // pawns cannot be on y == 0
                    if (x > 0) {
                        moves_buffer[offset] = Position.init(x  - 1, y - 1);
                        offset += 1;
                    }
                    if (x < 7) {
                        moves_buffer[offset] = Position.init(x  + 1, y - 1);
                        offset += 1;
                    }
                    moves_buffer[offset] = Position.init(x, y - 1);
                    offset += 1;
                }

                self.moves_for_black_pawns[@intCast(usize, x)][@intCast(usize, y)] = moves_buffer[0..offset];
                moves_buffer = moves_buffer[offset..];
            }
        }

        return moves_buffer;
    }

    fn precompute_rook_moves(self: *Board, in_moves_buffer: []Position)  []Position {
        var moves_buffer = in_moves_buffer;
        
        for ([_]i32{0,1,2,3,4,5,6,7}) |y| {
            for ([_]i32{0,1,2,3,4,5,6,7}) |x| {
                {   // go left
                    var offset: usize = 0;
                    var tx = x - 1;
                    while (tx >= 0) : (tx -= 1) {
                        moves_buffer[offset] = Position.init(tx, y);
                        offset += 1;
                    }
                    self.moves_for_rooks[@intCast(usize, x)][@intCast(usize, y)][0] = moves_buffer[0..offset];
                    moves_buffer = moves_buffer[offset..];
                }
                {   // go up
                    var offset: usize = 0;
                    var ty = y + 1;
                    while (ty <= 7) : (ty += 1) {
                        moves_buffer[offset] = Position.init(x, ty);
                        offset += 1;
                    }
                    self.moves_for_rooks[@intCast(usize, x)][@intCast(usize, y)][1] = moves_buffer[0..offset];
                    moves_buffer = moves_buffer[offset..];
                }
                {   // go right
                    var offset: usize = 0;
                    var tx = x + 1;
                    while (tx <= 7) : (tx += 1) {
                        moves_buffer[offset] = Position.init(tx, y);
                        offset += 1;
                    }
                    self.moves_for_rooks[@intCast(usize, x)][@intCast(usize, y)][2] = moves_buffer[0..offset];
                    moves_buffer = moves_buffer[offset..];
                }
                {   // go down
                    var offset: usize = 0;
                    var ty = y - 1;
                    while (ty >= 0) : (ty -= 1) {
                        moves_buffer[offset] = Position.init(x, ty);
                        offset += 1;
                    }
                    self.moves_for_rooks[@intCast(usize, x)][@intCast(usize, y)][3] = moves_buffer[0..offset];
                    moves_buffer = moves_buffer[offset..];
                }
            }
        }

        return moves_buffer;
    }

    fn precompute_king_moves(self: *Board, in_moves_buffer: []Position)  []Position {
        var moves_buffer = in_moves_buffer;

        const dx = utils.KingMoves.dx;
        const dy = utils.KingMoves.dy;
        
        for ([_]i32{0,1,2,3,4,5,6,7}) |y| {
            for ([_]i32{0,1,2,3,4,5,6,7}) |x| {
                var offset: usize = 0;
                for ([_]usize{0,1,2,3,4,5,6,7}) |k| {
                    if (position_is_valid(x + dx[k], y + dy[k])) {
                        moves_buffer[offset] = Position.init(x + dx[k], y + dy[k]);
                        offset += 1;
                    }
                }
                self.moves_for_kings[@intCast(usize, x)][@intCast(usize, y)] = moves_buffer[0..offset];
                moves_buffer = moves_buffer[offset..];
            }
        }
        return moves_buffer;
    }
};