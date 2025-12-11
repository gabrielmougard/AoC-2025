const std = @import("std");

const input_data = @embedFile("input.txt");

// Part 1 is very much a XOR subset problem:
// each machine has indicator lights (initially OFF) that must match a
// target pattern. Buttons toggle specific lights when pressed. Find the minimum
// total button presses across all machines. Toggling is XOR -> pressing a button twice cancels out.
// Therefore, each button is pressed 0 or 1 times.
// We need the smallest subset of buttons where XOR(masks in subset) = target.
// Let's enumerate combinations by size k = 1, 2, 3, ... until found.
// This guarantees minimum since we check smaller sizes first.
//
// Example: [.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}
//   - Target pattern [.##.]: lights 1,2 ON -> bitmask 0b0110
//   - Button (0,1): toggles lights 0,1 -> bitmask 0b0011
//   - Button (2,3): toggles lights 2,3 -> bitmask 0b1100
//   - Joltage {3,5,4,7}: ignored in Part 1
//
// Example: buttons = [0b0101, 0b0011, 0b0110], target = 0b0110
//   k=1: check each button alone -> 0b0110 == target OK -> return 1
//
//   buttons = [0b0001, 0b0010, 0b0100], target = 0b0011
//   k=1: none match
//   k=2: 0b0001 XOR 0b0010 = 0b0011 == target OK -> return 2
//
// Time comp: O(C(n,1) + C(n,2) + ... + C(n,k)) where k = answer
//                  Worst case O(2^n), typically O(n²) since k is small
// Space comp: O(n) for button storage, O(k) for combination indices

// Finds minimum number of buttons whose XOR equals target.
// Returns 0 if target is already 0, 255 if no solution exists.
fn findMinXorSubset(buttons: []const u16, target: u16) u32 {
    if (target == 0) return 0;

    const n = buttons.len;
    for (1..n + 1) |k| {
        if (hasKButtonSolution(buttons, target, n, k)) {
            return @intCast(k);
        }
    }

    return 255;
}

// Tests if target can be achieved with exactly k button presses.
// Uses lexicographic combination generation.
//
// Combination iteration for n=4, k=2:
//   [0,1] -> [0,2] -> [0,3] -> [1,2] -> [1,3] -> [2,3]
//
// Increment logic: Find rightmost index that can increase, increment it,
// then reset all following indices to consecutive values.
//   Example: n=5, k=3, [0,2,4] -> index 1 can increment -> [0,3,4]
fn hasKButtonSolution(buttons: []const u16, target: u16, n: usize, k: usize) bool {
    var indices: [20]usize = undefined;
    for (0..k) |i| {
        indices[i] = i;
    }

    while (true) {
        var xor_val: u16 = 0;
        for (0..k) |i| {
            xor_val ^= buttons[indices[i]];
        }

        if (xor_val == target) return true;

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

// Format: [.##.] (0,1) (2,3) ... {joltage}
//   - [.##.]: '.' = OFF, '#' = ON -> bit i set if light i should be ON
//   - (0,1): button toggles lights 0 and 1 -> bitmask with bits 0,1 set
fn solvePartOneMachine(line: []const u8) !u32 {
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

    i += 1;
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
            i += 1;
        } else if (line[i] == '{') {
            break;
        } else {
            i += 1;
        }
    }

    return findMinXorSubset(buttons[0..num_buttons], target);
}

pub fn partOne() !u64 {
    var total: u64 = 0;
    var lines = std.mem.tokenizeScalar(u8, input_data, '\n');
    while (lines.next()) |line| {
        total += try solvePartOneMachine(line);
    }
    return total;
}

