const std = @import("std");
const fs = std.fs;
const heap = std.heap;
const io = std.io;
const mem = std.mem;
const args = @import("args.zig");
const Board = @import("Board.zig");
const term = @import("term.zig");

pub var buf_writer = io.bufferedWriter(io.getStdOut().writer());
pub const writer = buf_writer.writer();
var buffer: [mem.page_size]u8 = undefined;
var fba = heap.FixedBufferAllocator.init(&buffer);
pub const allocator = fba.allocator();

pub fn main() !void {
    const tty = try fs.openFileAbsolute("/dev/tty", .{ .mode = .read_write });
    defer tty.close();
    // const reader = io.getStdIn().reader();
    const reader = tty.reader();

    var board = try Board.init(try args.parse());
    defer board.deinit();

    try term.init(tty.handle);
    try buf_writer.flush();
    defer {
        term.deinit(tty.handle) catch {};
        buf_writer.flush() catch {};
    }

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
            'r' =>  {
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
            else => {}
        }
        if (success) {
            try board.addRandom();
            try board.draw();
            try board.save();
        }
    }
}
