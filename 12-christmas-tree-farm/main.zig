const std = @import("std");

const input_data = @embedFile("input.txt");

const MAX_SHAPE_SIZE = 8;
const MAX_SHAPES = 20;
const MAX_ORIENTATIONS = 8;

const Point = struct {
    x: i8,
    y: i8,
};

const Shape = struct {
    points: [MAX_SHAPE_SIZE * MAX_SHAPE_SIZE]Point,
    count: usize,
    width: u8,
    height: u8,
};

const Orientation = struct {
    shapes: [MAX_ORIENTATIONS]Shape,
    count: usize,
};

fn parseInput() struct { orientations: [MAX_SHAPES]Orientation, shape_count: usize, regions: [1000]Region, region_count: usize } {
    var orientations: [MAX_SHAPES]Orientation = undefined;
    var shape_count: usize = 0;
    var regions: [1000]Region = undefined;
    var region_count: usize = 0;

    var lines = std.mem.splitScalar(u8, input_data, '\n');

    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (std.mem.indexOf(u8, line, "x")) |_| {
            const reg = parseRegionLine(line);
            regions[region_count] = reg;
            region_count += 1;
            continue;
        }
        if (line.len >= 2 and line[line.len - 1] == ':') {
            var grid: [MAX_SHAPE_SIZE][MAX_SHAPE_SIZE]bool = .{.{false} ** MAX_SHAPE_SIZE} ** MAX_SHAPE_SIZE;
            var row: usize = 0;
            var max_col: usize = 0;

            while (lines.next()) |grid_line| {
                if (grid_line.len == 0) break;
                if (grid_line[0] != '#' and grid_line[0] != '.') {
                    if (std.mem.indexOf(u8, grid_line, "x")) |_| {
                        const reg = parseRegionLine(grid_line);
                        regions[region_count] = reg;
                        region_count += 1;
                    }

                    break;
                }

                for (grid_line, 0..) |ch, col| {
                    if (ch == '#') {
                        grid[row][col] = true;
                        if (col + 1 > max_col) max_col = col + 1;
                    }
                }

                row += 1;
            }

            if (row > 0) {
                orientations[shape_count] = generateOrientations(&grid, @intCast(max_col), @intCast(row));
                shape_count += 1;
            }
        }
    }

    return .{ .orientations = orientations, .shape_count = shape_count, .regions = regions, .region_count = region_count };
}

const Region = struct {
    width: u16,
    height: u16,
    required: [MAX_SHAPES]u8,
    req_count: usize,
};

fn parseRegionLine(line: []const u8) Region {
    var region: Region = undefined;
    region.req_count = 0;

    var pos: usize = 0;
    var width: u16 = 0;
    while (pos < line.len and line[pos] >= '0' and line[pos] <= '9') {
        width = width * 10 + @as(u16, line[pos] - '0');
        pos += 1;
    }

    region.width = width;

    pos += 1;
    var height: u16 = 0;
    while (pos < line.len and line[pos] >= '0' and line[pos] <= '9') {
        height = height * 10 + @as(u16, line[pos] - '0');
        pos += 1;
    }

    region.height = height;

    if (pos < line.len and line[pos] == ':') pos += 1;
    while (pos < line.len) {
        while (pos < line.len and line[pos] == ' ') pos += 1;
        if (pos >= line.len) break;

        var qty: u8 = 0;
        while (pos < line.len and line[pos] >= '0' and line[pos] <= '9') {
            qty = qty * 10 + @as(u8, line[pos] - '0');
            pos += 1;
        }

        region.required[region.req_count] = qty;
        region.req_count += 1;
    }

    return region;
}

fn generateOrientations(grid: *const [MAX_SHAPE_SIZE][MAX_SHAPE_SIZE]bool, width: u8, height: u8) Orientation {
    var result: Orientation = undefined;
    result.count = 0;

    var current = grid.*;
    var cur_w = width;
    var cur_h = height;

    for (0..4) |_| {
        addIfUnique(&result, &current, cur_w, cur_h);

        var flipped: [MAX_SHAPE_SIZE][MAX_SHAPE_SIZE]bool = .{.{false} ** MAX_SHAPE_SIZE} ** MAX_SHAPE_SIZE;
        for (0..cur_h) |r| {
            for (0..cur_w) |c| {
                flipped[r][cur_w - 1 - c] = current[r][c];
            }
        }

        addIfUnique(&result, &flipped, cur_w, cur_h);

        var rotated: [MAX_SHAPE_SIZE][MAX_SHAPE_SIZE]bool = .{.{false} ** MAX_SHAPE_SIZE} ** MAX_SHAPE_SIZE;
        for (0..cur_h) |r| {
            for (0..cur_w) |c| {
                rotated[c][cur_h - 1 - r] = current[r][c];
            }
        }

        current = rotated;
        const tmp = cur_w;
        cur_w = cur_h;
        cur_h = tmp;
    }

    return result;
}

