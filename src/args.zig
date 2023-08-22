const std = @import("std");
const eql = std.mem.eql;
const exit = std.os.exit;
const allocator = @import("main.zig").allocator;
const version = "0.1";
var progname: [:0]const u8 = undefined;

fn usage(writer: anytype) !void {
    try writer.print(
        \\Usage: {s} [options]
        \\
        \\Options:
        \\-s|--size [n]    | Set the board size to n
        \\-h|--help        │ Print this help message
        \\-v|--version     | Print version information
        \\
        \\Commands:
        \\  ↑    w    k    | Classic movements
        \\ ←↓→  asd  hjl   |
        \\ q               | Quit the game
        \\ r               | Restart the game
        \\ u               | Undo one action
        \\
    , .{progname});
}

pub fn parse() !usize {
    var size: usize = 4;
    const stderr = std.io.getStdErr().writer();
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    progname = args.next().?;
    while (args.next()) |arg| {
        if (eql(u8, arg, "-h") or eql(u8, arg, "--help")) {
            try usage(stderr);
            exit(0);
        } else if (eql(u8, arg, "-v") or eql(u8, arg, "--version")) {
            try stderr.print("{s} {s}\n", .{progname, version});
            exit(0);
        } else if (eql(u8, arg, "-s") or eql(u8, arg, "--size")) {
            const val = args.next() orelse {
                try stderr.writeAll("Error: no size\n");
                exit(1);
            };
            size = std.fmt.parseUnsigned(usize, val, 10) catch |err| {
                try stderr.print("Error: {}\n", .{err});
                exit(1);
            };
            if (size <= 1) {
                try stderr.writeAll("Error: size too small\n");
                exit(1);
            }
            if (size > 16) {
                try stderr.writeAll("Error: size too big\n");
                exit(1);
            }
        } else {
            try stderr.print("Error: unknown option {s}\n", .{arg});
            try usage(stderr);
            exit(1);
        }
    }
    return size;
}
