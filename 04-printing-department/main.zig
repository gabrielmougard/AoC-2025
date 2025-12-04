const std = @import("std");

const input_data = @embedFile("input.txt");

// Result: 1419
// Time: 59917ns (59μs)
pub fn main() !void {
    var timer = try std.time.Timer.start();
    var out = std.fs.File.stdout().writerStreaming(&.{});

    var lines_buf: [1000][]const u8 = undefined;
    var line_count: usize = 0;

    var line_iter = std.mem.splitScalar(u8, input_data, '\n');
    while (line_iter.next()) |line| {
        if (line.len > 0) {
            lines_buf[line_count] = line;
            line_count += 1;
        }
    }

    const grid = lines_buf[0..line_count];
    const height = grid.len;

    const width = grid[0].len;
    var accessible_count: usize = 0;

    for (0..height) |y| {
        for (0..width) |x| {
            if (grid[y][x] != '@') continue;

            var adjacent_rolls: usize = 0;
            const directions = [_][2]i32{
                .{ -1, -1 }, .{ 0, -1 }, .{ 1, -1 },
                .{ -1, 0 },              .{ 1, 0 },
                .{ -1, 1 },  .{ 0, 1 },  .{ 1, 1 },
            };

            for (directions) |dir| {
                const nx_signed: i32 = @as(i32, @intCast(x)) + dir[0];
                const ny_signed: i32 = @as(i32, @intCast(y)) + dir[1];

                if (nx_signed < 0 or ny_signed < 0) continue;
                const nx: usize = @intCast(nx_signed);
                const ny: usize = @intCast(ny_signed);
                if (nx >= width or ny >= height) continue;

                if (grid[ny][nx] == '@') {
                    adjacent_rolls += 1;
                }
            }

            if (adjacent_rolls < 4) {
                accessible_count += 1;
            }
        }
    }

    const elapsed = timer.read();

    try out.interface.print("{d}\n", .{accessible_count});
    try out.interface.print("Time: {d}ns ({d}μs)\n", .{ elapsed, elapsed / 1000 });
}