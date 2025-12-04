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

fn countAdjacentRolls(grid: []const u8, x: usize, y: usize) u32 {
    var count: u32 = 0;

    const x_i32: i32 = @intCast(x);
    const y_i32: i32 = @intCast(y);

    if (x > 0 and y > 0) {
        count += @intFromBool(getCell(grid, x - 1, y - 1) == '@');
    }
    if (y > 0) {
        count += @intFromBool(getCell(grid, x, y - 1) == '@');
    }
    if (x < WIDTH - 1 and y > 0) {
        count += @intFromBool(getCell(grid, x + 1, y - 1) == '@');
    }
    if (x > 0) {
        count += @intFromBool(getCell(grid, x - 1, y) == '@');
    }
    if (x < WIDTH - 1) {
        count += @intFromBool(getCell(grid, x + 1, y) == '@');
    }
    if (x > 0 and y < HEIGHT - 1) {
        count += @intFromBool(getCell(grid, x - 1, y + 1) == '@');
    }
    if (y < HEIGHT - 1) {
        count += @intFromBool(getCell(grid, x, y + 1) == '@');
    }
    if (x < WIDTH - 1 and y < HEIGHT - 1) {
        count += @intFromBool(getCell(grid, x + 1, y + 1) == '@');
    }

    _ = x_i32;
    _ = y_i32;

    return count;
}

fn part1(grid: []const u8) usize {
    var accessible_count: usize = 0;

    for (0..HEIGHT) |y| {
        const row_start = y * LINE_STRIDE;

        var x: usize = 0;
        while (x + 16 <= WIDTH) : (x += 16) {
            const chunk: Vec = grid[row_start + x ..][0..16].*;
            const matches = chunk == AT_VEC;
            const mask: u16 = @bitCast(matches);

            if (mask != 0) {
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
        }

        while (x < WIDTH) : (x += 1) {
            if (getCell(grid, x, y) == '@') {
                if (countAdjacentRolls(grid, x, y) < 4) {
                    accessible_count += 1;
                }
            }
        }
    }

    return accessible_count;
}

fn part2(input: []const u8) usize {
    var grid: [HEIGHT * LINE_STRIDE]u8 = undefined;
    @memcpy(&grid, input[0 .. HEIGHT * LINE_STRIDE]);

    var to_remove_x: [WIDTH * HEIGHT]u8 = undefined;
    var to_remove_y: [WIDTH * HEIGHT]u8 = undefined;

    var total_removed: usize = 0;

    while (true) {
        var remove_count: usize = 0;

        for (0..HEIGHT) |y| {
            const row_start = y * LINE_STRIDE;

            var x: usize = 0;
            while (x + 16 <= WIDTH) : (x += 16) {
                const chunk: Vec = grid[row_start + x ..][0..16].*;
                const matches = chunk == AT_VEC;
                const mask: u16 = @bitCast(matches);

                if (mask != 0) {
                    var m = mask;
                    while (m != 0) {
                        const bit_pos = @ctz(m);
                        const actual_x = x + bit_pos;
                        if (countAdjacentRolls(&grid, actual_x, y) < 4) {
                            to_remove_x[remove_count] = @intCast(actual_x);
                            to_remove_y[remove_count] = @intCast(y);
                            remove_count += 1;
                        }
                        m &= m - 1;
                    }
                }
            }

            while (x < WIDTH) : (x += 1) {
                if (getCell(&grid, x, y) == '@') {
                    if (countAdjacentRolls(&grid, x, y) < 4) {
                        to_remove_x[remove_count] = @intCast(x);
                        to_remove_y[remove_count] = @intCast(y);
                        remove_count += 1;
                    }
                }
            }
        }

        if (remove_count == 0) break;

        for (0..remove_count) |i| {
            setCell(&grid, to_remove_x[i], to_remove_y[i], '.');
        }

        total_removed += remove_count;
    }

    return total_removed;
}

pub fn main() !void {
    var out = std.fs.File.stdout().writerStreaming(&.{});

    var timer1 = try std.time.Timer.start();
    const result1 = part1(input_data);
    const elapsed1 = timer1.read();

    var timer2 = try std.time.Timer.start();
    const result2 = part2(input_data);
    const elapsed2 = timer2.read();

    // Part 1: 1419
    // Time: 32958ns (32.96μs)
    try out.interface.print("Part 1: {d}\n", .{result1});
    try out.interface.print("Time: {d}ns ({d:.2}μs)\n\n", .{ elapsed1, @as(f64, @floatFromInt(elapsed1)) / 1000.0 });

    // Part 2: 8739
    // Time: 855459ns (855.46μs)
    try out.interface.print("Part 2: {d}\n", .{result2});
    try out.interface.print("Time: {d}ns ({d:.2}μs)\n\n", .{ elapsed2, @as(f64, @floatFromInt(elapsed2)) / 1000.0 });
}