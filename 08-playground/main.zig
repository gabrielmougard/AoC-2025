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

fn minCompare(_: void, a: Edge, b: Edge) std.math.Order {
    return std.math.order(a.dist_sq, b.dist_sq);
}

const UnionFind = struct {
    parent: []u16,
    size: []u16,
    num_components: usize,

    fn init(allocator: std.mem.Allocator, n: usize) !UnionFind {
        const parent = try allocator.alloc(u16, n);
        const sz = try allocator.alloc(u16, n);
        for (0..n) |i| {
            parent[i] = @intCast(i);
            sz[i] = 1;
        }

        return .{ .parent = parent, .size = sz, .num_components = n };
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

    fn unite(self: *UnionFind, x: u16, y: u16) bool {
        const rx = self.find(x);
        const ry = self.find(y);
        if (rx == ry) return false;
        if (self.size[rx] < self.size[ry]) {
            self.parent[rx] = ry;
            self.size[ry] += self.size[rx];
        } else {
            self.parent[ry] = rx;
            self.size[rx] += self.size[ry];
        }

        self.num_components -= 1;
        return true;
    }
};

fn parsePoints(allocator: std.mem.Allocator) !std.ArrayList(Point) {
    var points = try std.ArrayList(Point).initCapacity(allocator, 1500);
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var parts = std.mem.tokenizeScalar(u8, line, ',');
        const x = try std.fmt.parseInt(i32, parts.next().?, 10);
        const y = try std.fmt.parseInt(i32, parts.next().?, 10);
        const z = try std.fmt.parseInt(i32, parts.next().?, 10);
        points.appendAssumeCapacity(.{ .x = x, .y = y, .z = z });
    }

    return points;
}

fn partOne(allocator: std.mem.Allocator, pts: []const Point) !u64 {
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
        _ = uf.unite(e.i, e.j);
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

    return top3[0] * top3[1] * top3[2];
}

fn partTwo(allocator: std.mem.Allocator, pts: []const Point) !u64 {
    const n = pts.len;
    const num_edges = (n * (n - 1)) / 2;
    var edges = try allocator.alloc(Edge, num_edges);
    defer allocator.free(edges);

    var idx: usize = 0;
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

            edges[idx] = .{ .dist_sq = d, .i = @intCast(i), .j = @intCast(j) };
            idx += 1;
        }
    }

    const len = edges.len;
    var i: usize = len / 2;
    while (i > 0) {
        i -= 1;
        siftDown(edges, i, len);
    }

    var uf = try UnionFind.init(allocator, n);
    defer uf.deinit(allocator);

    var last_edge: Edge = undefined;
    var heap_size = len;

    while (uf.num_components > 1 and heap_size > 0) {
        const e = edges[0];
        heap_size -= 1;
        if (heap_size > 0) {
            edges[0] = edges[heap_size];
            siftDown(edges, 0, heap_size);
        }

        if (uf.unite(e.i, e.j)) {
            last_edge = e;
        }
    }

    const x1: u64 = @intCast(pts[last_edge.i].x);
    const x2: u64 = @intCast(pts[last_edge.j].x);
    return x1 * x2;
}

fn siftDown(edges: []Edge, start: usize, len: usize) void {
    var root = start;
    while (true) {
        const left = 2 * root + 1;
        if (left >= len) break;

        var smallest = root;
        if (edges[left].dist_sq < edges[smallest].dist_sq) {
            smallest = left;
        }

        const right = left + 1;
        if (right < len and edges[right].dist_sq < edges[smallest].dist_sq) {
            smallest = right;
        }

        if (smallest == root) break;

        const tmp = edges[root];
        edges[root] = edges[smallest];
        edges[smallest] = tmp;
        root = smallest;
    }
}

pub fn main() !void {
    var out = std.fs.File.stdout().writerStreaming(&.{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var points = try parsePoints(allocator);
    defer points.deinit(allocator);
    const pts = points.items;

    var t1 = try std.time.Timer.start();
    const result1 = try partOne(allocator, pts);
    const elapsed1 = t1.read();

    // Part 1: 352584
    // Time: 517166ns (517.17μs)
    try out.interface.print("Part 1: {d}\n", .{result1});
    try out.interface.print("Time: {d}ns ({d:.2}μs)\n\n", .{ elapsed1, @as(f64, @floatFromInt(elapsed1)) / 1000.0 });

    var t2 = try std.time.Timer.start();
    const result2 = try partTwo(allocator, pts);
    const elapsed2 = t2.read();

    // Part 2: 9617397716
    // Time: 3169000ns (3169.00μs)
    try out.interface.print("Part 2: {d}\n", .{result2});
    try out.interface.print("Time: {d}ns ({d:.2}μs)\n\n", .{ elapsed2, @as(f64, @floatFromInt(elapsed2)) / 1000.0 });

    try out.interface.print("Total: {d:.2}μs\n", .{@as(f64, @floatFromInt(elapsed1 + elapsed2)) / 1000.0});
}