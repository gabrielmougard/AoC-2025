const std = @import("std");
const input_data = @embedFile("input.txt");

const Interval = struct {
    start: u64,
    end: u64,
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

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var buffer: [64 * 1024]Interval = undefined;
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

    const intervals = buffer[0 .. write + 1];
    var res: usize = 0;
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        const number = std.fmt.parseInt(u64, line, 10) catch continue;
        if (contains(intervals, number)) res += 1;
    }

    const elapsed = timer.read();

    var out = std.fs.File.stdout().writerStreaming(&.{});
    try out.interface.print("Part 1: {d}\n", .{res});
    try out.interface.print("Time: {d}ns ({d:.2}μs)\n", .{ elapsed, @as(f64, @floatFromInt(elapsed)) / 1000.0 });
}