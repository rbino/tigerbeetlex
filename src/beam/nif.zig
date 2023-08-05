const e = @import("erl_nif.zig");
const beam = @import("../beam.zig");

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