// Part 2 is an integer linear programming problem:
// each machine has counters (initially 0) that must reach target values.
// Buttons increment specific counters by 1 each press. Buttons can be pressed
// multiple times. Find minimum total presses across all machines.
//
//   Given: Matrix A where A[i][j] = 1 if button j affects counter i
//          Target vector b (desired counter values)
//   Find:  Vector x ≥ 0 (button press counts) minimizing sum(x)
//          Subject to: A·x = b
//
// Example: [.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}
//   - Buttons: (3)→counter 3, (1,3)→counters 1,3, (2)→counter 2, etc.
//   - Targets: {3,5,4,7} → counter[0]=3, counter[1]=5, counter[2]=4, counter[3]=7
//
//   System of equations (button variables x0..x5):
//     counter 0: x4 + x5 = 3        (buttons (0,2) and (0,1) affect counter 0)
//     counter 1: x1 + x5 = 5        (buttons (1,3) and (0,1) affect counter 1)
//     counter 2: x2 + x3 + x4 = 4   (buttons (2), (2,3), (0,2) affect counter 2)
//     counter 3: x0 + x1 + x3 = 7   (buttons (3), (1,3), (2,3) affect counter 3)
//
//   1) Build augmented matrix [A | b]
//   2) Gaussian elimination -> reduced row echelon form (using exact rational arithmetic)
//   3) Identify pivot variables (determined) and free variables (can vary)
//   4) Search over non-negative integer values of free variables
//   5) For each assignment, back-substitute to get pivot variables
//   6) Track minimum total cost among valid (all non-negative integer) solutions
//
// Example Gaussian Elimination:
//   Original:  [1 0 0 0 1 1 | 3]   (counter 0 equation)
//              [0 1 0 0 0 1 | 5]   (counter 1 equation)
//              [0 0 1 1 1 0 | 4]   (counter 2 equation)
//              [1 1 0 1 0 0 | 7]   (counter 3 equation)
//
//   After elimination: pivot columns identified, free variables searched
//
// Time comp: O(M * (n^3 + B^f)) where M=machines, n=counters,
//                  f=free variables, B=max target value
// Space comp: O(n * m) for matrix, O(f) for search state
//==============================================================================

const MAX_BUTTONS = 20;
const MAX_COUNTERS = 16;

// Rational number for exact arithmetic during Gaussian elimination.
// Avoids floating-point precision issues that could cause incorrect solutions.
//
// Example: 1/3 + 1/6 = 2/6 + 1/6 = 3/6 = 1/2 (exactly, no rounding)
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
        return .{
            .num = @divTrunc(num, @as(i64, @intCast(g))),
            .den = @divTrunc(den, @as(i64, @intCast(g))),
        };
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
        if (self.den == 0) return null;
        if (@rem(self.num, self.den) != 0) return null;
        return @divTrunc(self.num, self.den);
    }

    fn fromInt(n: i64) Rational {
        return .{ .num = n, .den = 1 };
    }
};

// This recursively searches over free variables with pruning.
// After Gaussian elimination, we have:
//   - Pivot variables that are determined by free variable values via back-substitution
//   - Free variables that can take any non-negative integer value (bounded by targets)
//
// The search strategy is to try free variable values 0, 1, 2, ... up to bound,
// and prune branches where current cost >= best known solution.
// Also, we early exit when optimal found (cost can't decrease).
//
// Example: 2 free variables, bound=10, current best=15
//   depth=0: try v=0,1,2,... (stop when cost >= 15) -> 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
//   depth=1: for each v[0], try v=0,1,2,... (stop when cost >= 15) -> 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
//   depth=2: evaluate full solution via back-substitution
fn searchFreeVariables(
    matrix: *[MAX_COUNTERS][MAX_BUTTONS + 1]Rational,
    num_buttons: usize,
    num_pivots: usize,
    pivot_col: *[MAX_COUNTERS]i32,
    free_vars: *[MAX_BUTTONS]usize,
    num_free: usize,
    bound: u64,
    free_vals: *[MAX_BUTTONS]u64,
    depth: usize,
    current_free_cost: u64,
    min_cost: *u64,
) void {
    if (current_free_cost >= min_cost.*) return;
    if (depth == num_free) {
        var solution: [MAX_BUTTONS]i64 = .{0} ** MAX_BUTTONS;
        for (0..num_free) |f| {
            solution[free_vars[f]] = @intCast(free_vals[f]);
        }

        var total_cost: u64 = current_free_cost;
        var valid = true;

        // We use back-substitution to solve pivot variables from bottom row up
        // On each pivot row, we have: x_pivot = RHS - sum(coeff[j] * x[j]) for j > pivot_col
        var row_idx: usize = num_pivots;
        while (row_idx > 0) {
            row_idx -= 1;
            const col: usize = @intCast(pivot_col[row_idx]);
            var val = matrix[row_idx][num_buttons]; // RHS
            for (col + 1..num_buttons) |c| {
                val = val.sub(matrix[row_idx][c].mul(Rational.fromInt(solution[c])));
            }

            if (val.toInt()) |v| {
                if (v < 0) {
                    valid = false;
                    break;
                }
                solution[col] = v;
                total_cost += @intCast(v);
                if (total_cost >= min_cost.*) {
                    valid = false;
                    break;
                }
            } else {
                valid = false;
                break;
            }
        }

        if (valid and total_cost < min_cost.*) {
            min_cost.* = total_cost;
        }

        return;
    }

    const remaining_budget = if (min_cost.* > current_free_cost)
        min_cost.* - current_free_cost
    else
        0;
    const this_bound = @min(bound, remaining_budget);

    var v: u64 = 0;
    while (v < this_bound) : (v += 1) {
        free_vals[depth] = v;
        searchFreeVariables(
            matrix,
            num_buttons,
            num_pivots,
            pivot_col,
            free_vars,
            num_free,
            bound,
            free_vals,
            depth + 1,
            current_free_cost + v,
            min_cost,
        );

        // If best solution uses <= current free cost, no point trying larger
        if (min_cost.* <= current_free_cost + v) break;
    }
}

