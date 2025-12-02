const std = @import("std");

const input_data = @embedFile("input.txt");

fn countDigits(id: u64) u8 {
    if (id == 0) return 1;
    return @intCast(std.math.log10_int(id) + 1);
}

fn isValidID(id: u64, valids: *std.AutoHashMap(u64, bool)) bool {
    const digits = countDigits(id);
    if (digits % 2 == 1) return true; // number if an odd number of digits are necessarily valid since we can't have a symmetric digit sequence

    // check if we've already computed this ID
    if (valids.get(id)) |valid| {
        return valid;
    }

    // split the ID into two halves and check if the halves are the same
    const half = digits / 2;
    const first_half = id / std.math.pow(u64, 10, half);
    const second_half = id % std.math.pow(u64, 10, half);
    if (first_half == second_half) {
        valids.put(id, false) catch unreachable;
        return false;
    }

    valids.put(id, true) catch unreachable;
    return true;
}

// Sum of invalid IDs: 18595663903
// Time: 37838250ns (37838μs)
pub fn main() !void {
    var timer = try std.time.Timer.start();
    var out = std.fs.File.stdout().writerStreaming(&.{});

    var line_iter = std.mem.splitScalar(u8, input_data, '\n');
    var valids = std.AutoHashMap(u64, bool).init(std.heap.page_allocator);
    var invalid_ids_sum: u64 = 0;

    while (line_iter.next()) |line| {
        if (line.len == 0) continue;

        var ranges_iter = std.mem.splitSequence(u8, line, ",");
        while (ranges_iter.next()) |range| {
            var parts = std.mem.splitSequence(u8, range, "-");
            const start = std.fmt.parseInt(u64, parts.next().?, 10) catch continue;
            const end = std.fmt.parseInt(u64, parts.next().?, 10) catch continue;
            for (start..end) |i| {
                if (!isValidID(i, &valids)) {
                    invalid_ids_sum += i;
                }
            }
        }
    }

    const elapsed = timer.read();

    try out.interface.print("Sum of invalid IDs: {d}\n", .{invalid_ids_sum});
    // try out.interface.print("Password (click method): {d}\n", .{total_zero_clicks});
    try out.interface.print("Time: {d}ns ({d}μs)\n", .{ elapsed, elapsed / 1000 });
}