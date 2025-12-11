const std = @import("std");

const input_data = @embedFile("input.txt");

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

// Example: [.##.] -> target = 0b0110 (lights 1,2 on)
//          (0,2)  button mask = 0b0101 (toggles lights 0,2)
//
// Time comp: O(L + 2^n) where L = line length, n = number of buttons
// Space comp: O(n) for button storage
fn partOneMachine(line: []const u8) !u32 {
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
pub fn partOne() !u64 {
    var total: u64 = 0;
    var lines = std.mem.tokenizeScalar(u8, input_data, '\n');
    while (lines.next()) |line| {
        total += try partOneMachine(line);
    }

    return total;
}

///// Part 2 /////

const MAX_BUTTONS = 20;
const MAX_COUNTERS = 16;

// This models a rational number for exact arithmetic during Gaussian elimination
const Rational = struct {
    num: i64,
    den: i64,

    fn init(n: i64, d: i64) Rational {
        if (d == 0) return .{ .num = 0, .den = 1 };
        var num = n;
        var den = d;
        if (den < 0) {
            num = -num;
            den = -den;
        }

        const g = gcd(@abs(num), @abs(den));
        return .{ .num = @divTrunc(num, @as(i64, @intCast(g))), .den = @divTrunc(den, @as(i64, @intCast(g))) };
    }

    fn gcd(a: u64, b: u64) u64 {
        var x = a;
        var y = b;
        while (y != 0) {
            const t = y;
            y = x % y;
            x = t;
        }

        return if (x == 0) 1 else x;
    }

    fn add(self: Rational, other: Rational) Rational {
        return init(self.num * other.den + other.num * self.den, self.den * other.den);
    }

    fn sub(self: Rational, other: Rational) Rational {
        return init(self.num * other.den - other.num * self.den, self.den * other.den);
    }

    fn mul(self: Rational, other: Rational) Rational {
        return init(self.num * other.num, self.den * other.den);
    }

    fn div(self: Rational, other: Rational) Rational {
        return init(self.num * other.den, self.den * other.num);
    }

    fn isZero(self: Rational) bool {
        return self.num == 0;
    }

    fn toInt(self: Rational) ?i64 {
        if (@rem(self.num, self.den) != 0) return null;
        return @divTrunc(self.num, self.den);
    }

    fn fromInt(n: i64) Rational {
        return .{ .num = n, .den = 1 };
    }
};

// Matrix A[counter][button] = 1 if button affects counter, 0 otherwise
// Find x >= 0 minimizing sum(x) such that A*x = targets
//
// 1) Build augmented matrix [A | targets]
// 2) Gaussian elimination to row echelon form
// 3) Identify pivot (dependent) and free variables
// 4) Express solution as: x_pivot = f(free variables)
// 5) Search over non-negative integer values of free variables
//
// The search is bounded because free variables can't exceed max(targets).
fn solveSystem(buttons: []const u32, targets: []const u32) !u64 {
    const num_buttons = buttons.len;
    const num_counters = targets.len;

    // Build augmented matrix [A | b] as rationals
    // Rows = counters, Cols = buttons + 1 (for target)
    var matrix: [MAX_COUNTERS][MAX_BUTTONS + 1]Rational = undefined;

    for (0..num_counters) |row| {
        for (0..num_buttons) |col| {
            const bit = @as(u5, @intCast(row));
            matrix[row][col] = if ((buttons[col] >> bit) & 1 == 1)
                Rational.fromInt(1)
            else
                Rational.fromInt(0);
        }
        matrix[row][num_buttons] = Rational.fromInt(@intCast(targets[row]));
    }

    // Gaussian elimination with partial pivoting
    var pivot_col: [MAX_COUNTERS]i32 = .{-1} ** MAX_COUNTERS; // which column is pivot for each row
    var current_row: usize = 0;

    for (0..num_buttons) |col| {
        // Find pivot row
        var pivot_row: ?usize = null;
        for (current_row..num_counters) |row| {
            if (!matrix[row][col].isZero()) {
                pivot_row = row;
                break;
            }
        }

        if (pivot_row) |pr| {
            // Swap rows
            if (pr != current_row) {
                for (0..num_buttons + 1) |c| {
                    const tmp = matrix[current_row][c];
                    matrix[current_row][c] = matrix[pr][c];
                    matrix[pr][c] = tmp;
                }
            }

            // Scale pivot row
            const pivot_val = matrix[current_row][col];
            for (0..num_buttons + 1) |c| {
                matrix[current_row][c] = matrix[current_row][c].div(pivot_val);
            }

            // Eliminate column in other rows
            for (0..num_counters) |row| {
                if (row != current_row and !matrix[row][col].isZero()) {
                    const factor = matrix[row][col];
                    for (0..num_buttons + 1) |c| {
                        matrix[row][c] = matrix[row][c].sub(factor.mul(matrix[current_row][c]));
                    }
                }
            }

            pivot_col[current_row] = @intCast(col);
            current_row += 1;
        }
    }

    const num_pivots = current_row;

    // Check for inconsistency (row of form [0 0 ... 0 | nonzero])
    for (num_pivots..num_counters) |row| {
        if (!matrix[row][num_buttons].isZero()) {
            return error.NoSolution;
        }
    }

    // Identify free variables
    var is_pivot: [MAX_BUTTONS]bool = .{false} ** MAX_BUTTONS;
    for (0..num_pivots) |row| {
        if (pivot_col[row] >= 0) {
            is_pivot[@intCast(pivot_col[row])] = true;
        }
    }

    var free_vars: [MAX_BUTTONS]usize = undefined;
    var num_free: usize = 0;
    for (0..num_buttons) |col| {
        if (!is_pivot[col]) {
            free_vars[num_free] = col;
            num_free += 1;
        }
    }

    // Find max target for bounding search
    var max_target: u32 = 0;
    for (targets) |t| {
        if (t > max_target) max_target = t;
    }

    // Search over free variables
    // Each free variable can range from 0 to max_target
    const bound: u64 = @min(max_target + 1, 300); // reasonable bound

    var min_cost: u64 = std.math.maxInt(u64);

    // Enumerate all combinations of free variables
    var free_vals: [MAX_BUTTONS]u64 = .{0} ** MAX_BUTTONS;

    while (true) {
        // Compute dependent variables from free variables
        var solution: [MAX_BUTTONS]Rational = undefined;
        for (0..num_buttons) |col| {
            solution[col] = Rational.fromInt(0);
        }

        // Set free variables
        for (0..num_free) |f| {
            solution[free_vars[f]] = Rational.fromInt(@intCast(free_vals[f]));
        }

        // Compute pivot variables (back substitution)
        var valid = true;
        var row_idx: usize = num_pivots;
        while (row_idx > 0) {
            row_idx -= 1;
            const col: usize = @intCast(pivot_col[row_idx]);
            var val = matrix[row_idx][num_buttons];

            for (col + 1..num_buttons) |c| {
                val = val.sub(matrix[row_idx][c].mul(solution[c]));
            }

            solution[col] = val;
        }

        // Check if solution is valid (non-negative integers)
        var cost: u64 = 0;
        for (0..num_buttons) |col| {
            if (solution[col].toInt()) |v| {
                if (v < 0) {
                    valid = false;
                    break;
                }
                cost += @intCast(v);
            } else {
                valid = false;
                break;
            }
        }

        if (valid and cost < min_cost) {
            min_cost = cost;
        }

        // Increment free variables (odometer style)
        var carry = true;
        for (0..num_free) |f| {
            if (carry) {
                free_vals[f] += 1;
                if (free_vals[f] >= bound) {
                    free_vals[f] = 0;
                } else {
                    carry = false;
                }
            }
        }

        if (carry) break; // All combinations exhausted
    }

    if (min_cost == std.math.maxInt(u64)) {
        return error.NoSolution;
    }

    return min_cost;
}

// Example: [.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}
//   - Buttons: (3) -> affects counter 3, (1,3) -> affects counters 1,3, etc.
//   - Targets: counter 0=3, counter 1=5, counter 2=4, counter 3=7
//   - Find x0,x1,x2,x3,x4,x5 >= 0 minimizing sum, where:
//     counter0: x4 + x5 = 3
//     counter1: x1 + x5 = 5
//     counter2: x2 + x3 + x4 = 4
//     counter3: x0 + x1 + x3 = 7
fn partTwoMachine(line: []const u8) !u64 {
    var buttons: [MAX_BUTTONS]u32 = undefined; // bitmask of counters affected
    var num_buttons: usize = 0;
    var targets: [MAX_COUNTERS]u32 = undefined;
    var num_counters: usize = 0;

    var i: usize = 0;

    // Skip indicator pattern [...]
    while (i < line.len and line[i] != ']') : (i += 1) {}
    i += 1;

    // Parse buttons (0,1,3) ...
    while (i < line.len) {
        if (line[i] == '(') {
            i += 1;
            var mask: u32 = 0;
            while (line[i] != ')') {
                if (line[i] >= '0' and line[i] <= '9') {
                    var num: u32 = 0;
                    while (i < line.len and line[i] >= '0' and line[i] <= '9') {
                        num = num * 10 + (line[i] - '0');
                        i += 1;
                    }
                    mask |= @as(u32, 1) << @intCast(num);
                } else {
                    i += 1;
                }
            }
            buttons[num_buttons] = mask;
            num_buttons += 1;
            i += 1;
        } else if (line[i] == '{') {
            i += 1;
            // Parse targets {3,5,4,7}
            while (line[i] != '}') {
                if (line[i] >= '0' and line[i] <= '9') {
                    var num: u32 = 0;
                    while (i < line.len and line[i] >= '0' and line[i] <= '9') {
                        num = num * 10 + (line[i] - '0');
                        i += 1;
                    }
                    targets[num_counters] = num;
                    num_counters += 1;
                } else {
                    i += 1;
                }
            }
            break;
        } else {
            i += 1;
        }
    }

    return solveSystem(buttons[0..num_buttons], targets[0..num_counters]);
}

// This is an Integer Linear Programming problem:
//   Given matrix A (button-counter incidence) and target vector b,
//   find x >= 0 minimizing sum(x) such that A*x = b
//
// 1) Parse buttons and targets into matrix form
// 2) Use Gaussian elimination to find solution space
// 3) Search over free variables to find minimum-cost solution
//
// Time comp: O(M * (n^3 + k * 2^f)) where M=machines, n=counters,
//                  f=free variables after elimination, k=search bound
// Space comp: O(n * m) for the matrix
pub fn partTwo() !u64 {
    var total: u64 = 0;
    var lines = std.mem.tokenizeScalar(u8, input_data, '\n');
    while (lines.next()) |line| {
        total += try partTwoMachine(line);
    }

    return total;
}

pub fn main() !void {
    var timer = try std.time.Timer.start();
    const result1 = try partOne();
    const e1 = timer.read();
    var out = std.fs.File.stdout().writerStreaming(&.{});
    // 434
    // Time: 69375ns (69μs)
    try out.interface.print("Part 1: {}\n", .{result1});
    try out.interface.print("Time: {d}ns ({d}μs)\n", .{ e1, e1 / 1000 });

    timer = try std.time.Timer.start();
    const result2 = try partTwo();
    const e2 = timer.read();
    // Part 2: 15132
    // Time: 9399645958ns (9399645μs) -> ~9.4s
    try out.interface.print("Part 2: {}\n", .{result2});
    try out.interface.print("Time: {d}ns ({d}μs)\n", .{ e2, e2 / 1000 });
}