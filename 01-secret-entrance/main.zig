const std = @import("std");
const math = std.math;

const input_data = @embedFile("input.txt");

// Result: 969
// Time: 41625ns (41μs)
pub fn main() !void {
    var timer = try std.time.Timer.start();
    var out = std.fs.File.stdout().writerStreaming(&.{});

    var line_iter = std.mem.splitScalar(u8, input_data, '\n');
    var state: i32 = 50;
    var new_state: i32 = 0;
    var direction: ?u8 = null;
    var moves: i32 = 0;
    var res: i32 = 0;
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;

        direction = line[0];
        moves = std.fmt.parseInt(i32, line[1..], 10) catch continue;
        new_state = switch (direction.?) {
            'L' => try math.mod(i32, state - moves, 100),
            'R' => try math.mod(i32, state + moves, 100),
            else => state,
        };

        if (new_state == 0) {
            res += 1;
        }

        state = new_state;
    }

    const elapsed = timer.read();

    try out.interface.print("Result: {d}\n", .{res});
    try out.interface.print("Time: {d}ns ({d}μs)\n", .{ elapsed, elapsed / 1000 });
}