const std = @import("std");

const input_data = @embedFile("input.txt");

pub fn maxJoltage(line: []const u8, num_digits: usize) u64 {
    if (line.len < num_digits) unreachable;

    var result: u64 = 0;
    var start_pos: usize = 0;
    for (0..num_digits) |digit_idx| {
        const remaining = num_digits - digit_idx - 1;
        const search_end = line.len - remaining;
        var max_char: u8 = line[start_pos];
        var max_pos: usize = start_pos;
        for (start_pos..search_end) |i| {
            if (line[i] > max_char) {
                max_char = line[i];
                max_pos = i;
            }
        }

        result = result * 10 + (max_char - '0');
        start_pos = max_pos + 1;
    }

    return result;
}

// Sum: 17403
// Time: 13333ns (13μs)
pub fn partOne() !void {
    var timer = try std.time.Timer.start();
    var out = std.fs.File.stdout().writerStreaming(&.{});

    var line_iter = std.mem.splitScalar(u8, input_data, '\n');

    var sum: u64 = 0;
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        sum += maxJoltage(line, 2);
    }

    const elapsed = timer.read();

    try out.interface.print("Sum: {d}\n", .{sum});
    try out.interface.print("Time: {d}ns ({d}μs)\n", .{ elapsed, elapsed / 1000 });
}

// Sum: 173416889848394
// Time: 41584ns (41μs)
pub fn partTwo() !void {
    var timer = try std.time.Timer.start();
    var out = std.fs.File.stdout().writerStreaming(&.{});

    var line_iter = std.mem.splitScalar(u8, input_data, '\n');

    var sum: u64 = 0;
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        sum += maxJoltage(line, 12);
    }

    const elapsed = timer.read();

    try out.interface.print("Sum: {d}\n", .{sum});
    try out.interface.print("Time: {d}ns ({d}μs)\n", .{ elapsed, elapsed / 1000 });
}

pub fn main() !void {
    try partOne();
    try partTwo();
}