// This solves the integer linear system A * x = b with x >= 0, minimizing sum(x).
//
//   1) Gaussian elimination with partial pivoting
//   2) Check for inconsistency (row [0 0 ... 0 | nonzero])
//   3) Identify free variables (columns without pivots)
//   4) Search over free variable assignments
//   5) Back-substitute to get pivot variables, validate and track minimum
fn solveLinearSystem(buttons: []const u32, targets: []const u32) !u64 {
    const num_buttons = buttons.len;
    const num_counters = targets.len;

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

    var pivot_col: [MAX_COUNTERS]i32 = .{-1} ** MAX_COUNTERS;
    var current_row: usize = 0;

    for (0..num_buttons) |col| {
        var pivot_row: ?usize = null;
        for (current_row..num_counters) |row| {
            if (!matrix[row][col].isZero()) {
                pivot_row = row;
                break;
            }
        }

        if (pivot_row) |pr| {
            if (pr != current_row) {
                for (0..num_buttons + 1) |c| {
                    const tmp = matrix[current_row][c];
                    matrix[current_row][c] = matrix[pr][c];
                    matrix[pr][c] = tmp;
                }
            }

            const pivot_val = matrix[current_row][col];
            for (0..num_buttons + 1) |c| {
                matrix[current_row][c] = matrix[current_row][c].div(pivot_val);
            }

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
    for (num_pivots..num_counters) |row| {
        if (!matrix[row][num_buttons].isZero()) {
            return error.NoSolution;
        }
    }

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

    var max_target: u64 = 0;
    for (targets) |t| {
        if (t > max_target) max_target = t;
    }

    const search_bound: u64 = max_target + 1;

    var min_cost: u64 = std.math.maxInt(u64);
    var free_vals: [MAX_BUTTONS]u64 = .{0} ** MAX_BUTTONS;

    searchFreeVariables(
        &matrix,
        num_buttons,
        num_pivots,
        &pivot_col,
        &free_vars,
        num_free,
        search_bound,
        &free_vals,
        0,
        0,
        &min_cost,
    );

    if (min_cost == std.math.maxInt(u64)) {
        return error.NoSolution;
    }

    return min_cost;
}

// Format: [ignored] (0,1) (2,3) ... {target0,target1,...}
//   - (0,1): button affects counters 0 and 1 -> bitmask 0b0011
//   - {3,5,4}: targets -> counter[0]=3, counter[1]=5, counter[2]=4
fn solvePartTwoMachine(line: []const u8) !u64 {
    var buttons: [MAX_BUTTONS]u32 = undefined;
    var num_buttons: usize = 0;
    var targets: [MAX_COUNTERS]u32 = undefined;
    var num_counters: usize = 0;
    var i: usize = 0;

    while (i < line.len and line[i] != ']') : (i += 1) {}
    i += 1;

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

    return solveLinearSystem(buttons[0..num_buttons], targets[0..num_counters]);
}

pub fn partTwo() !u64 {
    var total: u64 = 0;
    var lines = std.mem.tokenizeScalar(u8, input_data, '\n');
    while (lines.next()) |line| {
        total += try solvePartTwoMachine(line);
    }

    return total;
}

pub fn main() !void {
    var out = std.fs.File.stdout().writerStreaming(&.{});

    var timer = try std.time.Timer.start();
    const result1 = try partOne();
    const time1 = timer.read();

    // Part 1: 434
    // Time: 69125ns (69μs)
    try out.interface.print("Part 1: {}\n", .{result1});
    try out.interface.print("Time: {d}ns ({d}μs)\n\n", .{ time1, time1 / 1000 });

    timer.reset();
    const result2 = try partTwo();
    const time2 = timer.read();

    // Part 2: 15132
    // Time: 336677542ns (336677μs) -> ~337ms
    try out.interface.print("Part 2: {}\n", .{result2});
    try out.interface.print("Time: {d}ns ({d}μs)\n", .{ time2, time2 / 1000 });
}