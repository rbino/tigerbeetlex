const std = @import("std");
const builtin = @import("builtin");
const Query = std.Target.Query;

// TigerBeetle requires certain CPU feature and supports a closed set of CPUs.
// This is taken from TigerBeetle's build.zig, but we also add the ABI to the
// available triples since we link against libc in our library
fn resolve_target(b: *std.Build, target_requested: ?[]const u8) !std.Build.ResolvedTarget {
    const target_host = @tagName(builtin.target.cpu.arch) ++ "-" ++ @tagName(builtin.target.os.tag) ++ "-" ++ @tagName(builtin.target.abi);
    const target = target_requested orelse target_host;
    const triples = .{
        "aarch64-linux-gnu",
        "aarch64-macos-none",
        "x86_64-linux-gnu",
        "x86_64-macos-none",
        "x86_64-windows-gnu",
    };
    const cpus = .{
        "baseline+aes+neon",
        "baseline+aes+neon",
        "x86_64_v3+aes",
        "x86_64_v3+aes",
        "x86_64_v3+aes",
    };

    const arch_os, const cpu = inline for (triples, cpus) |triple, cpu| {
        if (std.mem.eql(u8, target, triple)) break .{ triple, cpu };
    } else {
        std.log.err("unsupported target: '{s}'", .{target});
        return error.UnsupportedTarget;
    };
    const query = try Query.parse(.{
        .arch_os_abi = arch_os,
        .cpu_features = cpu,
    });
    return b.resolveTargetQuery(query);
}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // We use TigerBeetle's mechanism to resolve the target, so we don't use b.standardTargetOptions
    const target = b.option([]const u8, "target", "The CPU architecture, OS, and ABI to build for");

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // Get ERTS_INCLUDE_DIR from env, which should be passed by :build_dot_zig
    const erts_include_dir = b.graph.env_map.get("ERTS_INCLUDE_DIR") orelse blk: {
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

    // In its build.zig, TigerBeetle accepts a git commit hash that gets passed around to different modules (CI, VSR etc).
    // If no one is explicitly passed, it falls back to reading it by shelling out to git.
    // This is a problem because it means that it's a compile-time requirement to build inside a git repo, which could be
    // false if we're using TigerBeetlex, e.g., in an .exs script.
    // To avoid this, we just pass a fake git commit hash, since the git commit hash doesn't change the client behavior
    // in any way.
    const fake_git_commit_hash = "bee71e0000000000000000000000000000bee71e"; // Beetle-hash!
    const tigerbeetle_dep = b.dependency("tigerbeetle", .{ .@"git-commit" = @as([]const u8, fake_git_commit_hash) });

    const stdx_mod = b.createModule(.{ .root_source_file = tigerbeetle_dep.path("src/stdx/stdx.zig") });
    const vsr_mod = b.createModule(.{
        .root_source_file = tigerbeetle_dep.path("src/vsr.zig"),
    });
    vsr_mod.addImport("stdx", stdx_mod);

    const config_mod = b.createModule(.{
        .root_source_file = b.path("src/config.zig"),
    });

    const elixir_bindings_generator = b.addExecutable(.{
        .name = "elixir_bindings",
        .root_source_file = b.path("tools/elixir_bindings.zig"),
        .target = b.graph.host,
    });
    elixir_bindings_generator.root_module.addImport("config", config_mod);
    elixir_bindings_generator.root_module.addImport("vsr", vsr_mod);

    const elixir_bindings_generator_step = b.addRunArtifact(elixir_bindings_generator);

    const elixir_bindings_formatting_step = b.addSystemCommand(&.{ "mix", "format" });
    elixir_bindings_formatting_step.step.dependOn(&elixir_bindings_generator_step.step);

    const generate = b.step("bindings", "Generates the Elixir bindings from TigerBeetle source");
    generate.dependOn(&elixir_bindings_formatting_step.step);

    const lib = b.addSharedLibrary(.{
        .name = "tigerbeetlex",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/tigerbeetlex.zig" } },
        .target = resolve_target(b, target) catch @panic("unsupported host"),
        .optimize = optimize,
        .link_libc = true,
    });
    lib.addSystemIncludePath(.{ .cwd_relative = erts_include_dir });
    // Config (vsr_config) imports
    lib.root_module.addImport("config", config_mod);
    // TigerBeetle imports
    lib.root_module.addImport("vsr", vsr_mod);
    if (optimize == .ReleaseSafe) {
        // Reduce binary size in release safe mode
        lib.root_module.strip = true;
        // While still supporting stack traces
        lib.root_module.omit_frame_pointer = false;
        lib.root_module.unwind_tables = .none;
    }
    // This is needed to avoid errors on MacOS when loading the NIF
    lib.linker_allow_shlib_undefined = true;

    // Do this so `lib` doesn't get prepended to the lib name, and `.so` is used as suffix also
    // on MacOS, since it's required by the NIF loading mechanism.
    // See https://github.com/ziglang/zig/issues/2231
    const nif_so_install = b.addInstallFileWithDir(lib.getEmittedBin(), .lib, "tigerbeetlex.so");
    nif_so_install.step.dependOn(&lib.step);
    b.getInstallStep().dependOn(&nif_so_install.step);
}
