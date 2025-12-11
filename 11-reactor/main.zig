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
pub fn partOne() !u64 {
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
    return countPathsSimple(&graph, &memo, "you");
}

// Recursively counts paths from `node` to "out" with memoization.
//
// Base case: "out" -> 1 (we've reached the destination)
// Recursive case: sum of paths from all children
fn countPathsSimple(
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
            total += countPathsSimple(graph, memo, child);
        }
    }

    memo.put(node, total) catch {};
    return total;
}

const CHECKPOINT_DAC: u2 = 0b01;
const CHECKPOINT_FFT: u2 = 0b10;
const CHECKPOINT_BOTH: u2 = 0b11;

// Counts paths from `node` to "out" that visit both checkpoints.
// `state` tracks which checkpoints have been visited so far (bitmask).
fn countPathsWithCheckpoints(
    graph: *std.StringHashMap(std.ArrayList([]const u8)),
    memo: *std.StringHashMap(u64),
    allocator: std.mem.Allocator,
    node: []const u8,
    state: u2,
) u64 {
    var current_state = state;
    if (std.mem.eql(u8, node, "dac")) {
        current_state |= CHECKPOINT_DAC;
    } else if (std.mem.eql(u8, node, "fft")) {
        current_state |= CHECKPOINT_FFT;
    }

    if (std.mem.eql(u8, node, "out")) {
        return if (current_state == CHECKPOINT_BOTH) 1 else 0;
    }

    const key = std.fmt.allocPrint(allocator, "{s}:{d}", .{ node, current_state }) catch return 0;
    if (memo.get(key)) |cached| {
        return cached;
    }

    var total: u64 = 0;
    if (graph.get(node)) |children| {
        for (children.items) |child| {
            total += countPathsWithCheckpoints(graph, memo, allocator, child, current_state);
        }
    }

    memo.put(key, total) catch {};
    return total;
}

// We use the same approach as part one, but this time the DFS needs to track which checkpoints have been visited.
// We need to track (node, visited_checkpoints_bitmask). For example:
//   - Bit 0: visited "dac"
//   - Bit 1: visited "fft"
//   - State 0b00: visited neither
//   - State 0b01: visited dac only
//   - State 0b10: visited fft only
//   - State 0b11: visited both (this is what we count at "out")
//
// We use (node_name, checkpoint_state) for out memoization key.
// Example trace for path svr->aaa->fft->ccc->eee->dac->fff->ggg->out:
//   svr (state=0b00) -> aaa (0b00) -> fft (0b10) -> ccc (0b10)
//   -> eee (0b10) -> dac (0b11) -> fff (0b11) -> ggg (0b11) -> out (0b11) OK
//
// Time comp: O((V + E) * 4) = O(V + E)
// Space comp: O(V * 4) = O(V)
pub fn partTwo() !u64 {
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
    return countPathsWithCheckpoints(&graph, &memo, allocator, "svr", 0);
}

pub fn main() !void {
    var timer = try std.time.Timer.start();
    var out = std.fs.File.stdout().writerStreaming(&.{});

    const result1 = try partOne();
    const e1 = timer.read();

    // Part 1: 448
    // Time: 71667ns (71μs)
    try out.interface.print("Part 1: {}\n", .{result1});
    try out.interface.print("Time: {d}ns ({d}μs)\n", .{ e1, e1 / 1000 });

    timer.reset();
    const result2 = try partTwo();
    const e2 = timer.read();

    // Part 2: 553204221431080
    // Time: 206583ns (206μs)
    try out.interface.print("Part 2: {}\n", .{result2});
    try out.interface.print("Time: {d}ns ({d}μs)\n", .{ e2, e2 / 1000 });
}