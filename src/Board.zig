const std = @import("std");
const fmt = std.fmt;
const io = std.io;
const posix = std.posix;
const main = @import("main.zig");
const term = @import("term.zig");

const DefaultPrng = std.Random.DefaultPrng;
const allocator = main.allocator;
const writer = main.writer;
const CELL_SIZE = 7;
const cwd = std.fs.cwd();
var rnd: DefaultPrng = undefined;

pub const Board = @This();

cells: [][]u8,
size: usize,
highscore: u64,
score: u64,
turns: usize,
prev: *Board,
tmp: *Board,
savefile: []u8,
win: bool,

pub fn addRandom(self: *Board) !void {
    var len: usize = 0;
    var empty_cells = try allocator.alloc(*u8, self.size * self.size);
    defer allocator.free(empty_cells);

    for (self.cells) |row| {
        for (row) |*cell| {
            if (cell.* == 0) {
                empty_cells[len] = cell;
                len += 1;
            }
        }
    }

    if (len > 0) {
        const r = @mod(rnd.random().int(usize), len);
        empty_cells[r].* = if (rnd.random().int(u2) == 3) 2 else 1;
    }
}

fn createBoard(size: usize) ![][]u8 {
    const board = try allocator.alloc([]u8, size);
    for (board) |*row| {
        row.* = try allocator.alloc(u8, size);
        @memset(row.*, 0);
    }
    return board;
}

fn destroyBoard(board: [][]u8) void {
    for (board) |row| {
        allocator.free(row);
    }
    allocator.free(board);
}

pub fn init(size: usize) !*Board {
    rnd = DefaultPrng.init(@intCast(std.time.microTimestamp()));
    var board = try allocator.create(Board);
    board.cells = try createBoard(size);
    board.size = size;
    board.highscore = 0;
    board.score = 0;
    board.turns = 0;
    board.prev = try allocator.create(Board);
    board.tmp = try allocator.create(Board);
    board.prev.cells = try createBoard(size);
    board.tmp.cells = try createBoard(size);
    if (!try board.load()) {
        try board.addRandom();
        try board.addRandom();
    }
    board.win = gameWon(board.cells);
    boardCopy(board.prev, board);
    return board;
}

pub fn deinit(self: *Board) void {
    destroyBoard(self.cells);
    destroyBoard(self.prev.cells);
    destroyBoard(self.tmp.cells);
    allocator.destroy(self.prev);
    allocator.destroy(self.tmp);
    allocator.free(self.savefile);
}

pub fn reset(self: *Board) void {
    for (self.cells) |row| {
        @memset(row, 0);
    }
    self.score = 0;
    self.turns = 0;
    self.win = false;
}

fn readNextVal(comptime T: type, reader: anytype, fixed_buffer_stream: anytype) !T {
    var fbs = fixed_buffer_stream;
    try reader.streamUntilDelimiter(fbs.writer(), '\n', fbs.buffer.len);
    const output = fbs.getWritten();
    fbs.reset();
    return try fmt.parseInt(T, output, 10);
}

fn load(self: *Board) !bool {
    var buf: [4096]u8 = undefined;
    var path: []u8 = undefined;
    if (posix.getenv("XDG_DATA_HOME")) |xdg_data| {
        path = try fmt.bufPrint(buf[0..], "{s}/2048/", .{xdg_data});
    } else if (posix.getenv("HOME")) |home| {
        path = try fmt.bufPrint(buf[0..], "{s}/.local/share/2048/", .{home});
    } else {
        unreachable; // TODO: windows
    }
    try cwd.makePath(path);
    const len = path.len + (try fmt.bufPrint(buf[path.len..], "{d}", .{self.size})).len;
    self.savefile = try allocator.dupe(u8, buf[0..len]);

    const f = cwd.openFile(self.savefile, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => |e| return e,
    };
    defer f.close();
    errdefer cwd.deleteFile(self.savefile) catch {};

    var br = io.bufferedReader(f.reader());
    const br_reader = br.reader();

    var nbuf: [32]u8 = undefined;
    const fbs = io.fixedBufferStream(&nbuf);
    self.highscore = try readNextVal(u64, br_reader, fbs);
    self.score = try readNextVal(u64, br_reader, fbs);
    self.turns = try readNextVal(usize, br_reader, fbs);

    for (0..self.size) |x| {
        for (0..self.size) |y| {
            self.cells[x][y] = try br_reader.readByte();
        }
    }

    if (self.turns == 0 or gameOver(self)) {
        self.reset();
        return false;
    }

    return true;
}

