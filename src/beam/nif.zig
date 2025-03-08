const std = @import("std");
const assert = std.debug.assert;

const e = @import("erl_nif.zig");
const beam = @import("../beam.zig");
const resource = @import("resource.zig");

pub const Nif = *const fn (?*beam.Env, argc: c_int, argv: [*c]const beam.Term) callconv(.C) beam.Term;
pub const NifLoadFn = *const fn (?*beam.Env, [*c]?*anyopaque, beam.Term) callconv(.C) c_int;

pub const FunctionEntry = e.ErlNifFunc;
pub const Entrypoint = e.ErlNifEntry;

pub fn function_entry(
    comptime name: [:0]const u8,
    comptime arity: c_uint,
    comptime fun: Nif,
) FunctionEntry {
    return .{ .name = name.ptr, .arity = arity, .fptr = fun, .flags = 0 };
}

pub fn entrypoint(
    comptime name: [:0]const u8,
    comptime exported_nifs: []e.ErlNifFunc,
    comptime load_fn: NifLoadFn,
) Entrypoint {
    return .{
        .major = e.ERL_NIF_MAJOR_VERSION,
        .minor = e.ERL_NIF_MINOR_VERSION,
        .name = name.ptr,
        .num_of_funcs = exported_nifs.len,
        .funcs = exported_nifs.ptr,
        .load = load_fn,
        .reload = null, // currently unsupported
        .upgrade = null, // currently unsupported
        .unload = null, // currently unsupported
        .vm_variant = e.ERL_NIF_VM_VARIANT,
        .options = 1,
        .sizeof_ErlNifResourceTypeInit = @sizeOf(e.ErlNifResourceTypeInit),
        .min_erts = e.ERL_NIF_MIN_ERTS_VERSION,
    };
}

pub fn wrap(comptime nif_name: [:0]const u8, fun: anytype) FunctionEntry {
    const nif = MakeWrappedNif(fun);
    return function_entry(nif_name, nif.arity, nif.wrapper);
}

fn MakeWrappedNif(comptime fun: anytype) type {
    const Function = @TypeOf(fun);

    const function_info = switch (@typeInfo(Function)) {
        .Fn => |f| f,
        else => @compileError("Only functions can be wrapped"),
    };

    // Currently all our NIFs return a beam.Term
    const ReturnType = function_info.return_type.?;
    comptime assert(ReturnType == beam.Term);

    // And since we need to construct a beam.Term, we always accept a BEAM env as first parameter
    const params = function_info.params;
    comptime assert(params[0].type == *beam.Env);

    return struct {
        // Env is not counted towards the effective arity, subtract 1 since env is the first parameter
        pub const arity = params.len - 1;

        pub fn wrapper(
            env: ?*beam.Env,
            argc: c_int,
            argv_ptr: [*c]const beam.Term,
        ) callconv(.C) beam.Term {
            assert(env != null);
            assert(argc == arity);

            const argv = @as([*]const beam.Term, @ptrCast(argv_ptr))[0..@intCast(argc)];
            // The first argument is env, so we must adjust the offset between the input argv and
            // the actual args of the function
            const argv_offset = 1;

            var args: std.meta.ArgsTuple(Function) = undefined;
            inline for (&args, 0..) |*arg, i| {
                if (i == 0) {
                    // Put the env as first argument, asserting it's not null so we change
                    // the type from ?*beam.Env to *beam.Env
                    arg.* = env.?;
                } else {
                    // Check that the function accepts only beam.Term arguments
                    const ArgType = @TypeOf(arg.*);
                    comptime assert(ArgType == beam.Term);
                    // Copy over input argv to the function call arguments, shifting by one
                    // due to env being the first argument
                    const argv_idx = i - argv_offset;
                    arg.* = argv[argv_idx];
                }
            }

            return @call(.auto, fun, args);
        }
    };
}
