const std = @import("std");

const input_data = @embedFile("input.txt");

// Each machine has indicator lights (initially all off) that must match a target pattern.
// Buttons toggle specific lights when pressed. We need the minimum total button presses
// across all machines to achieve their target patterns.
//
// 1) Parse each machine's target pattern and button configurations
// 2) For each machine, find minimum buttons needed using combination enumeration
// 3) Sum the minimum presses across all machines
//
// Example:
//   [.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}
//   - Target: lights 1,2 ON (0-indexed), lights 0,3 OFF -> bitmask 0b0110 = 6
//   - Button (0,1) toggles lights 0 and 1 -> bitmask 0b0011 = 3
//   - Joltage {3,5,4,7} is ignored
//
// Time comp: O(M * sum(C(n_i, k))) where M = machines, n_i = buttons per machine
// Space comp: O(1) -> only fixed-size arrays used
pub fn solve() !u64 {
    var total: u64 = 0;
    var lines = std.mem.tokenizeScalar(u8, input_data, '\n');
    while (lines.next()) |line| {
        total += try solveMachine(line);
    }

    return total;
}

// Example: [.##.] -> target = 0b0110 (lights 1,2 on)
//          (0,2)  button mask = 0b0101 (toggles lights 0,2)
//
// Time comp: O(L + 2^n) where L = line length, n = number of buttons
// Space comp: O(n) for button storage
fn solveMachine(line: []const u8) !u32 {
    var target: u16 = 0;
    var buttons: [64]u16 = undefined;
    var num_buttons: usize = 0;

    var i: usize = 0;
    if (line[i] != '[') return error.ParseError;
    i += 1;
    var bit_pos: u4 = 0;
    while (line[i] != ']') : (i += 1) {
        if (line[i] == '#') {
            target |= @as(u16, 1) << bit_pos;
        }

        bit_pos += 1;
    }

    i += 1; // skip ']'
    while (i < line.len) {
        if (line[i] == '(') {
            i += 1;
            var mask: u16 = 0;
            while (line[i] != ')') {
                if (line[i] >= '0' and line[i] <= '9') {
                    var num: u16 = 0;
                    while (i < line.len and line[i] >= '0' and line[i] <= '9') {
                        num = num * 10 + (line[i] - '0');
                        i += 1;
                    }

                    mask |= @as(u16, 1) << @intCast(num);
                } else {
                    i += 1;
                }
            }

            buttons[num_buttons] = mask;
            num_buttons += 1;
            i += 1; // skip ')'
        } else if (line[i] == '{') {
            break;
        } else {
            i += 1;
        }
    }

    return findMinButtons(buttons[0..num_buttons], target);
}

// This finds the minimum number of buttons whose XOR equals target.
// Since toggling is XOR, pressing a button twice cancels out. Therefore, each button is either pressed once or not at all.
// We need the smallest subset of buttons where XOR of all masks in subset = target.
// We enumerate combinations by size (1, 2, 3, ...) until solution is found.
//
// Example: buttons = [0b0101, 0b0011, 0b0110], target = 0b0110
//   k=1: try each button alone
//        0b0110 == target OK -> return 1
//
// Example: buttons = [0b0001, 0b0010, 0b0100], target = 0b0011
//   k=1: 0b0001 != 0b0011, 0b0010 != 0b0011, 0b0100 != 0b0011
//   k=2: 0b0001 XOR 0b0010 = 0b0011 == target OK -> return 2
//
// Time comp: O(C(n,1) + C(n,2) + ... + C(n,k)) where k is the answer. Worst case O(2^n), but typically O(n^2) since k is small
// Space comp: O(k) for combination indices
fn findMinButtons(buttons: []const u16, target: u16) u32 {
    if (target == 0) return 0;

    const n = buttons.len;
    for (1..n + 1) |k| {
        if (tryKButtons(buttons, target, n, k)) {
            return @intCast(k);
        }
    }

    return 255;
}

// Tests if target can be achieved with exactly k button presses.
// For each combination, XORs the corresponding button masks and checks against target.
//
// Example for n=4, k=2:
//   [0,1] -> [0,2] -> [0,3] -> [1,2] -> [1,3] -> [2,3]
//
// Example: n=5, k=3, indices=[0,2,4]
//   - Index 2 (value 4) can't increment (max is 4)
//   - Index 1 (value 2) can increment to 3
//   - Result: [0,3,4]
//
// Time comp: O(C(n,k) * k) -> enumerate all combinations, k XORs each
// Space comp: O(k) for indices array
fn tryKButtons(buttons: []const u16, target: u16, n: usize, k: usize) bool {
    var indices: [20]usize = undefined;
    for (0..k) |i| {
        indices[i] = i;
    }

    while (true) {
        var xor_val: u16 = 0;
        for (0..k) |i| {
            xor_val ^= buttons[indices[i]];
        }

        if (xor_val == target) {
            return true;
        }

        var i: usize = k;
        while (i > 0) {
            i -= 1;
            if (indices[i] < n - k + i) {
                indices[i] += 1;
                for (i + 1..k) |j| {
                    indices[j] = indices[j - 1] + 1;
                }

                break;
            }
        } else {
            return false;
        }
    }
}

pub fn main() !void {
    var timer = try std.time.Timer.start();
    const result = try solve();
    const elapsed = timer.read();
    var out = std.fs.File.stdout().writerStreaming(&.{});
    // 434
    // Time: 69375ns (69μs)
    try out.interface.print("{}\n", .{result});
    try out.interface.print("Time: {d}ns ({d}μs)\n", .{ elapsed, elapsed / 1000 });
}