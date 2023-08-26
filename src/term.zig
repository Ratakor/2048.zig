const os = @import("std").os;
const main = @import("main.zig");
const writer = main.writer;
const csi = "\x1b[";
var orig: os.termios = undefined;

pub const Color = enum(u8) {
    black = 30,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    default,
    bright_black = 90,
    bright_red,
    bright_green,
    bright_yellow,
    bright_blue,
    bright_magenta,
    bright_cyan,
    bright_white,
};

fn enterAlt() !void {
    try writer.writeAll(csi ++ "s"); // Save cursor position.
    try writer.writeAll(csi ++ "?47h"); // Save screen.
    try writer.writeAll(csi ++ "?1049h"); // Enable alternative buffer.
}

fn leaveAlt() !void {
    try writer.writeAll(csi ++ "?1049l"); // Disable alternative buffer.
    try writer.writeAll(csi ++ "?47l"); // Restore screen.
    try writer.writeAll(csi ++ "u"); // Restore cursor position.
}

pub fn init() !void {
    const handle = os.STDIN_FILENO;
    orig = try os.tcgetattr(handle);
    errdefer deinit() catch {};

    var raw = orig;
    raw.lflag &= ~@as(
        os.system.tcflag_t,
        os.system.ECHO | os.system.ICANON,
    );
    try os.tcsetattr(handle, .FLUSH, raw);

    try hideCursor();
    try enterAlt();
    try clear();
    try resetColor();
    try main.buffered_writer.flush();
}

pub fn deinit() !void {
    const handle = os.STDIN_FILENO;
    try os.tcsetattr(handle, .FLUSH, orig);
    try clear();
    try leaveAlt();
    try showCursor();
    try resetColor();
    try main.buffered_writer.flush();
}

pub inline fn clear() !void {
    try writer.writeAll(csi ++ "2J");
}

pub inline fn hideCursor() !void {
    try writer.writeAll(csi ++ "?25l");
}

pub inline fn showCursor() !void {
    try writer.writeAll(csi ++ "?25h");
}

pub inline fn cursorUp() !void {
    try writer.writeAll(csi ++ "A");
}

pub inline fn cursorTopLeft() !void {
    try writer.writeAll(csi ++ "H");
}

pub inline fn setFg(fg: Color) !void {
    try writer.print(csi ++ "{d}m", .{@intFromEnum(fg)});
}

pub inline fn setBg(bg: Color) !void {
    try writer.print(csi ++ "{d}m", .{@intFromEnum(bg) + 10});
}

pub inline fn resetColor() !void {
    try writer.writeAll(csi ++ "m");
}
