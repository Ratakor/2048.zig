const std = @import("std");
const args = @import("args.zig");
const Board = @import("Board.zig");
const term = @import("term.zig");

pub var buf_writer = std.io.bufferedWriter(std.io.getStdOut().writer());
pub const writer = buf_writer.writer();
var buffer: [std.mem.page_size]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
pub const allocator = fba.allocator();

pub fn main() !void {
    const reader = std.io.getStdIn().reader();
    var board = try Board.init(try args.parse());
    defer board.deinit();
    try term.init();
    defer term.deinit() catch {};

    try board.draw();
    while (true) {
        var success = false;
        switch (try reader.readByte()) {
            'w', 'k', 65 => success = board.moveUp(),
            'a', 'h', 68 => success = board.moveLeft(),
            's', 'j', 66 => success = board.moveDown(),
            'd', 'l', 67 => success = board.moveRight(),
            'q', '' => {
                try board.print("QUIT? (y/n)");
                try buf_writer.flush();
                if (try reader.readByte() == 'y') {
                    break;
                }
                try board.draw();
            },
            'r' => {
                try board.print("RESTART? (y/n)");
                try buf_writer.flush();
                if (try reader.readByte() == 'y') {
                    board.reset();
                    try board.addRandom();
                    try board.addRandom();
                }
                try board.draw();
            },
            'u' => {
                board.undo();
                try board.draw();
            },
            else => {},
        }
        if (success) {
            try board.addRandom();
            try board.draw();
            try board.save();
        }
    }
}