pub fn save(self: *Board) !void {
    const f = try cwd.createFile(self.savefile, .{});
    defer f.close();
    errdefer cwd.deleteFile(self.savefile) catch {};

    var bw = io.bufferedWriter(f.writer());
    const bw_writer = bw.writer();
    try bw_writer.print("{d}\n{d}\n{d}\n", .{
        self.highscore,
        self.score,
        self.turns,
    });
    for (self.cells) |row| {
        for (row) |cell| {
            try bw_writer.writeByte(cell);
        }
    }
    try bw.flush();
}

fn findTarget(row: []u8, x: usize, stop: usize) usize {
    if (x == 0) {
        return 0;
    }

    var t = x - 1;
    while (true) : (t -= 1) {
        if (row[t] != 0) {
            if (row[t] != row[x]) {
                return t + 1;
            }
            return t;
        } else if (t == stop) {
            return t;
        }
    }
    unreachable;
}

fn rotateRight(board: [][]u8) void {
    const n = board.len;
    for (0..n / 2) |i| {
        for (i..n - i - 1) |j| {
            const tmp = board[i][j];
            board[i][j] = board[j][n - i - 1];
            board[j][n - i - 1] = board[n - i - 1][n - j - 1];
            board[n - i - 1][n - j - 1] = board[n - j - 1][i];
            board[n - j - 1][i] = tmp;
        }
    }
}

fn rotateLeft(board: [][]u8) void {
    const n = board.len;
    for (0..n / 2) |i| {
        for (i..n - i - 1) |j| {
            const tmp = board[n - j - 1][i];
            board[n - j - 1][i] = board[n - i - 1][n - j - 1];
            board[n - i - 1][n - j - 1] = board[j][n - i - 1];
            board[j][n - i - 1] = board[i][j];
            board[i][j] = tmp;
        }
    }
}

fn slide(self: *Board) bool {
    var success = false;
    for (self.cells) |row| {
        var stop: usize = 0;
        for (0..row.len) |x| {
            if (row[x] != 0) {
                const t = findTarget(row, x, stop);

                if (t != x) {
                    if (row[t] == 0) {
                        row[t] = row[x];
                    } else if (row[t] == row[x]) {
                        row[t] += 1;
                        self.score += @as(u64, 1) << @intCast(row[t]);
                        stop = t + 1;
                    }
                    row[x] = 0;
                    success = true;
                }
            }
        }
    }

    if (self.score > self.highscore) {
        self.highscore = self.score;
    }
    if (success) {
        boardCopy(self.prev, self.tmp);
        self.turns += 1;
    }

    return success;
}

fn boardCopy(dst: *Board, src: *Board) void {
    for (dst.cells, src.cells) |dst_row, src_row| {
        @memcpy(dst_row, src_row);
    }
    dst.score = src.score;
    dst.turns = src.turns;
}

pub fn moveLeft(self: *Board) bool {
    boardCopy(self.tmp, self);
    return slide(self);
}

pub fn moveUp(self: *Board) bool {
    boardCopy(self.tmp, self);
    rotateRight(self.cells);
    defer rotateLeft(self.cells);
    return slide(self);
}

pub fn moveRight(self: *Board) bool {
    boardCopy(self.tmp, self);
    rotateRight(self.cells);
    rotateRight(self.cells);
    defer rotateLeft(self.cells);
    defer rotateLeft(self.cells);
    return slide(self);
}

pub fn moveDown(self: *Board) bool {
    boardCopy(self.tmp, self);
    rotateLeft(self.cells);
    defer rotateRight(self.cells);
    return slide(self);
}

pub fn undo(self: *Board) void {
    boardCopy(self, self.prev);
}

fn gameWon(board: [][]u8) bool {
    for (board) |row| {
        for (row) |cell| {
            if (cell >= 11)
                return true;
        }
    }
    return false;
}

