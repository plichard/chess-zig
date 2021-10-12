pub const KnightMoves = struct {
    pub const dx = [8]i32{-2, -1, 1, 2, 2, 1, -1, -2};
    pub const dy = [8]i32{1, 2, 2, 1, -1, -2, -2, -1};
};  

pub const KingMoves = struct {
    pub const dx = [8]i32{0, 1, 1, 1, 0, -1, -1, -1};
    pub const dy = [8]i32{1, 1, 0, -1, -1, -1, 0, 1};
};


pub fn sum_for_all_positions(f: fn(i32, i32) u32) u32 {
    var sum : u32 = 0;
    inline for ([_]i32{0,1,2,3,4,5,6,7}) |y| {
        inline for ([_]i32{0,1,2,3,4,5,6,7}) |x| {
            sum += f(x, y);
        }
    }
    return sum;
}

pub fn number_of_moves_for_pawns() u32 {
    return sum_for_all_positions(number_of_moves_for_pawn_at_position);
}

fn number_of_moves_for_pawn_at_position(x: i32, y: i32) u32 {
    var sum : u32 = 0;
    if (y == 1) {
        sum += 1;   // move 2
    }

    if (y < 7 and y > 0) {      // pawns cannot be on y == 0
        if (x > 0) {sum += 1;}  // capture left
        if (x < 7) {sum += 1;}  // capture right
        sum += 1;               // move 1
    }
    return sum;
}

pub fn position_is_valid(x: i32, y: i32) bool {
    return x >= 0 and x <=7 and y >= 0 and y <= 7;
}

pub fn number_of_moves_for_knights() u32 {
    return sum_for_all_positions(number_of_moves_for_knights_at_square);
}

pub fn number_of_moves_for_king_at_square(x: i32, y: i32) u32 {
    const dx = KingMoves.dx;
    const dy = KingMoves.dy;

    var sum : u32 = 0;
    inline for ([_]usize{0,1,2,3,4,5,6,7}) |i| {
        if (position_is_valid(x + dx[i], y + dy[i])) {
            sum += 1;
        }
    }
    return sum;
}

pub fn number_of_moves_for_kings() u32 {
    return sum_for_all_positions(number_of_moves_for_king_at_square);
}

fn number_of_moves_for_knights_at_square(x: i32, y: i32) u32 {
    const dx = KnightMoves.dx;
    const dy = KnightMoves.dy;

    var sum : u32 = 0;
    inline for ([_]usize{0,1,2,3,4,5,6,7}) |i| {
        if (position_is_valid(x + dx[i], y + dy[i])) {
            sum += 1;
        }
    }
    return sum;
}

pub fn number_of_moves_for_main_pieces() u32 {
    // for rooks, bishops
    return 64*(7+7);
}

// computed with the const functions, but there was too much computation
const MOVES_MAIN_PIECES = 896;
const MOVES_KINGS = 420;
const MOVES_KNIGHTS = 336;
const MOVES_PAWNS = 140;
pub const MAX_MOVES = 
    MOVES_MAIN_PIECES +   // bishops
    MOVES_MAIN_PIECES +   // rooks
    MOVES_MAIN_PIECES*2 + // queens
    MOVES_PAWNS*2 +
    MOVES_KNIGHTS + 
    MOVES_KINGS;