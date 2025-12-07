const std = @import("std");
const input_data = @embedFile("input.txt");

fn part1() u64 {
    var lines: [256][]const u8 = undefined;
    var height: usize = 0;
    var width: usize = 0;

    var iter = std.mem.splitScalar(u8, input_data, '\n');
    while (iter.next()) |line| {
        if (line.len == 0) continue;
        lines[height] = line;
        width = @max(width, line.len);
        height += 1;
    }

    var start_col: usize = 0;
    for (lines[0], 0..) |c, i| {
        if (c == 'S') {
            start_col = i;
            break;
        }
    }

    var beams: [1024]bool = .{false} ** 1024;
    beams[start_col] = true;

    var split_count: u64 = 0;

    for (1..height) |row| {
        const line = lines[row];
        var new_beams: [1024]bool = .{false} ** 1024;

        for (0..width) |col| {
            if (!beams[col]) continue;

            const c = if (col < line.len) line[col] else '.';

            if (c == '^') {
                split_count += 1;
                if (col > 0) new_beams[col - 1] = true;
                if (col + 1 < width) new_beams[col + 1] = true;
            } else {
                new_beams[col] = true;
            }
        }

        beams = new_beams;
    }

    return split_count;
}

fn part2() u64 {
    var lines: [256][]const u8 = undefined;
    var height: usize = 0;
    var width: usize = 0;

    var iter = std.mem.splitScalar(u8, input_data, '\n');
    while (iter.next()) |line| {
        if (line.len == 0) continue;
        lines[height] = line;
        width = @max(width, line.len);
        height += 1;
    }

    var start_col: usize = 0;
    for (lines[0], 0..) |c, i| {
        if (c == 'S') {
            start_col = i;
            break;
        }
    }

    var timelines: [1024]u64 = .{0} ** 1024;
    timelines[start_col] = 1;

    for (1..height) |row| {
        const line = lines[row];
        var new_timelines: [1024]u64 = .{0} ** 1024;

        for (0..width) |col| {
            if (timelines[col] == 0) continue;

            const c = if (col < line.len) line[col] else '.';

            if (c == '^') {
                // Each timeline splits into two
                if (col > 0) new_timelines[col - 1] += timelines[col];
                if (col + 1 < width) new_timelines[col + 1] += timelines[col];
            } else {
                // Timelines continue straight
                new_timelines[col] += timelines[col];
            }
        }

        timelines = new_timelines;
    }

    var total: u64 = 0;
    for (timelines) |t| {
        total += t;
    }

    return total;
}

pub fn main() !void {
    var out = std.fs.File.stdout().writerStreaming(&.{});

    var t1 = try std.time.Timer.start();
    const res1 = part1();
    const e1 = t1.read();

    var t2 = try std.time.Timer.start();
    const res2 = part2();
    const e2 = t2.read();

    // Part 1: 1516
    // Time:   32.67μs
    try out.interface.print("Part 1: {d}\nTime:   {d:.2}μs\n\n", .{ res1, @as(f64, @floatFromInt(e1)) / 1000.0 });
    // Part 2: 1393669447690
    // Time:   49.71μs
    try out.interface.print("Part 2: {d}\nTime:   {d:.2}μs\n", .{ res2, @as(f64, @floatFromInt(e2)) / 1000.0 });
}