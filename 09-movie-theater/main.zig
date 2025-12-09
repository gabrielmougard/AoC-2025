const std = @import("std");

const input = @embedFile("input.txt");

const Point = struct {
    x: i32,
    y: i32,
};

pub fn main() !void {
    var timer = try std.time.Timer.start();
    var out = std.fs.File.stdout().writerStreaming(&.{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var points: std.ArrayList(Point) = .empty;
    defer points.deinit(allocator);

    var lines = std.mem.tokenizeAny(u8, input, "\n\r");
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var parts = std.mem.tokenizeAny(u8, line, ",");
        const x_str = parts.next() orelse continue;
        const y_str = parts.next() orelse continue;

        const x = std.fmt.parseInt(i32, x_str, 10) catch continue;
        const y = std.fmt.parseInt(i32, y_str, 10) catch continue;

        try points.append(allocator, Point{ .x = x, .y = y });
    }

    var max_area: i64 = 0;

    const pts = points.items;
    for (0..pts.len) |i| {
        for ((i + 1)..pts.len) |j| {
            const p1 = pts[i];
            const p2 = pts[j];

            const dx = @abs(p2.x - p1.x)+1;
            const dy = @abs(p2.y - p1.y)+1;

            const area: i64 = @as(i64, dx) * @as(i64, dy);

            if (area > max_area) {
                max_area = area;
            }
        }
    }

    const elapsed = timer.read();

    try out.interface.print("Result: {d}\n", .{max_area});
    try out.interface.print("Time: {d}ns ({d:.2}μs)\n\n", .{ elapsed, @as(f64, @floatFromInt(elapsed)) / 1000.0 });
}