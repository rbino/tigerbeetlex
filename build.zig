const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

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

        break :blk b.run(&argv);
    };

    const lib = b.addSharedLibrary(.{
        .name = "tigerbeetlex",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/tigerbeetlex.zig" } },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.addSystemIncludePath(.{ .cwd_relative = erts_include_dir });
    // This is needed to avoid errors on MacOS when loading the NIF
    lib.linker_allow_shlib_undefined = true;

    // Do this so `lib` doesn't get prepended to the lib name, and `.so` is used as suffix also
    // on MacOS, since it's required by the NIF loading mechanism.
    // See https://github.com/ziglang/zig/issues/2231
    // Windows still needs the .dll suffix
    const lib_name = if (target.result.os.tag == .windows) "tigerbeetlex.dll" else "tigerbeetlex.so";
    const nif_so_install = b.addInstallFileWithDir(lib.getEmittedBin(), .lib, lib_name);
    nif_so_install.step.dependOn(&lib.step);
    b.getInstallStep().dependOn(&nif_so_install.step);
}
