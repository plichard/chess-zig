const std = @import("std");

const board = @import("board.zig");
const utils = @import("utils.zig");

const n = board.sum_for_all_positions(board.number_of_moves_for_pawns);

fn take_some_slice(slice: []u32) void {
    slice[1] = 42;
}

pub fn main() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});
    var b = board.Board.create_classic_game(std.heap.c_allocator);
    defer b.deinit();

    b.precompute_all_moves();

    std.log.debug("sizeof cells: {} bytes", .{@sizeOf(@TypeOf(b.cells))});
    std.log.debug(
        \\ size of:
        \\ PieceMove:     {} bytes ({} bits)
        \\ Action:        {} bytes ({} bits)
        \\ Board:         {} bytes
    , .{ @sizeOf(board.PieceMove), @bitSizeOf(board.PieceMove), @sizeOf(board.Action), @bitSizeOf(board.Action), @sizeOf(board.Board) });

    std.log.debug(
        \\ 
        \\ MAIN PIECES: {}
        \\ KINGS      : {}
        \\ KNIGHTS    : {}
        \\ PAWNS      : {}
    , .{ utils.number_of_moves_for_main_pieces(), utils.number_of_moves_for_kings(), utils.number_of_moves_for_knights(), utils.number_of_moves_for_pawns() });

    var slice = [_]u32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    take_some_slice(slice[4..]);
    std.log.debug("slice[5] = {}", .{slice[5]});

    std.log.debug("MAX_MOVES = {}", .{utils.MAX_MOVES});

    var move_buffer: [1024]board.PieceMove = undefined;

    var count : i32 = 0;

    var outer : i32 = 0;
        while (outer < 10000000) : (outer += 1)  {
        var i: i32 = 0;
        while (i < 100) : (i +=1) {
            var c = b.collect_all_moves(move_buffer[0..]);

            // std.log.debug("moves: {}", .{moves.items.len});
            if (c == 0) {
                break;
            }
            b.push_move(move_buffer[0]);
            count += 1;
            // _ = b.pop_move();
        }

        // _ = b.pop_move();

        while (i > 0):(i -= 1) {

            // _ = b.collect_all_moves(move_buffer[0..]);

            // std.log.debug("moves: {}", .{moves.items.len});
            _ = b.pop_move();
        }
    }

    std.log.err("Made {} moves", .{count});
}
