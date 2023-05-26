const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    // TODO: toggle this from mix.exs when build_dot_zig supports it
    const mode = .ReleaseSafe;

    // Get ERTS_INCLUDE_DIR from env, which should be passed by :build_dot_zig
    const erts_include_dir = std.process.getEnvVarOwned(b.allocator, "ERTS_INCLUDE_DIR") catch blk: {
        // Fallback to extracting it from the erlang shell so we can also execute zig build manually
        const argv = [_][]const u8{
            "erl",
            "-eval",
            "io:format(\"~s\", [lists:concat([code:root_dir(), \"/erts-\", erlang:system_info(version), \"/include\"])])",
            "-s",
            "init",
            "stop",
            "-noshell",
        };

        break :blk b.exec(&argv) catch @panic("Cannot find ERTS include dir");
    };
    defer b.allocator.free(erts_include_dir);

    const lib = b.addSharedLibrary("tigerbeetlex", "src/tigerbeetlex.zig", .unversioned);
    lib.addSystemIncludeDir(erts_include_dir);
    lib.addPackagePath("beam", "deps/zigler/priv/beam/beam.zig");
    lib.addPackagePath("beam_mutex", "deps/zigler/priv/beam/beam_mutex.zig");
    lib.addPackagePath("erl_nif", "deps/zigler/priv/beam/erl_nif.zig");
    lib.addPackagePath("tigerbeetle", "src/tigerbeetle/src/tigerbeetle.zig");
    lib.linkLibC();
    lib.setBuildMode(mode);

    // Do this so `lib` doesn't get prepended to the lib name, see https://github.com/ziglang/zig/issues/2231
    const install = b.addInstallLibFile(lib.getOutputLibSource(), "tigerbeetlex.so");
    install.step.dependOn(&lib.step);
    b.getInstallStep().dependOn(&install.step);

    const tests = b.addTest("src/tigerbeetlex.zig");
    tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&tests.step);
}
