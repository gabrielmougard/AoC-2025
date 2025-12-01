const std = @import("std");
const math = std.math;

const input_data = @embedFile("input.txt");

pub fn main() !void {
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

    try out.interface.print("Result: {d}\n", .{ res });
}