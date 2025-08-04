const std = @import("std");
const linux = std.os.linux;
const process = std.process;
const args = @import("args.zig");
const Board = @import("Board.zig");
const term = @import("term.zig");

pub var buffered_writer = std.io.bufferedWriter(std.io.getStdOut().writer());
pub const writer = buffered_writer.writer();
var alloc_buffer: [4096]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&alloc_buffer);
pub const allocator = fba.allocator();
var board: *Board = undefined;

fn sigHandler(sig: c_int) callconv(.C) void {
    _ = sig;
    board.save() catch {};
    board.deinit();
    term.deinit() catch {};
    process.exit(0);
}

pub fn main() !void {
    const reader = std.io.getStdIn().reader();
    board = try Board.init(args.parse());
    defer board.deinit();
    try term.init();
    defer term.deinit() catch {};

    const sa = linux.Sigaction{
        .handler = .{ .handler = sigHandler },
        .mask = linux.filled_sigset,
        .flags = linux.SA.RESTART,
    };
    _ = linux.sigaction(linux.SIG.HUP, &sa, null);
    _ = linux.sigaction(linux.SIG.INT, &sa, null);
    _ = linux.sigaction(linux.SIG.TERM, &sa, null);

    try board.draw();
    while (true) {
        var success = false;
        switch (try reader.readByte()) {
            'w', 'k', 65 => success = board.moveUp(),
            'a', 'h', 68 => success = board.moveLeft(),
            's', 'j', 66 => success = board.moveDown(),
            'd', 'l', 67 => success = board.moveRight(),
            'q' => {
                try board.print("QUIT? (y/n)");
                try buffered_writer.flush();
                if (try reader.readByte() == 'y') {
                    break;
                }
                try board.draw();
            },
            'r' => {
                try board.print("RESTART? (y/n)");
                try buffered_writer.flush();
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
        }
    }
    try board.save();
}
