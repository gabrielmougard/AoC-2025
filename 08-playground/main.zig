const std = @import("std");

const input = @embedFile("input.txt");

const Point = struct {
    x: i32,
    y: i32,
    z: i32,
};

const Edge = struct {
    dist_sq: i64,
    i: u16,
    j: u16,
};

fn maxCompare(_: void, a: Edge, b: Edge) std.math.Order {
    return std.math.order(b.dist_sq, a.dist_sq);
}

const UnionFind = struct {
    parent: []u16,
    size: []u16,

    fn init(allocator: std.mem.Allocator, n: usize) !UnionFind {
        const parent = try allocator.alloc(u16, n);
        const sz = try allocator.alloc(u16, n);
        for (0..n) |i| {
            parent[i] = @intCast(i);
            sz[i] = 1;
        }

        return .{ .parent = parent, .size = sz };
    }

    fn deinit(self: *UnionFind, allocator: std.mem.Allocator) void {
        allocator.free(self.parent);
        allocator.free(self.size);
    }

    fn find(self: *UnionFind, x: u16) u16 {
        var current = x;
        while (self.parent[current] != current) {
            self.parent[current] = self.parent[self.parent[current]];
            current = self.parent[current];
        }

        return current;
    }

    fn unite(self: *UnionFind, x: u16, y: u16) void {
        const rx = self.find(x);
        const ry = self.find(y);
        if (rx == ry) return;

        if (self.size[rx] < self.size[ry]) {
            self.parent[rx] = ry;
            self.size[ry] += self.size[rx];
        } else {
            self.parent[ry] = rx;
            self.size[rx] += self.size[ry];
        }
    }
};

pub fn main() !void {
    var out = std.fs.File.stdout().writerStreaming(&.{});
    var t = try std.time.Timer.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var points = try std.ArrayList(Point).initCapacity(allocator, 1000);
    defer points.deinit(allocator);

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var parts = std.mem.tokenizeScalar(u8, line, ',');
        const x = try std.fmt.parseInt(i32, parts.next().?, 10);
        const y = try std.fmt.parseInt(i32, parts.next().?, 10);
        const z = try std.fmt.parseInt(i32, parts.next().?, 10);
        points.appendAssumeCapacity(.{ .x = x, .y = y, .z = z });
    }

    const pts = points.items;
    const n = pts.len;
    const k: usize = 1000;

    var heap = std.PriorityQueue(Edge, void, maxCompare).init(allocator, {});
    defer heap.deinit();
    try heap.ensureTotalCapacity(k + 1);

    var max_dist: i64 = std.math.maxInt(i64);

    for (0..n) |i| {
        const pi = pts[i];
        const pi_x: i64 = pi.x;
        const pi_y: i64 = pi.y;
        const pi_z: i64 = pi.z;

        for (i + 1..n) |j| {
            const pj = pts[j];
            const dx = pi_x - @as(i64, pj.x);
            const dy = pi_y - @as(i64, pj.y);
            const dz = pi_z - @as(i64, pj.z);
            const d = dx * dx + dy * dy + dz * dz;

            if (d >= max_dist) continue;

            heap.add(.{ .dist_sq = d, .i = @intCast(i), .j = @intCast(j) }) catch unreachable;
            if (heap.count() > k) {
                _ = heap.remove();
                max_dist = heap.peek().?.dist_sq;
            }
        }
    }

    var edges: [k]Edge = undefined;
    var idx: usize = heap.count();
    const edge_count = idx;
    while (heap.removeOrNull()) |e| {
        idx -= 1;
        edges[idx] = e;
    }

    std.mem.sort(Edge, edges[0..edge_count], {}, struct {
        fn lt(_: void, a: Edge, b: Edge) bool {
            return a.dist_sq < b.dist_sq;
        }
    }.lt);

    var uf = try UnionFind.init(allocator, n);
    defer uf.deinit(allocator);

    for (edges[0..edge_count]) |e| {
        uf.unite(e.i, e.j);
    }

    var top3 = [3]u64{ 0, 0, 0 };
    for (0..n) |i| {
        if (uf.parent[i] == @as(u16, @intCast(i))) {
            const sz: u64 = uf.size[i];
            if (sz > top3[0]) {
                top3[2] = top3[1];
                top3[1] = top3[0];
                top3[0] = sz;
            } else if (sz > top3[1]) {
                top3[2] = top3[1];
                top3[1] = sz;
            } else if (sz > top3[2]) {
                top3[2] = sz;
            }
        }
    }

    const result = top3[0] * top3[1] * top3[2];
    const elapsed = t.read();

    // Result: 352584
    // Time: 556000ns (556.00μs)
    try out.interface.print("Result: {d}\n", .{result});
    try out.interface.print("Time: {d}ns ({d:.2}μs)\n", .{ elapsed, @as(f64, @floatFromInt(elapsed)) / 1000.0 });
}