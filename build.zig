const std = @import("std");

pub fn build(b: *std.Build) void {
    const executables = [_]struct {
        name: []const u8,
        path: []const u8,
    }{
        .{ .name = "01-secret-entrance", .path = "01-secret-entrance/main.zig" },
    };

    inline for (executables) |exe_config| {
        const exe = b.addExecutable(.{
            .name = exe_config.name,
            .root_module = b.addModule(exe_config.name, .{
                .root_source_file = b.path(exe_config.path),
                .target = b.graph.host,
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