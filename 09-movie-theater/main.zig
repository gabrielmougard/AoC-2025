const std = @import("std");

const input = @embedFile("input.txt");

const Point = struct {
    x: i32,
    y: i32,

    fn min(a: Point, b: Point) Point {
        return .{ .x = @min(a.x, b.x), .y = @min(a.y, b.y) };
    }

    fn max(a: Point, b: Point) Point {
        return .{ .x = @max(a.x, b.x), .y = @max(a.y, b.y) };
    }
};

const BoundingBox = struct {
    min: Point,
    max: Point,

    fn init() BoundingBox {
        return .{
            .min = .{ .x = std.math.maxInt(i32), .y = std.math.maxInt(i32) },
            .max = .{ .x = std.math.minInt(i32), .y = std.math.minInt(i32) },
        };
    }

    fn expand(self: *BoundingBox, p: Point) void {
        self.min = Point.min(self.min, p);
        self.max = Point.max(self.max, p);
    }

    fn width(self: BoundingBox) i32 {
        return self.max.x - self.min.x + 1;
    }

    fn height(self: BoundingBox) i32 {
        return self.max.y - self.min.y + 1;
    }

    fn area(self: BoundingBox) i64 {
        return @as(i64, self.width()) * @as(i64, self.height());
    }

    fn fromPoints(p1: Point, p2: Point) BoundingBox {
        return .{
            .min = Point.min(p1, p2),
            .max = Point.max(p1, p2),
        };
    }
};

fn parsePoints(allocator: std.mem.Allocator, data: []const u8) !std.ArrayList(Point) {
    var points: std.ArrayList(Point) = .empty;

    var lines = std.mem.tokenizeAny(u8, data, "\n\r");
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var parts = std.mem.tokenizeAny(u8, line, ",");
        const x_str = parts.next() orelse continue;
        const y_str = parts.next() orelse continue;

        const x = std.fmt.parseInt(i32, x_str, 10) catch continue;
        const y = std.fmt.parseInt(i32, y_str, 10) catch continue;

        try points.append(allocator, Point{ .x = x, .y = y });
    }

    return points;
}

fn computeBoundingBox(pts: []const Point) BoundingBox {
    var bbox = BoundingBox.init();
    for (pts) |p| {
        bbox.expand(p);
    }
    return bbox;
}

fn partOne(pts: []const Point) i64 {
    var max_area: i64 = 0;

    for (0..pts.len) |i| {
        for ((i + 1)..pts.len) |j| {
            const bbox = BoundingBox.fromPoints(pts[i], pts[j]);
            const area = bbox.area();
            if (area > max_area) {
                max_area = area;
            }
        }
    }

    return max_area;
}

const Segment = struct {
    start: Point,
    end: Point,
    is_horizontal: bool,
};

fn partTwo(pts: []const Point, allocator: std.mem.Allocator) !i64 {
    if (pts.len < 2) return 0;
    var segments: std.ArrayList(Segment) = .empty;
    defer segments.deinit(allocator);

    for (0..pts.len) |i| {
        const p1 = pts[i];
        const p2 = pts[(i + 1) % pts.len];
        try segments.append(allocator, .{
            .start = Point.min(p1, p2),
            .end = Point.max(p1, p2),
            .is_horizontal = (p1.y == p2.y),
        });
    }

    var x_coords: std.ArrayList(i32) = .empty;
    defer x_coords.deinit(allocator);
    var y_coords: std.ArrayList(i32) = .empty;
    defer y_coords.deinit(allocator);

    for (pts) |p| {
        try x_coords.append(allocator, p.x);
        try y_coords.append(allocator, p.y);
    }

    std.mem.sort(i32, x_coords.items, {}, std.sort.asc(i32));
    std.mem.sort(i32, y_coords.items, {}, std.sort.asc(i32));

    const unique_x = try deduplicate(i32, allocator, x_coords.items);
    defer allocator.free(unique_x);
    const unique_y = try deduplicate(i32, allocator, y_coords.items);
    defer allocator.free(unique_y);

    var x_to_idx = std.AutoHashMap(i32, usize).init(allocator);
    defer x_to_idx.deinit();
    var y_to_idx = std.AutoHashMap(i32, usize).init(allocator);
    defer y_to_idx.deinit();

    for (unique_x, 0..) |x, i| {
        try x_to_idx.put(x, i);
    }
    for (unique_y, 0..) |y, i| {
        try y_to_idx.put(y, i);
    }

    var max_area: i64 = 0;

    for (0..pts.len) |i| {
        for ((i + 1)..pts.len) |j| {
            const p1 = pts[i];
            const p2 = pts[j];

            const bbox = BoundingBox.fromPoints(p1, p2);
            const area = bbox.area();

            if (area <= max_area) continue;
            if (isRectangleInPolygon(bbox, segments.items)) {
                max_area = area;
            }
        }
    }

    return max_area;
}