fn findPairOneWay(board: [][]u8) bool {
    for (0..board.len) |x| {
        for (0..board.len - 1) |y| {
            if (board[x][y] == board[x][y + 1])
                return true;
        }
    }
    return false;
}

pub fn gameOver(self: *Board) bool {
    for (self.cells) |row| {
        for (row) |cell| {
            if (cell == 0)
                return false; // has empty cells
        }
    }
    if (findPairOneWay(self.cells))
        return false;
    rotateRight(self.cells);
    defer rotateLeft(self.cells);
    return !findPairOneWay(self.cells);
}

fn setColors(cell: u8) !void {
    try term.setFg(term.Color.black);
    const real = @as(u64, 1) << @intCast(cell);
    switch (real) {
        2 => try term.setBg(term.Color.red),
        4 => try term.setBg(term.Color.green),
        8 => try term.setBg(term.Color.yellow),
        16 => try term.setBg(term.Color.blue),
        32 => try term.setBg(term.Color.magenta),
        64 => try term.setBg(term.Color.cyan),
        128 => try term.setBg(term.Color.bright_red),
        256 => try term.setBg(term.Color.bright_green),
        512 => try term.setBg(term.Color.bright_yellow),
        1024 => try term.setBg(term.Color.bright_blue),
        2048 => try term.setBg(term.Color.bright_magenta),
        4096 => try term.setBg(term.Color.bright_cyan),
        8192 => {
            try term.setFg(term.Color.white);
            try term.setBg(term.Color.black);
        },
        else => {
            try term.resetColor();
            try term.setBg(term.Color.bright_black);
        },
    }
}

fn countDigits(number: u64) u8 {
    var count: u8 = 1;
    var n = number / 10;
    while (n != 0) {
        count += 1;
        n /= 10;
    }
    return count;
}

fn printHeader(self: *Board) !void {
    const board_size = CELL_SIZE * self.size;
    const title = "2048.zig" ++ " ";
    const score_digits = countDigits(self.score);
    const turns_digits = countDigits(self.turns);
    const highscore_digits = countDigits(self.highscore);

    const stext1 = title.len + highscore_digits + "Highscore: ".len;
    const n1 = board_size -| stext1;
    try writer.writeAll(title);
    try writer.writeByteNTimes(' ', n1);
    try writer.print("Highscore: {d}\n", .{self.highscore});

    const padding = highscore_digits - score_digits;
    const stext2 = "Turns:  ".len + turns_digits + "Score: ".len + padding + score_digits;
    const n2 = board_size -| stext2;
    try writer.print("Turns: {d} ", .{self.turns});
    try writer.writeByteNTimes(' ', n2);
    try writer.writeAll("Score: ");
    try writer.writeByteNTimes(' ', padding);
    try writer.print("{d}\n", .{self.score});
}

pub fn print(self: *Board, str: []const u8) !void {
    const board_size = CELL_SIZE * self.size;
    const n = (board_size - str.len) / 2;
    try writer.writeByteNTimes(' ', n);
    try writer.print("{s}\n", .{str});
}

pub fn draw(self: *Board) !void {
    try term.cursorTopLeft();
    try term.clear();
    try printHeader(self);
    for (self.cells) |row| {
        for (row) |cell| {
            try setColors(cell);
            try writer.writeAll(" " ** CELL_SIZE);
        }
        try writer.writeAll("\n");
        for (row) |cell| {
            try setColors(cell);
            if (cell == 0) {
                try writer.writeAll("   ·   ");
            } else {
                const real = @as(u64, 1) << @intCast(cell);
                const digits = countDigits(real);
                // TODO kinda unsafe negative
                var n = CELL_SIZE - digits;
                n = n - n / 2;
                if (digits % 2 == 0) {
                    try writer.writeByteNTimes(' ', n - 1);
                } else {
                    try writer.writeByteNTimes(' ', n);
                }
                try writer.print("{d}", .{real});
                try writer.writeByteNTimes(' ', n);
            }
        }
        try writer.writeAll("\n");
        for (row) |cell| {
            try setColors(cell);
            try writer.writeAll(" " ** CELL_SIZE);
        }
        try term.resetColor();
        try writer.writeAll("\n");
    }
    if (!self.win and gameWon(self.cells)) {
        self.win = true;
        try print(self, "VICTORY!");
    } else if (self.gameOver()) {
        try print(self, "GAME OVER");
    } else {
        try writer.writeAll("\n");
    }
    try term.cursorUp();
    try main.buffered_writer.flush();
}

