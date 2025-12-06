const std = @import("std");
const input_data = @embedFile("input.txt");

const Lines = struct {
    data: [64][]const u8 = undefined,
    count: usize = 0,
    width: usize = 0,

    fn init() Lines {
        var self = Lines{};
        var iter = std.mem.splitScalar(u8, input_data, '\n');
        while (iter.next()) |line| {
            if (line.len == 0) continue;
            self.data[self.count] = line;
            self.count += 1;
            self.width = @max(self.width, line.len);
        }

        return self;
    }

    fn dataRows(self: *const Lines) []const []const u8 {
        return self.data[0 .. self.count - 1];
    }

    fn opRow(self: *const Lines) []const u8 {
        return self.data[self.count - 1];
    }

    fn getChar(self: *const Lines, row: usize, col: usize) u8 {
        const line = self.data[row];
        return if (col < line.len) line[col] else ' ';
    }

    fn isSpaceCol(self: *const Lines, col: usize) bool {
        for (0..self.count) |row| {
            if (self.getChar(row, col) != ' ') return false;
        }
        return true;
    }

    fn getOp(self: *const Lines, start: usize, end: usize) u8 {
        for (start..end) |col| {
            const c = self.getChar(self.count - 1, col);
            if (c == '*' or c == '+') return c;
        }
        return '+';
    }
};

fn applyOp(result: *u64, num: u64, op: u8) void {
    if (op == '*') result.* *= num else result.* += num;
}

fn part1(lines: *const Lines) u64 {
    var total: u64 = 0;
    var col: usize = 0;

    while (col < lines.width) {
        while (col < lines.width and lines.isSpaceCol(col)) col += 1;
        if (col >= lines.width) break;

        var end = col + 1;
        while (end < lines.width and !lines.isSpaceCol(end)) end += 1;

        const op = lines.getOp(col, end);
        var result: u64 = if (op == '*') 1 else 0;

        for (lines.dataRows()) |line| {
            if (col >= line.len) continue;
            const slice = std.mem.trim(u8, line[col..@min(end, line.len)], " ");
            if (slice.len > 0) {
                if (std.fmt.parseInt(u64, slice, 10)) |num| applyOp(&result, num, op) else |_| {}
            }
        }

        total += result;
        col = end;
    }

    return total;
}

fn part2(lines: *const Lines) u64 {
    var total: u64 = 0;
    var col: isize = @intCast(lines.width - 1);

    while (col >= 0) {
        while (col >= 0 and lines.isSpaceCol(@intCast(col))) col -= 1;
        if (col < 0) break;

        var start: isize = col - 1;
        while (start >= 0 and !lines.isSpaceCol(@intCast(start))) start -= 1;
        start += 1;

        const s: usize = @intCast(start);
        const e: usize = @intCast(col + 1);

        const op = lines.getOp(s, e);
        var result: u64 = if (op == '*') 1 else 0;

        var c: usize = e;
        while (c > s) {
            c -= 1;
            var num: u64 = 0;
            var has_digit = false;
            for (lines.dataRows(), 0..) |_, row| {
                const ch = lines.getChar(row, c);
                if (ch >= '0' and ch <= '9') {
                    num = num * 10 + (ch - '0');
                    has_digit = true;
                }
            }

            if (has_digit) applyOp(&result, num, op);
        }

        total += result;
        col = start - 1;
    }

    return total;
}

pub fn main() !void {
    var out = std.fs.File.stdout().writerStreaming(&.{});
    const lines = Lines.init();

    var t1 = try std.time.Timer.start();
    const res1 = part1(&lines);
    const e1 = t1.read();

    var t2 = try std.time.Timer.start();
    const res2 = part2(&lines);
    const e2 = t2.read();

    // Part 1: 4364617236318
    // Time:   33.96μs
    try out.interface.print("Part 1: {d}\nTime:   {d:.2}μs\n\n", .{ res1, @as(f64, @floatFromInt(e1)) / 1000.0 });
    // Part 2: 9077004354241
    // Time:   19.79μs
    try out.interface.print("Part 2: {d}\nTime:   {d:.2}μs\n", .{ res2, @as(f64, @floatFromInt(e2)) / 1000.0 });
}