fn deduplicate(comptime T: type, allocator: std.mem.Allocator, sorted: []const T) ![]T {
    if (sorted.len == 0) return try allocator.alloc(T, 0);

    var result: std.ArrayList(T) = .empty;
    try result.append(allocator, sorted[0]);

    for (sorted[1..]) |val| {
        if (val != result.items[result.items.len - 1]) {
            try result.append(allocator, val);
        }
    }

    return result.toOwnedSlice(allocator);
}

fn isRectangleInPolygon(rect: BoundingBox, segments: []const Segment) bool {
    // A rectangle with red corners is valid if all 4 edges lie on or inside the polygon
    // Since the polygon is rectilinear (axis-aligned), we check:
    // 1. All 4 corners must be inside or on the boundary
    // 2. All 4 edges must not cross the polygon boundary improperly

    // For a rectilinear polygon formed by the path, the rectangle is valid if:
    // - The 4 edges of the rectangle don't cross any polygon edge (except at endpoints)
    // - OR the rectangle is fully contained

    const corners = [_]Point{
        rect.min,
        .{ .x = rect.max.x, .y = rect.min.y },
        rect.max,
        .{ .x = rect.min.x, .y = rect.max.y },
    };

    for (corners) |corner| {
        if (!isPointInPolygon(corner, segments)) {
            return false;
        }
    }

    const rect_edges = [_]Segment{
        .{ .start = corners[0], .end = corners[1], .is_horizontal = true }, // bottom
        .{ .start = corners[1], .end = corners[2], .is_horizontal = false }, // right
        .{ .start = corners[3], .end = corners[2], .is_horizontal = true }, // top
        .{ .start = corners[0], .end = corners[3], .is_horizontal = false }, // left
    };

    for (rect_edges) |rect_edge| {
        for (segments) |poly_edge| {
            if (edgesCrossImproperly(rect_edge, poly_edge)) {
                return false;
            }
        }
    }

    return true;
}

fn isPointInPolygon(p: Point, segments: []const Segment) bool {
    var crossings: i32 = 0;

    for (segments) |seg| {
        if (seg.is_horizontal) {
            if (p.y == seg.start.y and p.x >= seg.start.x and p.x <= seg.end.x) {
                return true;
            }
        } else {
            if (p.x == seg.start.x and p.y >= seg.start.y and p.y <= seg.end.y) {
                return true;
            }

            if (p.x < seg.start.x and p.y > seg.start.y and p.y <= seg.end.y) {
                crossings += 1;
            }
        }
    }

    return @mod(crossings, 2) == 1;
}

fn edgesCrossImproperly(rect_edge: Segment, poly_edge: Segment) bool {
    if (rect_edge.is_horizontal and !poly_edge.is_horizontal) {
        const rx1 = rect_edge.start.x;
        const rx2 = rect_edge.end.x;
        const ry = rect_edge.start.y;

        const px = poly_edge.start.x;
        const py1 = poly_edge.start.y;
        const py2 = poly_edge.end.y;

        if (px > rx1 and px < rx2 and ry > py1 and ry < py2) {
            return true;
        }
    } else if (!rect_edge.is_horizontal and poly_edge.is_horizontal) {
        const rx = rect_edge.start.x;
        const ry1 = rect_edge.start.y;
        const ry2 = rect_edge.end.y;

        const py = poly_edge.start.y;
        const px1 = poly_edge.start.x;
        const px2 = poly_edge.end.x;

        if (rx > px1 and rx < px2 and py > ry1 and py < ry2) {
            return true;
        }
    }

    return false;
}

pub fn main() !void {
    var out = std.fs.File.stdout().writerStreaming(&.{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var points = try parsePoints(allocator, input);
    defer points.deinit(allocator);

    const bbox = computeBoundingBox(points.items);
    try out.interface.print("Bounding box: ({d},{d}) to ({d},{d}), size: {d}x{d}\n", .{
        bbox.min.x, bbox.min.y, bbox.max.x, bbox.max.y, bbox.width(), bbox.height(),
    });
    try out.interface.print("Number of points: {d}\n\n", .{points.items.len});

    // Part 1: 4738108384
    // Time: 25583ns (25.58μs)
    var timer1 = try std.time.Timer.start();
    const result1 = partOne(points.items);
    const elapsed1 = timer1.read();

    try out.interface.print("Part 1: {d}\n", .{result1});
    try out.interface.print("Time: {d}ns ({d:.2}μs)\n\n", .{ elapsed1, @as(f64, @floatFromInt(elapsed1)) / 1000.0 });

    // Result: 1513792010
    // Time: 44945167ns (44945.17μs)
    var timer2 = try std.time.Timer.start();
    const result2 = try partTwo(points.items, allocator);
    const elapsed2 = timer2.read();

    try out.interface.print("Part 2 Result: {d}\n", .{result2});
    try out.interface.print("Part 2 Time: {d}ns ({d:.2}μs)\n\n", .{ elapsed2, @as(f64, @floatFromInt(elapsed2)) / 1000.0 });

    try out.interface.flush();
}