test "rotation" {
    // 2, 0, 0, 0
    // 0, 0, 0, 0
    // 2, 0, 0, 4
    // 4, 2, 0, 0
    var board = try createBoard(4);
    defer destroyBoard(board);
    board[0][0] = 1;
    board[2][0] = 1;
    board[2][3] = 2;
    board[3][0] = 2;
    board[3][1] = 1;

    const expect = std.testing.expect;
    const eql = std.mem.eql;
    rotateRight(board);
    try expect(eql(u8, board[0], &([_]u8{ 0, 0, 2, 0 })));
    try expect(eql(u8, board[1], &([_]u8{ 0, 0, 0, 0 })));
    try expect(eql(u8, board[2], &([_]u8{ 0, 0, 0, 1 })));
    try expect(eql(u8, board[3], &([_]u8{ 1, 0, 1, 2 })));
    rotateLeft(board);
    try expect(eql(u8, board[0], &([_]u8{ 1, 0, 0, 0 })));
    try expect(eql(u8, board[1], &([_]u8{ 0, 0, 0, 0 })));
    try expect(eql(u8, board[2], &([_]u8{ 1, 0, 0, 2 })));
    try expect(eql(u8, board[3], &([_]u8{ 2, 1, 0, 0 })));
}

test "move" {
    var board = try init(4);
    defer board.deinit();
    board.reset();
    board.cells[0][0] = 1;
    board.cells[2][0] = 1;
    board.cells[2][3] = 2;
    board.cells[3][0] = 2;
    board.cells[3][1] = 1;

    const expect = std.testing.expect;
    const eql = std.mem.eql;
    try expect(board.moveRight());
    try expect(eql(u8, board.cells[0], &([_]u8{ 0, 0, 0, 1 })));
    try expect(eql(u8, board.cells[1], &([_]u8{ 0, 0, 0, 0 })));
    try expect(eql(u8, board.cells[2], &([_]u8{ 0, 0, 1, 2 })));
    try expect(eql(u8, board.cells[3], &([_]u8{ 0, 0, 2, 1 })));
    try expect(board.moveDown());
    try expect(eql(u8, board.cells[0], &([_]u8{ 0, 0, 0, 0 })));
    try expect(eql(u8, board.cells[1], &([_]u8{ 0, 0, 0, 1 })));
    try expect(eql(u8, board.cells[2], &([_]u8{ 0, 0, 1, 2 })));
    try expect(eql(u8, board.cells[3], &([_]u8{ 0, 0, 2, 1 })));
    try expect(board.moveLeft());
    try expect(eql(u8, board.cells[0], &([_]u8{ 0, 0, 0, 0 })));
    try expect(eql(u8, board.cells[1], &([_]u8{ 1, 0, 0, 0 })));
    try expect(eql(u8, board.cells[2], &([_]u8{ 1, 2, 0, 0 })));
    try expect(eql(u8, board.cells[3], &([_]u8{ 2, 1, 0, 0 })));
    try expect(board.moveUp());
    try expect(eql(u8, board.cells[0], &([_]u8{ 2, 2, 0, 0 })));
    try expect(eql(u8, board.cells[1], &([_]u8{ 2, 1, 0, 0 })));
    try expect(eql(u8, board.cells[2], &([_]u8{ 0, 0, 0, 0 })));
    try expect(eql(u8, board.cells[3], &([_]u8{ 0, 0, 0, 0 })));
}

test "gameOver" {
    var board = try init(2);
    defer board.deinit();
    board.reset();
    board.cells[0][0] = 1;
    board.cells[0][1] = 3;
    board.cells[1][0] = 3;
    board.cells[1][1] = 2;

    const expect = std.testing.expect;
    try expect(board.gameOver());
    board.cells[1][0] = 0;
    try expect(!board.gameOver());
    board.cells[1][0] = 2;
    try expect(!board.gameOver());
}
