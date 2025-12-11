const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const executables = [_]struct {
        name: []const u8,
        path: []const u8,
    }{
        .{ .name = "01-secret-entrance", .path = "01-secret-entrance/main.zig" },
        .{ .name = "02-gift-shop", .path = "02-gift-shop/main.zig" },
        .{ .name = "03-lobby", .path = "03-lobby/main.zig" },
        .{ .name = "04-printing-department", .path = "04-printing-department/main.zig" },
        .{ .name = "05-cafeteria", .path = "05-cafeteria/main.zig" },
        .{ .name = "06-trash-compactor", .path = "06-trash-compactor/main.zig" },
        .{ .name = "07-laboratory", .path = "07-laboratory/main.zig" },
        .{ .name = "08-playground", .path = "08-playground/main.zig" },
        .{ .name = "09-movie-theater", .path = "09-movie-theater/main.zig" },
        .{ .name = "10-factory", .path = "10-factory/main.zig" },
        .{ .name = "11-reactor", .path = "11-reactor/main.zig" },
    };

    inline for (executables) |exe_config| {
        const exe = b.addExecutable(.{
            .name = exe_config.name,
            .root_module = b.addModule(exe_config.name, .{
                .root_source_file = b.path(exe_config.path),
                .target = b.graph.host,
                .optimize = optimize,
            }),
        });

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step_name = std.fmt.allocPrint(
            b.allocator,
            "run-{s}",
            .{exe_config.name},
        ) catch @panic("OOM");

        const run_step_desc = std.fmt.allocPrint(
            b.allocator,
            "Run {s}",
            .{exe_config.name},
        ) catch @panic("OOM");

        const run_step = b.step(run_step_name, run_step_desc);
        run_step.dependOn(&run_cmd.step);
    }
}