const std = @import("std");
const eql = std.mem.eql;
const allocator = @import("main.zig").allocator;

const version = "0.1.2";
const usage =
    \\Usage: {s} [options]
    \\
    \\Options:
    \\-s, --size [n]    | Set the board size to n
    \\-h, --help        │ Print this help message
    \\-v, --version     | Print version information
    \\
    \\Commands:
    \\  ↑    w    k     | Classic movements
    \\ ←↓→  asd  hjl    |
    \\ q                | Quit the game
    \\ r                | Restart the game
    \\ u                | Undo one action
    \\
;

fn die(status: u8, comptime fmt: []const u8, args: anytype) noreturn {
    const stderr = std.io.getStdErr().writer();
    stderr.print(fmt, args) catch {};
    std.os.exit(status);
}

pub fn parse() !usize {
    var size: usize = 4;
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    const progname = args.next().?;
    while (args.next()) |arg| {
        if (eql(u8, arg, "-h") or eql(u8, arg, "--help")) {
            die(0, usage, .{progname});
        } else if (eql(u8, arg, "-v") or eql(u8, arg, "--version")) {
            die(0, "{s} {s}\n", .{ progname, version });
        } else if (eql(u8, arg, "-s") or eql(u8, arg, "--size")) {
            const val = args.next() orelse {
                die(1, "{s}: no size provided\n", .{progname});
            };
            size = std.fmt.parseUnsigned(usize, val, 10) catch |err| {
                die(1, "{s}: {}\n", .{ progname, err });
            };
            if (size <= 1) {
                die(1, "{s}: size is too small\n", .{progname});
            }
            if (size > 16) {
                die(1, "{s}: size is too big\n", .{progname});
            }
        } else {
            try die(1, "{s}: unknown option {s}\n" ++ usage, .{ progname, arg, progname });
        }
    }
    return size;
}
