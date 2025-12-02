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
pub fn naiveMainPartOne() !void {
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
//   - pattern = 5   (1 digit) -> 5 * 11 = 55
//   - pattern = 64  (2 digits) -> 64 * 101 = 6464
//   - pattern = 123 (3 digits) -> 123 * 1001 = 123123
//
// For each range [start, end]:
//   1. Try each possible even digit length (2, 4, 6, 8, ...) (note: as shown in the naive approach, we only need to check even digit lengths since an odd number of digits are necessarily valid)
//   2. For each length, calculate which patterns would produce invalid IDs that fall within the range
//   3. Use the arithmetic series formula to sum those invalid IDs in O(1) time
//
// For range [95, 115] looking for 2-digit invalid IDs:
//   - Pattern must be 1 digit (to make 2-digit invalid IDs)
//   - Multiplier = 10^1 + 1 = 11
//   - we need: 95 <= pattern × 11 <= 115
//   - so pattern belongs to {9} (since 9 * 11 = 99 is the only one in range)
//   - Sum = 99
//
// In terms of complexity:
//   - Time: O(D * N) where D ~ 10 (number of even digit lengths to check) and N is the number of ranges
//   - Space: O(1)
//
// To sum up:
//   - The naive approach: O(R) where R is the total size of all ranges
//   - This: O(D * N) ~ O(10 * N)

fn sumInvalidIDsInRangeNoDuplicates(start: u64, end: u64) u64 {
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

pub fn optimizedMainPartOne() !void {
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
                invalid_ids_sum += sumInvalidIDsInRangeNoDuplicates(start, end - 1);
            }
        }
    }

    const elapsed = timer.read();

    try out.interface.print("Sum of invalid IDs: {d}\n", .{invalid_ids_sum});
    try out.interface.print("Time: {d}ns ({d}μs)\n", .{ elapsed, elapsed / 1000 });
}

// For part 2, an invalid ID is now any number formed by
// repeating a pattern k times, where k >= 2.
//
// we basically need to avoid duplicates.
//   - 1111 = "1" repeated 4 times = "11" repeated 2 times
//   - 121212 = "12" repeated 3 times = "121212" repeated 1 time (but k must be >=2)
//
// We must only count patterns in their primitive form
// A pattern is primitive if it cannot be decomposed into a smaller repeating unit.
//   - "12" is primitive (can't be decomposed)
//   - "1212" is NOT primitive (it's "12" repeated)
//   - "1234" is primitive
//
// Based on this isPrimitive function, we can now sum the invalid IDs in the range with:
// For each pattern length p (1, 2, 3, ...):
//   For each number of repetitions k (2, 3, 4, ...):
//     For each p-digit pattern:
//       If pattern is primitive:
//         invalid_id = pattern × (1 + 10^p + 10^(2p) + ... + 10^((k-1)p))
//         If invalid_id is in range, add to sum
//
//   - Time: O(D * R * P) where D is max digits (~20), R is avg patterns per range, P is max repetitions (~10)
//   - Space: O(1)

// Checks if a pattern is primitive (cannot be decomposed into smaller repetitions)
// For example: 1234 is primitive, but 1212 is not (it's "12" repeated)
// Example:
//
// Testing pattern = 1234, length = 4
//
// Divisors of 4: [1, 2]
//
// Check divisor = 1:
//   - Extract first 1 digit: 1234 / 10^3 = 1234 / 1000 = 1
//   - If "1" repeated 4 times: 1 + 10 + 100 + 1000 = 1111
//   - Does 1111 is not 1234
//
// Check divisor = 2:
//   - Extract first 2 digits: 1234 / 10^2 = 1234 / 100 = 12
//   - If "12" repeated 2 times: 12 + 12×100 = 1212
//   - Does 1212 is not 1234
//
// Result: PRIMITIVE
//
// Testing pattern = 1111, length = 4
//
// Divisors of 4: [1, 2]
//
// Check divisor = 1:
//   - Extract first 1 digit: 1111 / 1000 = 1
//   - If "1" repeated 4 times: 1 + 10 + 100 + 1000 = 1111
//   - Does 1111 is equal to 1111
//
// Result: NOT PRIMITIVE
//
// Testing pattern = 123, length = 3
//
// Divisors of 3: [1]
//
// Check divisor = 1:
//   - Extract first 1 digit: 123 / 100 = 1
//   - If "1" repeated 3 times: 1 + 10 + 100 = 111
//   - Does 111 is not 123
//
// Result: PRIMITIVE
fn isPrimitive(pattern: u64, pattern_len: u8) bool {
    if (pattern_len == 1) return true;

    var divisor: u8 = 1;
    while (divisor <= pattern_len / 2) : (divisor += 1) {
        if (pattern_len % divisor == 0) {
            const sub_pattern = pattern / std.math.pow(u64, 10, pattern_len - divisor);

            const reps = pattern_len / divisor;
            const power_base = std.math.pow(u64, 10, divisor);
            var expected: u64 = 0;
            var p: u64 = 1;
            for (0..reps) |_| {
                expected += sub_pattern * p;
                p *= power_base;
            }

            if (expected == pattern) {
                return false;
            }
        }
    }

    return true;
}

fn sumInvalidIDsInRange(start: u64, end: u64) u64 {
    if (start > end) return 0;

    var sum: u64 = 0;
    const max_digits = if (end == 0) 1 else @as(u8, @intCast(std.math.log10_int(end) + 1));

    var pattern_len: u8 = 1;
    while (pattern_len <= max_digits) : (pattern_len += 1) {
        var num_reps: u8 = 2;
        while (pattern_len * num_reps <= max_digits) : (num_reps += 1) {
            const power_base = std.math.pow(u64, 10, pattern_len);
            var multiplier: u64 = 0;
            var p: u64 = 1;
            for (0..num_reps) |_| {
                multiplier += p;
                p *= power_base;
            }

            const min_pattern = if (pattern_len == 1) 1 else std.math.pow(u64, 10, pattern_len - 1);
            const max_pattern = std.math.pow(u64, 10, pattern_len) - 1;

            const pattern_start = @max(min_pattern, (start + multiplier - 1) / multiplier);
            const pattern_end = @min(max_pattern, end / multiplier);

            if (pattern_start <= pattern_end) {
                var pattern = pattern_start;
                while (pattern <= pattern_end) : (pattern += 1) {
                    if (isPrimitive(pattern, pattern_len)) {
                        const invalid_id = pattern * multiplier;
                        sum += invalid_id;
                    }
                }
            }
        }
    }

    return sum;
}

pub fn optimizedMainPartTwo() !void {
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

pub fn main() !void {
    // Naive approach: sum all invalid IDs in each range
    // Sum of invalid IDs: 18595663903
    // Time: 37838250ns (37838μs)
    try naiveMainPartOne();

    // Optimized approach: generate and sum the invalid IDs that fall within each range
    // Sum of invalid IDs: 18595663903
    // Time: 1875ns (1μs)
    try optimizedMainPartOne();

    // Now for part 2
    // Sum of invalid IDs: 19058204438
    // Time: 9083ns (9μs)
    try optimizedMainPartTwo();
}