const std = @import("std");
const math = std.math;

const input_data = @embedFile("input.txt");

fn countZerosLeft(state: i32, moves: i32) i32 {
    if (state == 0) {
        return @divFloor(moves, 100);
    } else if (moves >= state) {
        return @divFloor(moves - state, 100) + 1;
    } else {
        return 0;
    }
}

fn countZerosRight(state: i32, moves: i32) i32 {
    return @divFloor(state + moves, 100);
}

pub fn main() !void {
    var timer = try std.time.Timer.start();
    var out = std.fs.File.stdout().writerStreaming(&.{});

    var line_iter = std.mem.splitScalar(u8, input_data, '\n');
    var state: i32 = 50;
    var endpoints_at_zero: i32 = 0;
    var total_zero_clicks: i32 = 0;

    while (line_iter.next()) |line| {
        if (line.len == 0) continue;

        const direction = line[0];
        const moves = std.fmt.parseInt(i32, line[1..], 10) catch continue;
        const zeros = switch (direction) {
            'L' => countZerosLeft(state, moves),
            'R' => countZerosRight(state, moves),
            else => 0,
        };

        total_zero_clicks += zeros;
        const new_state = switch (direction) {
            'L' => try math.mod(i32, state - moves, 100),
            'R' => try math.mod(i32, state + moves, 100),
            else => state,
        };

        if (new_state == 0) {
            endpoints_at_zero += 1;
        }

        state = new_state;
    }

    const elapsed = timer.read();

    try out.interface.print("Password (endpoint method): {d}\n", .{endpoints_at_zero});
    try out.interface.print("Password (click method): {d}\n", .{total_zero_clicks});
    try out.interface.print("Time: {d}ns ({d}μs)\n", .{ elapsed, elapsed / 1000 });
}