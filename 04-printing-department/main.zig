const std = @import("std");

const input_data = @embedFile("input.txt");

const directions = [_][2]i32{
    .{ -1, -1 }, .{ 0, -1 }, .{ 1, -1 },
    .{ -1, 0 },              .{ 1, 0 },
    .{ -1, 1 },  .{ 0, 1 },  .{ 1, 1 },
};

fn countAdjacentRolls(grid: []const u8, x: usize, y: usize, width: usize, height: usize) usize {
    var adjacent_rolls: usize = 0;

    for (directions) |dir| {
        const nx_signed: i32 = @as(i32, @intCast(x)) + dir[0];
        const ny_signed: i32 = @as(i32, @intCast(y)) + dir[1];

        if (nx_signed < 0 or ny_signed < 0) continue;
        const nx: usize = @intCast(nx_signed);
        const ny: usize = @intCast(ny_signed);
        if (nx >= width or ny >= height) continue;

        if (grid[ny * width + nx] == '@') {
            adjacent_rolls += 1;
        }
    }

    return adjacent_rolls;
}

fn part1(grid: []const u8, width: usize, height: usize) usize {
    var accessible_count: usize = 0;

    for (0..height) |y| {
        for (0..width) |x| {
            if (grid[y * width + x] != '@') continue;

            if (countAdjacentRolls(grid, x, y, width, height) < 4) {
                accessible_count += 1;
            }
        }
    }

    return accessible_count;
}

fn part2(original_grid: []const u8, width: usize, height: usize, allocator: std.mem.Allocator) !usize {
    const grid = try allocator.alloc(u8, width * height);
    defer allocator.free(grid);
    @memcpy(grid, original_grid);

    const to_remove = try allocator.alloc([2]usize, width * height);
    defer allocator.free(to_remove);

    var total_removed: usize = 0;

    while (true) {
        var remove_count: usize = 0;

        for (0..height) |y| {
            for (0..width) |x| {
                if (grid[y * width + x] != '@') continue;

                if (countAdjacentRolls(grid, x, y, width, height) < 4) {
                    to_remove[remove_count] = .{ x, y };
                    remove_count += 1;
                }
            }
        }

        if (remove_count == 0) break;

        for (0..remove_count) |i| {
            const x = to_remove[i][0];
            const y = to_remove[i][1];
            grid[y * width + x] = '.';
        }

        total_removed += remove_count;
    }

    return total_removed;
}

pub fn main() !void {
    var out = std.fs.File.stdout().writerStreaming(&.{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var height: usize = 0;
    var width: usize = 0;

    var line_iter = std.mem.splitScalar(u8, input_data, '\n');
    while (line_iter.next()) |line| {
        if (line.len > 0) {
            width = line.len;
            height += 1;
        }
    }

    const grid = try allocator.alloc(u8, width * height);

    line_iter = std.mem.splitScalar(u8, input_data, '\n');
    var y: usize = 0;
    while (line_iter.next()) |line| {
        if (line.len > 0) {
            @memcpy(grid[y * width .. (y + 1) * width], line);
            y += 1;
        }
    }

    var timer1 = try std.time.Timer.start();
    const result1 = part1(grid, width, height);
    const elapsed1 = timer1.read();

    var timer2 = try std.time.Timer.start();
    const result2 = try part2(grid, width, height, allocator);
    const elapsed2 = timer2.read();

    // Part 1: 1419
    // Time: 53625ns (53μs)
    try out.interface.print("Part 1: {d}\n", .{result1});
    try out.interface.print("Time: {d}ns ({d}μs)\n\n", .{ elapsed1, elapsed1 / 1000 });

    // Part 2: 8739
    // Time: 1371208ns (1371μs)
    try out.interface.print("Part 2: {d}\n", .{result2});
    try out.interface.print("Time: {d}ns ({d}μs)\n\n", .{ elapsed2, elapsed2 / 1000 });

    try out.interface.print("Total time: {d}ns ({d}μs)\n", .{ elapsed1 + elapsed2, (elapsed1 + elapsed2) / 1000 });
}