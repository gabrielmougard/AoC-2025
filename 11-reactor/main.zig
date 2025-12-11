const std = @import("std");

const input_data = @embedFile("input.txt");

// Count all distinct paths from "you" to "out" in a directed graph.
// Data flows only forward, so this is a DAG. We use DFS with memoization:
//   - pathCount(node) = sum of pathCount(child) for all children
//   - Base case: pathCount("out") = 1
//   - Memoize results to avoid recomputation
//
// Example:
//   you -> bbb -> ddd -> ggg -> out
//              -> eee -> out
//       -> ccc -> ddd -> ggg -> out
//              -> eee -> out
//              -> fff -> out
//
//   pathCount(out) = 1
//   pathCount(ggg) = pathCount(out) = 1
//   pathCount(eee) = pathCount(out) = 1
//   pathCount(fff) = pathCount(out) = 1
//   pathCount(ddd) = pathCount(ggg) = 1
//   pathCount(bbb) = pathCount(ddd) + pathCount(eee) = 1 + 1 = 2
//   pathCount(ccc) = pathCount(ddd) + pathCount(eee) + pathCount(fff) = 1 + 1 + 1 = 3
//   pathCount(you) = pathCount(bbb) + pathCount(ccc) = 2 + 3 = 5
//
// Time comp: O(V + E) -> each node and edge visited once
// Space comp: O(V) for memoization table
pub fn solve() !u64 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var graph = std.StringHashMap(std.ArrayList([]const u8)).init(allocator);
    var lines = std.mem.tokenizeScalar(u8, input_data, '\n');
    while (lines.next()) |line| {
        var parts = std.mem.tokenizeSequence(u8, line, ": ");
        const node_name = parts.next() orelse continue;
        var children: std.ArrayList([]const u8) = .empty;
        if (parts.next()) |rest| {
            var child_iter = std.mem.tokenizeScalar(u8, rest, ' ');
            while (child_iter.next()) |child| {
                try children.append(allocator, child);
            }
        }

        try graph.put(node_name, children);
    }

    var memo = std.StringHashMap(u64).init(allocator);
    return countPaths(&graph, &memo, "you");
}

// Recursively counts paths from `node` to "out" with memoization.
//
// Base case: "out" -> 1 (we've reached the destination)
// Recursive case: sum of paths from all children
fn countPaths(
    graph: *std.StringHashMap(std.ArrayList([]const u8)),
    memo: *std.StringHashMap(u64),
    node: []const u8,
) u64 {
    if (std.mem.eql(u8, node, "out")) {
        return 1;
    }

    if (memo.get(node)) |cached| {
        return cached;
    }

    var total: u64 = 0;
    if (graph.get(node)) |children| {
        for (children.items) |child| {
            total += countPaths(graph, memo, child);
        }
    }

    memo.put(node, total) catch {};
    return total;
}

pub fn main() !void {
    var timer = try std.time.Timer.start();
    var out = std.fs.File.stdout().writerStreaming(&.{});

    const result = try solve();
    const elapsed = timer.read();

    try out.interface.print("Result: {}\n", .{result});
    try out.interface.print("Time: {d}ns ({d}μs)\n", .{ elapsed, elapsed / 1000 });
}