fn addIfUnique(result: *Orientation, grid: *const [MAX_SHAPE_SIZE][MAX_SHAPE_SIZE]bool, width: u8, height: u8) void {
    var shape: Shape = undefined;
    shape.count = 0;
    shape.width = width;
    shape.height = height;

    for (0..height) |r| {
        for (0..width) |c| {
            if (grid[r][c]) {
                shape.points[shape.count] = .{ .x = @intCast(c), .y = @intCast(r) };
                shape.count += 1;
            }
        }
    }

    for (0..result.count) |i| {
        const existing = &result.shapes[i];
        if (existing.count == shape.count and existing.width == shape.width and existing.height == shape.height) {
            var match = true;
            for (0..shape.count) |j| {
                var found = false;
                for (0..existing.count) |k| {
                    if (existing.points[k].x == shape.points[j].x and existing.points[k].y == shape.points[j].y) {
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    match = false;
                    break;
                }
            }

            if (match) return;
        }
    }

    result.shapes[result.count] = shape;
    result.count += 1;
}

const MAX_GRID = 60;

fn canPlace(grid: *const [MAX_GRID][MAX_GRID]bool, shape: *const Shape, px: usize, py: usize, width: u16, height: u16) bool {
    for (0..shape.count) |i| {
        const nx = px + @as(usize, @intCast(shape.points[i].x));
        const ny = py + @as(usize, @intCast(shape.points[i].y));
        if (nx >= width or ny >= height) return false;
        if (grid[ny][nx]) return false;
    }

    return true;
}

fn placeShape(grid: *[MAX_GRID][MAX_GRID]bool, shape: *const Shape, px: usize, py: usize) void {
    for (0..shape.count) |i| {
        const nx = px + @as(usize, @intCast(shape.points[i].x));
        const ny = py + @as(usize, @intCast(shape.points[i].y));
        grid[ny][nx] = true;
    }
}

fn removeShape(grid: *[MAX_GRID][MAX_GRID]bool, shape: *const Shape, px: usize, py: usize) void {
    for (0..shape.count) |i| {
        const nx = px + @as(usize, @intCast(shape.points[i].x));
        const ny = py + @as(usize, @intCast(shape.points[i].y));
        grid[ny][nx] = false;
    }
}

fn countFilled(grid: *const [MAX_GRID][MAX_GRID]bool, width: u16, height: u16) usize {
    var count: usize = 0;
    for (0..height) |y| {
        for (0..width) |x| {
            if (grid[y][x]) count += 1;
        }
    }

    return count;
}

fn totalCellsNeeded(orientations: *const [MAX_SHAPES]Orientation, remaining: *const [MAX_SHAPES]u8, shape_count: usize) usize {
    var total: usize = 0;
    for (0..shape_count) |i| {
        if (remaining[i] > 0) {
            total += orientations[i].shapes[0].count * remaining[i];
        }
    }

    return total;
}

fn solve(grid: *[MAX_GRID][MAX_GRID]bool, orientations: *const [MAX_SHAPES]Orientation, remaining: *[MAX_SHAPES]u8, shape_count: usize, width: u16, height: u16) bool {
    var best_idx: ?usize = null;
    var best_count: u8 = 255;
    for (0..shape_count) |i| {
        if (remaining[i] > 0 and remaining[i] < best_count) {
            best_count = remaining[i];
            best_idx = i;
        }
    }

    if (best_idx == null) return true;

    const idx = best_idx.?;
    const filled = countFilled(grid, width, height);
    const available = @as(usize, width) * @as(usize, height) - filled;
    const needed = totalCellsNeeded(orientations, remaining, shape_count);
    if (needed > available) return false;

    remaining[idx] -= 1;

    const orient = &orientations[idx];
    for (0..orient.count) |o| {
        const shape = &orient.shapes[o];
        const max_x = if (width >= shape.width) width - shape.width + 1 else 0;
        const max_y = if (height >= shape.height) height - shape.height + 1 else 0;

        for (0..max_y) |py| {
            for (0..max_x) |px| {
                if (canPlace(grid, shape, px, py, width, height)) {
                    placeShape(grid, shape, px, py);
                    if (solve(grid, orientations, remaining, shape_count, width, height)) {
                        return true;
                    }

                    removeShape(grid, shape, px, py);
                }
            }
        }
    }

    remaining[idx] += 1;
    return false;
}

fn canFitAllPresents(region: *const Region, orientations: *const [MAX_SHAPES]Orientation, shape_count: usize) bool {
    var cells_needed: usize = 0;
    for (0..shape_count) |i| {
        const qty = if (i < region.req_count) region.required[i] else 0;
        if (qty > 0) {
            cells_needed += orientations[i].shapes[0].count * qty;
        }
    }

    const available = @as(usize, region.width) * @as(usize, region.height);
    if (cells_needed > available) return false;

    var grid: [MAX_GRID][MAX_GRID]bool = .{.{false} ** MAX_GRID} ** MAX_GRID;
    var remaining: [MAX_SHAPES]u8 = .{0} ** MAX_SHAPES;
    for (0..shape_count) |i| {
        remaining[i] = if (i < region.req_count) region.required[i] else 0;
    }

    return solve(&grid, orientations, &remaining, shape_count, region.width, region.height);
}

pub fn main() !void {
    var out = std.fs.File.stdout().writerStreaming(&.{});

    var timer = try std.time.Timer.start();
    const parsed = parseInput();

    var count: usize = 0;
    for (0..parsed.region_count) |i| {
        if (canFitAllPresents(&parsed.regions[i], &parsed.orientations, parsed.shape_count)) {
            count += 1;
        }
    }

    const elapsed = timer.read();

    // Part 1: 541
    // Time: 91911375ns (91911.38μs)
    try out.interface.print("Part 1: {d}\n", .{count});
    try out.interface.print("Time: {d}ns ({d:.2}μs)\n", .{ elapsed, @as(f64, @floatFromInt(elapsed)) / 1000.0 });
}
