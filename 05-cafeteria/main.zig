const std = @import("std");
const input_data = @embedFile("input.txt");

const Interval = struct {
    start: u64,
    end: u64,

    inline fn size(self: Interval) u64 {
        return self.end - self.start + 1;
    }
};

fn lessThan(_: void, a: Interval, b: Interval) bool {
    return a.start < b.start;
}

fn contains(intervals: []const Interval, value: u64) bool {
    var left: usize = 0;
    var right: usize = intervals.len;

    while (left < right) {
        const mid = left + (right - left) / 2;
        const iv = intervals[mid];

        if (value >= iv.start and value <= iv.end) return true;
        if (value < iv.start) {
            right = mid;
        } else {
            left = mid + 1;
        }
    }

    return false;
}

const ParseResult = struct {
    intervals: []Interval,
    query_start: std.mem.SplitIterator(u8, .scalar),
};

fn parseAndMerge(buffer: []Interval) ParseResult {
    var len: usize = 0;
    var line_iter = std.mem.splitScalar(u8, input_data, '\n');

    while (line_iter.next()) |line| {
        if (line.len == 0) break;
        var parts = std.mem.splitSequence(u8, line, "-");
        const start = std.fmt.parseInt(u64, parts.next().?, 10) catch continue;
        const end = std.fmt.parseInt(u64, parts.next().?, 10) catch continue;
        buffer[len] = .{ .start = start, .end = end };
        len += 1;
    }

    std.mem.sort(Interval, buffer[0..len], {}, lessThan);

    var write: usize = 0;
    for (buffer[1..len]) |next| {
        if (next.start <= buffer[write].end + 1) {
            buffer[write].end = @max(buffer[write].end, next.end);
        } else {
            write += 1;
            buffer[write] = next;
        }
    }

    return .{
        .intervals = buffer[0 .. write + 1],
        .query_start = line_iter,
    };
}

fn part1(buffer: []Interval) struct { result: usize, intervals: []Interval } {
    var parsed = parseAndMerge(buffer);

    var res: usize = 0;
    while (parsed.query_start.next()) |line| {
        if (line.len == 0) continue;
        const number = std.fmt.parseInt(u64, line, 10) catch continue;
        if (contains(parsed.intervals, number)) res += 1;
    }

    return .{ .result = res, .intervals = parsed.intervals };
}

fn part2(buffer: []Interval) u64 {
    const parsed = parseAndMerge(buffer);

    var res: u64 = 0;
    for (parsed.intervals) |iv| {
        res += iv.size();
    }

    return res;
}

pub fn main() !void {
    var out = std.fs.File.stdout().writerStreaming(&.{});

    // Part 1: 513
    // Time:   50042ns (50.04μs)
    var buffer1: [64 * 1024]Interval = undefined;
    var timer1 = try std.time.Timer.start();
    const p1 = part1(&buffer1);
    const elapsed1 = timer1.read();

    // Part 2: 339668510830757
    // Time:   8083ns (8.08μs)
    var buffer2: [64 * 1024]Interval = undefined;
    var timer2 = try std.time.Timer.start();
    const res2 = part2(&buffer2);
    const elapsed2 = timer2.read();

    try out.interface.print("Part 1: {d}\n", .{p1.result});
    try out.interface.print("Time:   {d}ns ({d:.2}μs)\n\n", .{ elapsed1, @as(f64, @floatFromInt(elapsed1)) / 1000.0 });

    try out.interface.print("Part 2: {d}\n", .{res2});
    try out.interface.print("Time:   {d}ns ({d:.2}μs)\n", .{ elapsed2, @as(f64, @floatFromInt(elapsed2)) / 1000.0 });
}