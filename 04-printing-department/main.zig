const std = @import("std");

const input_data = @embedFile("input.txt");

const WIDTH: usize = 138;
const HEIGHT: usize = 138;
const LINE_STRIDE: usize = WIDTH + 1;

const Vec = @Vector(16, u8);
const AT_VEC: Vec = @splat('@');

inline fn getCell(grid: []const u8, x: usize, y: usize) u8 {
    return grid[y * LINE_STRIDE + x];
}

inline fn setCell(grid: []u8, x: usize, y: usize, val: u8) void {
    grid[y * LINE_STRIDE + x] = val;
}

inline fn countAdjacentRolls(grid: []const u8, x: usize, y: usize) u32 {
    var count: u32 = 0;

    if (x > 0 and y > 0) count += @intFromBool(getCell(grid, x - 1, y - 1) == '@');
    if (y > 0) count += @intFromBool(getCell(grid, x, y - 1) == '@');
    if (x < WIDTH - 1 and y > 0) count += @intFromBool(getCell(grid, x + 1, y - 1) == '@');
    if (x > 0) count += @intFromBool(getCell(grid, x - 1, y) == '@');
    if (x < WIDTH - 1) count += @intFromBool(getCell(grid, x + 1, y) == '@');
    if (x > 0 and y < HEIGHT - 1) count += @intFromBool(getCell(grid, x - 1, y + 1) == '@');
    if (y < HEIGHT - 1) count += @intFromBool(getCell(grid, x, y + 1) == '@');
    if (x < WIDTH - 1 and y < HEIGHT - 1) count += @intFromBool(getCell(grid, x + 1, y + 1) == '@');

    return count;
}

fn part1(grid: []const u8) usize {
    var accessible_count: usize = 0;

    for (0..HEIGHT) |y| {
        const row_start = y * LINE_STRIDE;
        var x: usize = 0;

        while (x + 16 <= WIDTH) : (x += 16) {
            const chunk: Vec = grid[row_start + x ..][0..16].*;
            const mask: u16 = @bitCast(chunk == AT_VEC);

            var m = mask;
            while (m != 0) {
                const bit_pos = @ctz(m);
                const actual_x = x + bit_pos;
                if (countAdjacentRolls(grid, actual_x, y) < 4) {
                    accessible_count += 1;
                }
                m &= m - 1;
            }
        }

        while (x < WIDTH) : (x += 1) {
            if (getCell(grid, x, y) == '@' and countAdjacentRolls(grid, x, y) < 4) {
                accessible_count += 1;
            }
        }
    }

    return accessible_count;
}

fn part2(input: []const u8) usize {
    var grid: [HEIGHT * LINE_STRIDE]u8 = undefined;
    @memcpy(&grid, input[0 .. HEIGHT * LINE_STRIDE]);

    var queue: [WIDTH * HEIGHT * 9]u16 = undefined;
    var queue_head: usize = 0;
    var queue_tail: usize = 0;

    for (0..HEIGHT) |y| {
        const row_start = y * LINE_STRIDE;
        var x: usize = 0;

        while (x + 16 <= WIDTH) : (x += 16) {
            const chunk: Vec = grid[row_start + x ..][0..16].*;
            const mask: u16 = @bitCast(chunk == AT_VEC);

            var m = mask;
            while (m != 0) {
                const bit_pos = @ctz(m);
                const actual_x = x + bit_pos;
                queue[queue_tail] = @as(u16, @intCast(y)) << 8 | @as(u16, @intCast(actual_x));
                queue_tail += 1;
                m &= m - 1;
            }
        }

        while (x < WIDTH) : (x += 1) {
            if (getCell(&grid, x, y) == '@') {
                queue[queue_tail] = @as(u16, @intCast(y)) << 8 | @as(u16, @intCast(x));
                queue_tail += 1;
            }
        }
    }

    var total: usize = 0;

    const neighbors = [8][2]i8{
        .{ -1, -1 }, .{ 0, -1 }, .{ 1, -1 },
        .{ -1, 0 },              .{ 1, 0 },
        .{ -1, 1 },  .{ 0, 1 },  .{ 1, 1 },
    };

    while (queue_head < queue_tail) {
        const pcked = queue[queue_head];
        queue_head += 1;

        const x = pcked & 0xFF;
        const y = pcked >> 8;

        if (getCell(&grid, x, y) != '@') continue;
        if (countAdjacentRolls(&grid, x, y) >= 4) continue;

        total += 1;
        setCell(&grid, x, y, '.');

        inline for (neighbors) |n| {
            const nx_i16 = @as(i16, @intCast(x)) + n[0];
            const ny_i16 = @as(i16, @intCast(y)) + n[1];

            if (nx_i16 >= 0 and nx_i16 < WIDTH and ny_i16 >= 0 and ny_i16 < HEIGHT) {
                const nx: u16 = @intCast(nx_i16);
                const ny: u16 = @intCast(ny_i16);
                queue[queue_tail] = ny << 8 | nx;
                queue_tail += 1;
            }
        }
    }

    return total;
}

pub fn main() !void {
    var out = std.fs.File.stdout().writerStreaming(&.{});

    // Part 1: 1419
    // Time: 33250ns (33.25μs)
    var timer1 = try std.time.Timer.start();
    const result1 = part1(input_data);
    const elapsed1 = timer1.read();

    // Part 2: 8739
    // Time: 232166ns (232.17μs)
    var timer2 = try std.time.Timer.start();
    const result2 = part2(input_data);
    const elapsed2 = timer2.read();

    try out.interface.print("Part 1: {d}\n", .{result1});
    try out.interface.print("Time: {d}ns ({d:.2}μs)\n\n", .{ elapsed1, @as(f64, @floatFromInt(elapsed1)) / 1000.0 });

    try out.interface.print("Part 2: {d}\n", .{result2});
    try out.interface.print("Time: {d}ns ({d:.2}μs)\n\n", .{ elapsed2, @as(f64, @floatFromInt(elapsed2)) / 1000.0 });
}