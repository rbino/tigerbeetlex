const std = @import("std");
const assert = std.debug.assert;

const e = @import("erl_nif.zig");
const beam = @import("../beam.zig");
const resource = @import("resource.zig");

pub const Nif = *const fn (beam.Env, argc: c_int, argv: [*c]const beam.Term) callconv(.C) beam.Term;
pub const NifLoadFn = *const fn (beam.Env, [*c]?*anyopaque, beam.Term) callconv(.C) c_int;

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

    const params = function_info.params;
    const with_env = params.len > 1 and params[0].type == beam.Env;
    const ReturnType = function_info.return_type.?;
    comptime assert(ReturnType == beam.Term);

    return struct {
        // Env is not counted towards the effective arity, subtract 1 if env is the first parameter
        pub const arity = if (with_env) params.len - 1 else params.len;

        pub fn wrapper(
            env: beam.Env,
            argc: c_int,
            argv_ptr: [*c]const beam.Term,
        ) callconv(.C) beam.Term {
            assert(argc == arity);

            const argv = @as([*]const beam.Term, @ptrCast(argv_ptr))[0..@intCast(argc)];
            // If the first argument is env, we must adjust the offset between the input argv and
            // the actual args of the function
            const argv_offset = if (with_env) 1 else 0;

            var args: std.meta.ArgsTuple(Function) = undefined;
            inline for (&args, 0..) |*arg, i| {
                if (with_env and i == 0) {
                    // Put the env as first argument if the function accepts it
                    arg.* = env;
                } else {
                    // For all the other arguments, extract them based on their type
                    const argv_idx = i - argv_offset;
                    const ArgType = @TypeOf(arg.*);
                    arg.* = get_arg_from_term(ArgType, env, argv[argv_idx]) catch
                        return beam.raise_badarg(env);
                }
            }

            return @call(.auto, fun, args);
        }
    };
}

fn get_arg_from_term(comptime T: type, env: beam.Env, term: beam.Term) !T {
    // Special case: check if it's a resource
    if (comptime resource.is_resource(T)) return try T.from_term_handle(env, term);

    // These are what we currently need, the need to add new types to the switch should be caught
    // by the compileError below
    return switch (T) {
        beam.Term => term,
        u128 => try beam.get_u128(env, term),
        []const u8 => try beam.get_char_slice(env, term),
        else => @compileError("Type " ++ @typeName(T) ++ " is not handled by get_arg_from_term"),
    };
}
