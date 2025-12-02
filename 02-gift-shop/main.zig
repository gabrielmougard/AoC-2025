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

// Time: 37838250ns (37838μs)
pub fn naiveMain() !void {
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


// Now the optimized approach: instead of checking every single number in each range to see if it's invalid,
// we directly generate and sum the invalid IDs that fall within each range.
//
// An invalid ID is formed by repeating a pattern twice.
// Mathematically, if the pattern has n digits, the invalid ID equals:
//     invalid_id = pattern × (10^n + 1)
//
// For example:
//   - pattern = 5   (1 digit) → 5 × 11 = 55
//   - pattern = 64  (2 digits) → 64 × 101 = 6464
//   - pattern = 123 (3 digits) → 123 × 1001 = 123123
//
// For each range [start, end]:
//   1. Try each possible even digit length (2, 4, 6, 8, ...) (note: as shown in the naive approach, we only need to check even digit lengths since an odd number of digits are necessarily valid)
//   2. For each length, calculate which patterns would produce invalid IDs that fall within the range
//   3. Use the arithmetic series formula to sum those invalid IDs in O(1) time
//
// For range [95, 115] looking for 2-digit invalid IDs:
//   - Pattern must be 1 digit (to make 2-digit invalid IDs)
//   - Multiplier = 10^1 + 1 = 11
//   - we need: 95 ≤ pattern × 11 ≤ 115
//   - so pattern belongs to {9} (since 9×11=99 is the only one in range)
//   - Sum = 99
//
// In terms of complexity:
//   - Time: O(D × N) where D ~ 10 (number of even digit lengths to check) and N is the number of ranges
//   - Space: O(1)
//
// To sum up:
//   - The naive approach: O(R) where R is the total size of all ranges
//   - This: O(D × N) ≈ O(10 × N)

fn sumInvalidIDsInRange(start: u64, end: u64) u64 {
    if (start > end) return 0;

    var sum: u64 = 0;

    const max_digits = if (end == 0) 1 else @as(u8, @intCast(std.math.log10_int(end) + 1));
    var num_digits: u8 = 2;
    while (num_digits <= max_digits) : (num_digits += 2) {
        const half_digits = num_digits / 2;
        const multiplier = std.math.pow(u64, 10, half_digits) + 1;
        const min_pattern = std.math.pow(u64, 10, half_digits - 1);
        const max_pattern = std.math.pow(u64, 10, half_digits) - 1;
        const pattern_start = @max(min_pattern, (start + multiplier - 1) / multiplier);
        const pattern_end = @min(max_pattern, end / multiplier);

        if (pattern_start <= pattern_end) {
            // arithmetic series formula: n(first + last)/2 (yay!)
            const count = pattern_end - pattern_start + 1;
            const sum_patterns = (pattern_start + pattern_end) * count / 2;
            sum += sum_patterns * multiplier;
        }
    }

    return sum;
}

pub fn optimizedMain() !void {
    var timer = try std.time.Timer.start();
    var out = std.fs.File.stdout().writerStreaming(&.{});

    var line_iter = std.mem.splitScalar(u8, input_data, '\n');
    var invalid_ids_sum: u64 = 0;

    while (line_iter.next()) |line| {
        if (line.len == 0) continue;

        var ranges_iter = std.mem.splitSequence(u8, line, ",");
        while (ranges_iter.next()) |range| {
            var parts = std.mem.splitSequence(u8, range, "-");
            const start = std.fmt.parseInt(u64, parts.next().?, 10) catch continue;
            const end = std.fmt.parseInt(u64, parts.next().?, 10) catch continue;
            if (end > 0) {
                invalid_ids_sum += sumInvalidIDsInRange(start, end - 1);
            }
        }
    }

    const elapsed = timer.read();

    try out.interface.print("Sum of invalid IDs: {d}\n", .{invalid_ids_sum});
    try out.interface.print("Time: {d}ns ({d}μs)\n", .{ elapsed, elapsed / 1000 });
}

// Sum of invalid IDs: 18595663903
pub fn main() !void {
    // Naive approach: sum all invalid IDs in each range
    // Time: 37838250ns (37838μs)
    naiveMain();

    // Optimized approach: generate and sum the invalid IDs that fall within each range
    // Time: 1875ns (1μs)
    optimizedMain();
}