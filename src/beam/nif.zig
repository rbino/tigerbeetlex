const std = @import("std");
const e = @import("erl_nif.zig");
const beam = @import("../beam.zig");
const resource = @import("resource.zig");
const scheduler = @import("scheduler.zig");

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
        .major = 2,
        .minor = 16,
        .name = name.ptr,
        .num_of_funcs = exported_nifs.len,
        .funcs = exported_nifs.ptr,
        .load = load_fn,
        .reload = null, // currently unsupported
        .upgrade = null, // currently unsupported
        .unload = null, // currently unsupported
        .vm_variant = "beam.vanilla",
        .options = 1,
        .sizeof_ErlNifResourceTypeInit = @sizeOf(e.ErlNifResourceTypeInit),
        .min_erts = "erts-13.1.2",
    };
}

pub fn wrap(comptime nif_name: [:0]const u8, fun: anytype) FunctionEntry {
    const nif = MakeWrappedNif(nif_name, fun);
    return function_entry(nif_name, nif.arity, nif.wrapper);
}

fn MakeWrappedNif(comptime nif_name: [:0]const u8, comptime fun: anytype) type {
    const Function = @TypeOf(fun);

    const function_info = switch (@typeInfo(Function)) {
        .Fn => |f| f,
        else => @compileError("Only functions can be wrapped"),
    };

    const params = function_info.args;
    const with_env = params.len > 1 and params[0].arg_type == beam.Env;
    const ReturnType = function_info.return_type.?;

    return struct {
        // Env is not counted towards the effective arity, subtract 1 if env is the first parameter
        pub const arity = if (with_env) params.len - 1 else params.len;

        pub fn wrapper(
            env: beam.Env,
            argc: c_int,
            argv_ptr: [*c]const beam.Term,
        ) callconv(.C) beam.Term {
            if (argc != arity) @panic(nif_name ++ " called with the wrong number of arguments");

            const argv = @ptrCast([*]const beam.Term, argv_ptr)[0..@intCast(usize, argc)];
            // If the first argument is env, we must adjust the offset between the input argv and
            // the actual args of the function
            const argv_offset = if (with_env) 1 else 0;

            var args: std.meta.ArgsTuple(Function) = undefined;
            inline for (args) |*arg, i| {
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

            // TODO: this currently assumes that if it's not an error union it's beam.Term, make
            // this a little better
            return switch (@typeInfo(ReturnType)) {
                .ErrorUnion => @call(.{}, fun, args) catch |err| switch (err) {
                    error.Yield => scheduler.reschedule(env, nif_name.ptr, wrapper, argc, argv_ptr),
                },
                else => @call(.{}, fun, args),
            };
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
        u16 => try beam.get_u16(env, term),
        u32 => try beam.get_u32(env, term),
        u64 => try beam.get_u64(env, term),
        u128 => try beam.get_u128(env, term),
        []const u8 => try beam.get_char_slice(env, term),
        else => @compileError("Type " ++ @typeName(T) ++ " is not handled by get_arg_from_term"),
    };
}
